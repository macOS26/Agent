import Foundation
import AppKit

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    saveImageFromClipboard()
    return 0
}

func saveImageFromClipboard() {
    let outputPath = "/Users/toddbruss/Desktop/Agent/andrew_avatar_circle.png"

    guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
        print("No image found in clipboard.")
        return
    }

    guard let tiffData = image.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
        print("Failed to convert image to PNG")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Image saved to \(outputPath)")
    } catch {
        print("Failed to save image: \(error)")
    }
}
