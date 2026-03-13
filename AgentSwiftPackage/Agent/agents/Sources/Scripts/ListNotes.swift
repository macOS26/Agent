import Foundation
import NotesBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    listNotes()
    return 0
}

func listNotes() {
    // Connect to Notes app
    guard let app: NotesApplication = SBApplication(bundleIdentifier: "com.apple.Notes") else {
        print("Could not connect to Notes.app")
        return
    }

    // Small delay to ensure app is responsive
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))

    print("Notes")
    print("=====")

    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short

    var totalNotes = 0
    var folderCount = 0

    // Try to get notes from accounts first (more reliable)
    if let accounts = app.accounts?(), accounts.count > 0 {
        for i in 0..<accounts.count {
            guard let account = accounts.object(at: i) as? NotesAccount,
                  let accountName = account.name else { continue }

            if let folders = account.folders?(), folders.count > 0 {
                for j in 0..<folders.count {
                    guard let folder = folders.object(at: j) as? NotesFolder,
                          let folderName = folder.name,
                          let notes = folder.notes?() else { continue }

                    let count = notes.count
                    guard count > 0 else { continue }
                    totalNotes += count
                    folderCount += 1

                    print("\n[\(accountName)] \(folderName) (\(count) notes)")

                    let limit = min(5, count)
                    for k in 0..<limit {
                        guard let note = notes.object(at: k) as? NotesNote,
                              let name = note.name else { continue }

                        let modified = note.modificationDate.map { dateFormatter.string(from: $0) } ?? ""
                        print("  - \(name)  [\(modified)]")
                    }
                    if count > 5 {
                        print("  ... and \(count - 5) more")
                    }
                }
            }
        }
    }

    // Fallback: try app.folders() directly
    if totalNotes == 0, let folders = app.folders?(), folders.count > 0 {
        for i in 0..<folders.count {
            guard let folder = folders.object(at: i) as? NotesFolder,
                  let folderName = folder.name,
                  let notes = folder.notes?() else { continue }

            let count = notes.count
            guard count > 0 else { continue }
            totalNotes += count
            folderCount += 1

            print("\n\(folderName) (\(count) notes)")

            let limit = min(5, count)
            for j in 0..<limit {
                guard let note = notes.object(at: j) as? NotesNote,
                      let name = note.name else { continue }

                let modified = note.modificationDate.map { dateFormatter.string(from: $0) } ?? ""
                print("  - \(name)  [\(modified)]")
            }
            if count > 5 {
                print("  ... and \(count - 5) more")
            }
        }
    }

    // Last resort: try app.notes() directly
    if totalNotes == 0, let notes = app.notes?(), notes.count > 0 {
        totalNotes = notes.count
        print("\nAll Notes (\(totalNotes) total)")

        let limit = min(10, totalNotes)
        for i in 0..<limit {
            guard let note = notes.object(at: i) as? NotesNote,
                  let name = note.name else { continue }

            let modified = note.modificationDate.map { dateFormatter.string(from: $0) } ?? ""
            print("  - \(name)  [\(modified)]")
        }
        if totalNotes > 10 {
            print("  ... and \(totalNotes - 10) more")
        }
    }

    if totalNotes == 0 {
        print("\nNo notes found. Make sure Notes.app is running and has notes.")
        print("Try: osascript -e 'tell application \"Notes\" to activate'")
    } else {
        print("\nTotal: \(totalNotes) notes in \(folderCount) folders")
    }
}