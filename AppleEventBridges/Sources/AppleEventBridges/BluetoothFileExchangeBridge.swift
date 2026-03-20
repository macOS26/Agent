
// MARK: BluetoothFileExchangeApplication
@objc public protocol BluetoothFileExchangeApplication: SBApplicationProtocol {
    @objc optional func browseDevice(_ device: String!) // Browse a device.
    @objc optional func sendFile(_ file: URL!, toDevice: String!) // Send a file to a bluetooth device.
}
extension SBApplication: BluetoothFileExchangeApplication {}

