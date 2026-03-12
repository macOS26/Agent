import Foundation
import NotesBridge

// List Notes — shows recent notes from Notes.app

guard let app: NotesApplication = SBApplication(bundleIdentifier: "com.apple.Notes") else {
    print("Could not connect to Notes.app")
    exit(1)
}

print("Notes")
print("=====")

guard let folders = app.folders?() else {
    print("No folders found")
    exit(0)
}

let dateFormatter = DateFormatter()
dateFormatter.dateStyle = .short
dateFormatter.timeStyle = .short

var totalNotes = 0

for i in 0..<folders.count {
    guard let folder = folders.object(at: i) as? NotesFolder,
          let folderName = folder.name,
          let notes = folder.notes?() else { continue }

    let count = notes.count
    guard count > 0 else { continue }
    totalNotes += count

    print("\n\(folderName) (\(count) notes)")

    // Show the 5 most recent
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

print("\nTotal: \(totalNotes) notes")
