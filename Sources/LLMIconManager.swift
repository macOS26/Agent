import Cocoa

// Function to change LLM icon based on its status
func changeLLMIcon(status: String) {
    let statusColor: NSColor
    switch status {
    case "active":
        statusColor = NSColor.blue
    case "running":
        statusColor = NSColor.green
    case "not_set":
        statusColor = NSColor.red
    default:
        statusColor = NSColor.black
    }
    // Code to change the LLM icon color
}
