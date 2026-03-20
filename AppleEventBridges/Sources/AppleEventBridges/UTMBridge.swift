
// MARK: UTMSaveOptions
@objc public enum UTMSaveOptions : AEKeyword {
    case yes = 0x79657320 /* Save the file. */
    case no = 0x6e6f2020 /* Do not save the file. */
    case ask = 0x61736b20 /* Ask the user whether or not to save the file. */
}

// MARK: UTMPrintingErrorHandling
@objc public enum UTMPrintingErrorHandling : AEKeyword {
    case standard = 0x6c777374 /* Standard PostScript error handling */
    case detailed = 0x6c776474 /* print a detailed report of PostScript errors */
}

// MARK: UTMBackend
@objc public enum UTMBackend : AEKeyword {
    case apple = 0x4170506c /* Apple Virtualization.framework backend. */
    case qemu = 0x51654d75 /* QEMU backend. */
    case unavailable = 0x556e4176 /* The virtual machine is not currently available. */
}

// MARK: UTMStatus
@objc public enum UTMStatus : AEKeyword {
    case stopped = 0x53745361 /* VM is not running. */
    case starting = 0x53745362 /* VM is starting up. */
    case started = 0x53745363 /* VM is running. */
    case pausing = 0x53745364 /* VM is going to pause. */
    case paused = 0x53745365 /* VM is paused. */
    case resuming = 0x53745366 /* VM is resuming from pause. */
    case stopping = 0x53745367 /* VM is stopping. */
}

// MARK: UTMStopMethod
@objc public enum UTMStopMethod : AEKeyword {
    case force = 0x466f5263 /* Force stop VM by sending stop request to the backend. */
    case kill = 0x4b694c6c /* Force kill VM by terminating the backend. */
    case request = 0x52655175 /* Send a power down request to the guest OS which may be ignored. */
}

// MARK: UTMSerialInterface
@objc public enum UTMSerialInterface : AEKeyword {
    case ptty = 0x50745479 /* Pseudo TTY port. */
    case tcp = 0x54635020 /* TCP port. */
    case unavailable = 0x49556e41 /* Serial interface is currently unavailable or is in use by the GUI. */
}

// MARK: UTMOpenMode
@objc public enum UTMOpenMode : AEKeyword {
    case reading = 0x4f70526f /* Open the file as read only. The file must exist. */
    case writing = 0x4f70576f /* Open the file for writing. If the file does not exist, it will be created. If the file exists, it will be overwritten. */
    case appending = 0x4f704170 /* Open the file for writing at the end. Offsets are ignored for writes. If the file does not exist, it will be created. */
}

// MARK: UTMWhence
@objc public enum UTMWhence : AEKeyword {
    case startPosition = 0x53745274 /* The start of the file (only positive offsets). */
    case currentPosition = 0x43755272 /* The current pointer (both positive and negative offsets). */
    case endPosition = 0x556e4176 /* The end of the file (only negative offsets for reads, both for writes). */
}

// MARK: UTMQemuDirectoryShareMode
@objc public enum UTMQemuDirectoryShareMode : AEKeyword {
    case none = 0x536d4f66 /* Do not enable directory sharing. */
    case webDAV = 0x536d5776 /* Use SPICE WebDav (SPICE guest tools required). */
    case virtFS = 0x536d5673 /* Use VirtFS mount tagged 'share' (VirtFS guest drivers required). */
}

// MARK: UTMQemuDriveInterface
@objc public enum UTMQemuDriveInterface : AEKeyword {
    case none = 0x5164494e
    case ide = 0x51644969
    case scsi = 0x51644973
    case sd = 0x51644964
    case mtd = 0x5164496d
    case floppy = 0x51644966
    case pFlash = 0x51644970
    case virtIO = 0x51644976
    case nvMe = 0x5164496e
    case usb = 0x51644975
}

// MARK: UTMQemuNetworkMode
@objc public enum UTMQemuNetworkMode : AEKeyword {
    case emulated = 0x456d5564 /* Emulate a VLAN. */
    case shared = 0x53685264 /* NAT based sharing with the host. */
    case host = 0x486f5374 /* NAT based sharing with no WAN routing. */
    case bridged = 0x42724764 /* Bridged to a host interface. */
}

