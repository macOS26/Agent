import Foundation
import FinderBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    listHomeContents()
    return 0
}

func listHomeContents() {
    guard let finder: FinderApplication = SBApplication(bundleIdentifier: "com.apple.finder") else {
        print("Could not connect to Finder")
        return
    }

    print("=== HOME DIRECTORY CONTENTS ===\n")

    // Get the home folder
    guard let home = finder.home else {
        print("Could not get home folder")
        return
    }

    print("Home: \(home.name ?? "unknown")\n")

    // Get folders in home
    print("--- FOLDERS ---")
    if let folders = home.folders?() {
        for i in 0..<folders.count {
            if let folder = folders.object(at: i) as? FinderFolder,
               let name = folder.name {
                print("  \(name)")
            }
        }
    }

    // Get files in home
    print("\n--- FILES ---")
    if let files = home.files?() {
        for i in 0..<files.count {
            if let file = files.object(at: i) as? FinderItem,
               let name = file.name {
                let size = file.size ?? 0
                print("  \(name) (\(size) bytes)")
            }
        }
    }

    // Explore each folder for more details
    print("\n--- FOLDER DETAILS ---")
    if let folders = home.folders?() {
        for i in 0..<folders.count {
            if let folder = folders.object(at: i) as? FinderFolder,
               let name = folder.name {

                // Get item count
                if let items = folder.items?() {
                    let itemCount = items.count
                    print("\n  \(name)/ (\(itemCount) items)")

                    // Show first 5 items in each folder
                    let limit = min(5, itemCount)
                    for j in 0..<limit {
                        if let item = items.object(at: j) as? FinderItem,
                           let itemName = item.name {
                            let itemType = type(of: item) == FinderFolder.self ? "folder" : "file"
                            print("     \(itemType) \(itemName)")
                        }
                    }
                    if itemCount > 5 {
                        print("     ... and \(itemCount - 5) more items")
                    }
                }
            }
        }
    }

    print("\n=== DONE ===")
}