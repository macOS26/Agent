import Foundation
@preconcurrency import Speech
import AVFoundation

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
        SFSpeechRecognizer.requestAuthorization { @Sendable status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.beginAudioSession()
                case .denied, .restricted:
                    self.appendLog("Speech recognition not authorized. Enable in System Settings > Privacy > Speech Recognition.")
                case .notDetermined:
                    self.appendLog("Speech recognition authorization not determined.")
                @unknown default:
                    break
                }
            }
        }
    }

    func stopDictation() {
        speechAudioEngine?.stop()
        speechAudioEngine?.inputNode.removeTap(onBus: 0)
        speechRecognitionRequest?.endAudio()
        speechRecognitionTask?.cancel()
        speechRecognitionTask = nil
        speechRecognitionRequest = nil
        speechAudioEngine = nil
        isListening = false
    }

    // MARK: - Private

    private func beginAudioSession() {
        // Clean up any prior session
        stopDictation()

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            appendLog("Speech recognizer not available for current locale.")
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
            appendLog("Audio engine failed to start: \(error.localizedDescription)")
            return
        }

        speechAudioEngine = engine
        speechRecognitionRequest = request
        isListening = true

        speechRecognitionTask = recognizer.recognitionTask(with: request) { @Sendable result, error in
            let transcription = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let hasError = error != nil
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let transcription {
                    self.taskInput = transcription
                }

                if hasError || isFinal {
                    self.stopDictation()
                }
            }
        }
    }
}
