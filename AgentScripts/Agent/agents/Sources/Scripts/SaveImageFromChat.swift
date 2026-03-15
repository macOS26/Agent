import Foundation
import AppKit

// This script saves an image from the clipboard (if available) to a file.
// In this case, the image is assumed to be in the clipboard from the chat interface.
let outputPath = "/Users/toddbruss/Desktop/Agent/andrew_avatar_circle.png"

if let image = NSPasteboard.general.image {
    if let tiffData = image.tiffRepresentation,
       let bitmapImage = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
        do {
            try pngData.write(to: URL(fileURLWithPath: outputPath))
            print("Image saved to \(outputPath)")
        } catch {
            print("Failed to save image: \(error)")
        }
    }
} else {
    print("No image found in clipboard.")
}