// MARK: UTMNetworkProtocol
@objc public enum UTMNetworkProtocol : AEKeyword {
    case tcp = 0x54635070
    case udp = 0x55645070
}

// MARK: UTMQemuScaler
@objc public enum UTMQemuScaler : AEKeyword {
    case linear = 0x51734c69
    case nearest = 0x51734e65
}

// MARK: UTMAppleNetworkMode
@objc public enum UTMAppleNetworkMode : AEKeyword {
    case shared = 0x53685264 /* NAT based sharing with the host. */
    case bridged = 0x42724764 /* Bridged to a host interface. */
}

// MARK: UTMGenericMethods
@objc public protocol UTMGenericMethods {
    @objc optional func closeSaving(_ saving: UTMSaveOptions, savingIn: URL!) // Close a document.
    @objc optional func saveIn(_ `in`: URL!, `as`: Any!) // Save a document.
    @objc optional func printWithProperties(_ withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) // Copy an object.
    @objc optional func moveTo(_ to: SBObject!) // Move an object to a new location.
}

// MARK: UTMApplication
@objc public protocol UTMApplication: SBApplicationProtocol {
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Bool { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional var autoTerminate: Bool { get } // Auto terminate the application when all windows are closed?
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func print(_ x: Any!, withProperties: [AnyHashable : Any]!, printDialog: Bool) // Print a document.
    @objc optional func quitSaving(_ saving: UTMSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) -> Bool // Verify that an object exists.
    @objc optional func importNew(_ new: NSNumber!, from: URL!) -> SBObject // Import a new virtual machine from a file.
    @objc optional func virtualMachines() -> SBElementArray
    @objc optional func usbDevices() -> SBElementArray
}
extension SBApplication: UTMApplication {}

// MARK: UTMDocument
@objc public protocol UTMDocument: SBObjectProtocol, UTMGenericMethods {
    @objc optional var name: String { get } // Its name.
    @objc optional var modified: Bool { get } // Has it been modified since the last save?
    @objc optional var file: URL { get } // Its location on disk, if it has one.
}
extension SBObject: UTMDocument {}

// MARK: UTMWindow
@objc public protocol UTMWindow: SBObjectProtocol, UTMGenericMethods {
    @objc optional var name: String { get } // The title of the window.
    @objc optional var index: Int { get } // The index of the window, ordered front to back.
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Does the window have a close button?
    @objc optional var miniaturizable: Bool { get } // Does the window have a minimize button?
    @objc optional var miniaturized: Bool { get } // Is the window minimized right now?
    @objc optional var resizable: Bool { get } // Can the window be resized?
    @objc optional var visible: Bool { get } // Is the window visible right now?
    @objc optional var zoomable: Bool { get } // Does the window have a zoom button?
    @objc optional var zoomed: Bool { get } // Is the window zoomed right now?
    @objc optional var document: UTMDocument { get } // The document whose contents are displayed in the window.
    @objc optional func id() -> Int // The unique identifier of the window.
}
extension SBObject: UTMWindow {}

// MARK: UTMVirtualMachine
@objc public protocol UTMVirtualMachine: SBObjectProtocol, UTMGenericMethods {
    @objc optional var name: String { get } // The name of the VM.
    @objc optional var backend: UTMBackend { get } // Emulation/virtualization engine used.
    @objc optional var status: UTMStatus { get } // Current running status.
    @objc optional var configuration: Any { get } // The configuration of the virtual machine.
    @objc optional var registry: [Any] { get } // The registry of the virtual machine.
    @objc optional func serialPorts() -> SBElementArray
    @objc optional func id() -> String // The unique identifier of the VM.
    @objc optional func startSaving(_ saving: Bool) // Start a virtual machine or resume a suspended virtual machine.
    @objc optional func suspendSaving(_ saving: Bool) // Suspend a running virtual machine to memory.
    @objc optional func stopBy(_ by: UTMStopMethod) // Shuts down a running virtual machine.
    @objc optional func delete() // Delete a virtual machine. All data will be deleted, there is no confirmation!
    @objc optional func duplicateWithProperties(_ withProperties: [AnyHashable : Any]!) // Copy an virtual machine and all its data.
    @objc optional func exportTo(_ to: URL!) // Export a virtual machine to a specified location.
    @objc optional func openFileAt(_ at: String!, `for`: UTMOpenMode, updating: Bool) -> UTMGuestFile // Open a file on the guest. You must close the file when you are done to prevent leaking guest resources.
    @objc optional func executeAt(_ at: String!, withArguments: [Any]!, withEnvironment: [Any]!, usingInput: String!, base64Encoding: Bool, outputCapturing: Bool) -> UTMGuestProcess // Execute a command or script on the guest.
    @objc optional func queryIp() -> [Any] // Query the guest for all IP addresses on its network interfaces (excluding loopback).
    @objc optional func updateConfigurationWith(_ with: Any!) // Update the configuration of the virtual machine. The VM must be in the stopped state.
    @objc optional func updateRegistryWith(_ with: [Any]!) // Update the registry of the virtual machine.
    @objc optional func guestFiles() -> SBElementArray
    @objc optional func guestProcesses() -> SBElementArray
    @objc optional func usbDevices() -> SBElementArray
}
extension SBObject: UTMVirtualMachine {}

// MARK: UTMSerialPort
@objc public protocol UTMSerialPort: SBObjectProtocol, UTMGenericMethods {
    @objc optional var interface: UTMSerialInterface { get } // The type of serial interface on the host.
    @objc optional var address: String { get } // Host address of the serial port (determined by the interface type).
    @objc optional var port: Int { get } // Port number of the serial port (not used in some interface types).
    @objc optional func id() -> Int // The unique identifier of the tag.
}
extension SBObject: UTMSerialPort {}

// MARK: UTMGuestFile
@objc public protocol UTMGuestFile: SBObjectProtocol, UTMGenericMethods {
    @objc optional func id() -> Int // The handle for the file.
    @objc optional func readAtOffset(_ atOffset: Int, from: UTMWhence, forLength: Int, base64Encoding: Bool, closing: Bool) -> String // Reads text data from a guest file.
    @objc optional func pullTo(_ to: URL!, closing: Bool) // Pulls a file from the guest to the host.
    @objc optional func writeWithData(_ withData: String!, atOffset: Int, from: UTMWhence, base64Encoding: Bool, closing: Bool) // Writes text data to a guest file.
    @objc optional func pushFrom(_ from: URL!, closing: Bool) // Pushes a file from the host to the guest and closes it.
    @objc optional func close() // Closes the file and prevent further operations.
}
extension SBObject: UTMGuestFile {}

// MARK: UTMGuestProcess
@objc public protocol UTMGuestProcess: SBObjectProtocol, UTMGenericMethods {
    @objc optional func id() -> Int // The PID of the process.
    @objc optional func getResult() -> [AnyHashable : Any] // Fetch execution result from the guest.
}
extension SBObject: UTMGuestProcess {}

// MARK: UTMUsbDevice
@objc public protocol UTMUsbDevice: SBObjectProtocol, UTMGenericMethods {
    @objc optional var name: String { get } // The name of the USB device.
    @objc optional var manufacturerName: String { get } // The product name described by the iManufacturer descriptor.
    @objc optional var productName: String { get } // The product name described by the iProduct descriptor.
    @objc optional var vendorId: Int { get } // The vendor ID described by the idVendor descriptor.
    @objc optional var productId: Int { get } // The product ID described by the idProduct descriptor.
    @objc optional func id() -> Int // A unique identifier corrosponding to the USB bus and port number.
    @objc optional func connectTo(_ to: UTMVirtualMachine!) // Connect a USB device to a running VM and remove it from the host.
    @objc optional func disconnect() // Disconnect a USB device from the guest and re-assign it to the host.
}
extension SBObject: UTMUsbDevice {}

