import Foundation
@preconcurrency import Speech
import AVFoundation
import CoreAudio
import AgentAudit

// MARK: - Speech-to-Text Dictation

extension AgentViewModel {

    func toggleDictation() {
        if isListening {
            stopDictation()
        } else {
            startDictation()
        }
    }

    func startDictation() {
        isListening = true
        SFSpeechRecognizer.requestAuthorization { @Sendable status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.beginAudioSession()
                case .denied, .restricted:
                    self.isListening = false
                    self.appendLog("⚠️ Speech recognition not authorized. Enable in System Settings > Privacy > Speech Recognition.")
                case .notDetermined:
                    self.isListening = false
                    self.appendLog("⚠️ Speech recognition authorization not determined.")
                @unknown default:
                    self.isListening = false
                }
            }
        }
    }

    private func tearDownSpeech() {
        hotwordSilenceTimer?.invalidate()
        hotwordSilenceTimer = nil
        isHotwordCapturing = false
        hotwordLastTranscriptionLength = 0
        speechAudioEngine?.stop()
        speechAudioEngine?.inputNode.removeTap(onBus: 0)
        speechRecognitionRequest?.endAudio()
        speechRecognitionTask?.cancel()
        speechRecognitionTask = nil
        speechRecognitionRequest = nil
        speechAudioEngine = nil
        preDictationTabId = nil
    }

    func stopDictation() {
        tearDownSpeech()
        isListening = false
    }

    // MARK: - Hotword Listening

    func toggleHotwordListening() {
        if isHotwordListening {
            stopHotwordListening()
        } else {
            startHotwordListening()
        }
    }

    func startHotwordListening() {
        isHotwordListening = true
        isHotwordCapturing = false
        startDictation()
    }

    func stopHotwordListening() {
        isHotwordListening = false
        isHotwordCapturing = false
        stopDictation()
    }

    // MARK: - Private

    private func beginAudioSession() {
        tearDownSpeech()

        guard Self.hasPhysicalDefaultInput() else {
            isListening = false
            AuditLog.log(.shell, "Dictation aborted: no physical audio input device (virtual default input on this Mac).")
            appendLog("⚠️ No microphone detected. Connect an audio input (AirPods, USB mic, etc.) and try again.")
            return
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            isListening = false
            appendLog("⚠️ Speech recognizer not available for current locale.")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { @Sendable buffer, _ in
            request.append(buffer)
        }

        engine.prepare()

        do {
            try engine.start()
        } catch {
            isListening = false
            appendLog("❌ Audio engine failed: \(error.localizedDescription)")
            return
        }

        speechAudioEngine = engine
        speechRecognitionRequest = request
        isListening = true

        preDictationTabId = selectedTabId
        if let tabId = selectedTabId,
           let tab = tab(for: tabId)
        {
            preDictationText = tab.taskInput
        } else {
            preDictationText = taskInput
        }

        speechRecognitionTask = recognizer.recognitionTask(with: request) { @Sendable result, error in
            let transcription = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let hasError = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.isListening else { return }

                if let transcription {
                    if self.isHotwordListening {
                        self.handleHotwordTranscription(transcription)
                    } else {
                        // Normal dictation mode
                        let prefix = self.preDictationText
                        let separator = prefix.isEmpty || prefix.hasSuffix(" ") ? "" : " "
                        let newText = prefix + separator + transcription

                        if let tabId = self.preDictationTabId,
                           let tab = self.tab(for: tabId)
                        {
                            tab.taskInput = newText
                        } else {
                            self.taskInput = newText
                        }
                    }
                }

                if hasError || isFinal {
                    if self.isHotwordListening {
                        // Restart listening after a pause (recognition sessions time out)
                        self.restartHotwordSession()
                    } else {
                        self.stopDictation()
                    }
                }
            }
        }
    }

    // MARK: - Hotword Processing

    /// / Find the LAST word-boundary occurrence of "agent"/"agent!" in lowercased / transcription and return index
    /// after it. Word-boundary = char before must be / non-letter (or start) AND char after "t"/"!" must be non-letter (or end). / Anchors on LAST occurrence so "agent open agent script" treats second as wake word.
    private static func wakeWordAnchor(in transcription: String) -> String.Index? {
        let lower = transcription.lowercased()
        let wakes = ["agent!", "agent"] // try the punctuated form first
        var bestEnd: String.Index?
        for wake in wakes {
            var searchStart = lower.startIndex
            while let range = lower.range(of: wake, range: searchStart..<lower.endIndex) {
                let beforeOK: Bool = {
                    guard range.lowerBound > lower.startIndex else { return true }
                    let prev = lower[lower.index(before: range.lowerBound)]
                    return !prev.isLetter
                }()
                let afterOK: Bool = {
                    guard range.upperBound < lower.endIndex else { return true }
                    let next = lower[range.upperBound]
                    return !next.isLetter
                }()
                if beforeOK && afterOK {
                    bestEnd = range.upperBound // keep walking — we want the LAST hit
                }
                searchStart = lower.index(after: range.lowerBound)
            }
            if bestEnd != nil { break } // prefer "agent!" over "agent" if both matched
        }
        return bestEnd
    }

    private func handleHotwordTranscription(_ transcription: String) {
        if !isHotwordCapturing {
            // Look for the wake word "agent" / "agent!" — must be a complete word
            guard let anchor = Self.wakeWordAnchor(in: transcription) else { return }

            // Wake word detected — start capturing the command after it
            isHotwordCapturing = true
            let afterAgent = String(transcription[anchor...])
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "!.,")))

            let command = afterAgent.isEmpty ? "" : afterAgent
            setInputText(command)
            hotwordLastTranscriptionLength = command.count
            resetSilenceTimer()
            return
        }

        // Already capturing — re-anchor on the LAST wake-word hit so the
        // captured command stays in sync with the latest transcription.
        if let anchor = Self.wakeWordAnchor(in: transcription) {
            let afterAgent = String(transcription[anchor...])
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "!.,")))
            setInputText(afterAgent)

            if afterAgent.count != hotwordLastTranscriptionLength {
                hotwordLastTranscriptionLength = afterAgent.count
                resetSilenceTimer()
            }
        }
    }

    private func setInputText(_ text: String) {
        let prefix = preDictationText
        let separator = (prefix.isEmpty || prefix.hasSuffix(" ") || text.isEmpty) ? "" : " "
        let newText = prefix + separator + text

        if let tabId = preDictationTabId,
           let tab = tab(for: tabId)
        {
            tab.taskInput = newText
        } else {
            taskInput = newText
        }
    }

    private func resetSilenceTimer() {
        hotwordSilenceTimer?.invalidate()
        hotwordSilenceTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.submitHotwordCommand()
            }
        }
    }

    private func submitHotwordCommand() {
        hotwordSilenceTimer?.invalidate()
        hotwordSilenceTimer = nil

        // Stop current recognition
        speechAudioEngine?.stop()
        speechAudioEngine?.inputNode.removeTap(onBus: 0)
        speechRecognitionRequest?.endAudio()
        speechRecognitionTask?.cancel()
        speechRecognitionTask = nil
        speechRecognitionRequest = nil
        speechAudioEngine = nil
        isListening = false
        isHotwordCapturing = false

        // Submit the command
        if let tabId = preDictationTabId,
           let tab = tab(for: tabId)
        {
            if !tab.taskInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                runTabTask(tab: tab)
            }
        } else {
            if !taskInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                run()
            }
        }

        // Restart hotword listening after a short delay
        if isHotwordListening {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isHotwordListening else { return }
                self.startDictation()
            }
        }
    }

    // MARK: - Audio Input Detection

    private static func getDefaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &size, &deviceID
        )
        return (status == noErr && deviceID != 0) ? deviceID : nil
    }

    private static func transportType(of deviceID: AudioDeviceID) -> UInt32? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &transport)
        return status == noErr ? transport : nil
    }

    /// Returns true only when the default input is a real, usable device.
    /// Mac mini with no mic connected reports a virtual (`'vrtc'`) default
    /// input that crashes `AVAudioEngine.start()` — filter it out here.
    static func hasPhysicalDefaultInput() -> Bool {
        guard let dev = getDefaultInputDeviceID(),
              let t = transportType(of: dev) else { return false }
        return t != 0x76727463 // 'vrtc'
    }

    private func restartHotwordSession() {
        // Recognition timed out — restart if still in hotword mode
        speechAudioEngine?.stop()
        speechAudioEngine?.inputNode.removeTap(onBus: 0)
        speechRecognitionRequest?.endAudio()
        speechRecognitionTask?.cancel()
        speechRecognitionTask = nil
        speechRecognitionRequest = nil
        speechAudioEngine = nil
        isListening = false
        isHotwordCapturing = false
        hotwordLastTranscriptionLength = 0
        hotwordSilenceTimer?.invalidate()
        hotwordSilenceTimer = nil

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.5))
            guard let self, self.isHotwordListening else { return }
            self.startDictation()
        }
    }
}
