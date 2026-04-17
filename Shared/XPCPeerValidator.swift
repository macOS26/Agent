import Foundation
import Security
import Darwin

/// Validates the code-signing identity of an XPC peer before the listener
/// accepts the connection.
///
/// Both AgentHelper (runs as root) and AgentUser (runs as the user with TCC)
/// expose well-known Mach services. Without peer validation, any local
/// process can connect and drive them — a local privilege-escalation path.
///
/// Strategy:
///   1. On macOS 13+, we call `NSXPCListener.setCodeSigningRequirement` so
///      the OS enforces the requirement before the delegate ever sees the
///      connection. This is the primary defense.
///   2. In `shouldAcceptNewConnection` we *also* manually evaluate the
///      requirement against the connection's audit token. Belt-and-suspenders
///      for older OS versions and for cases where `setCodeSigningRequirement`
///      silently fails to install (malformed requirement, ad-hoc-signed
///      builds, etc.).
///   3. If the daemon itself is ad-hoc signed and has no Team ID, we cannot
///      enforce a team-based requirement. In that case we require the peer
///      to carry the same SHA-256 CDHash as the daemon's own bundle — so
///      only the exact same locally-built Agent.app can connect.
enum XPCPeerValidator {

    /// The hardcoded bundle identifier prefix of the main Agent.app.
    /// Peers whose signing identifier does not start with this cannot drive
    /// the daemons.
    static let allowedIdentifierPrefix = "Agent.app.toddbruss"

    /// Build a Code Signing requirement string describing acceptable peers.
    /// Returns nil if the daemon is ad-hoc signed and no Team ID is available
    /// — callers should then fall back to `selfCDHashRequirement()`.
    static func teamBasedRequirement() -> String? {
        guard let teamID = ownTeamIdentifier(), !teamID.isEmpty else {
            return nil
        }
        // anchor apple generic = signed in the Apple cert chain
        // certificate leaf[subject.OU] = the exact Team ID of the daemon itself
        // identifier ... = only our app, not every app the developer ships
        return "anchor apple generic "
            + "and certificate leaf[subject.OU] = \"\(teamID)\" "
            + "and identifier \"\(allowedIdentifierPrefix)\""
    }

    /// Fallback requirement for ad-hoc signed builds: the peer must have the
    /// same CDHash as the daemon itself. This means only the exact same build
    /// sitting next to the daemon on disk can connect.
    static func selfCDHashRequirement() -> String? {
        guard let hash = ownCDHashHex() else { return nil }
        return "cdhash H\"\(hash)\""
    }

    /// Best-effort requirement: prefer team-based, fall back to cdhash.
    static func preferredRequirement() -> String? {
        teamBasedRequirement() ?? selfCDHashRequirement()
    }

    /// Install the preferred code-signing requirement on a listener. On macOS
    /// versions that don't support the API, this is a no-op and the delegate
    /// will still perform manual validation.
    static func install(on listener: NSXPCListener) {
        guard let requirement = preferredRequirement() else {
            NSLog("XPCPeerValidator: no requirement available; manual validation only")
            return
        }
        if #available(macOS 13.0, *) {
            do {
                try listener.setCodeSigningRequirement(requirement)
            } catch {
                NSLog("XPCPeerValidator: setCodeSigningRequirement failed: \(error)")
            }
        }
    }

    /// Returns true when the peer on the far end of `connection` satisfies
    /// `preferredRequirement()`. Safe to call from `shouldAcceptNewConnection`.
    static func accept(_ connection: NSXPCConnection) -> Bool {
        guard let requirement = preferredRequirement() else {
            NSLog("XPCPeerValidator: rejecting — no requirement could be built")
            return false
        }

        var secRequirement: SecRequirement?
        let compileStatus = SecRequirementCreateWithString(
            requirement as CFString, [], &secRequirement
        )
        guard compileStatus == errSecSuccess, let req = secRequirement else {
            NSLog("XPCPeerValidator: rejecting — requirement compile failed (\(compileStatus))")
            return false
        }

        let auditToken = connection.auditToken
        let tokenData = withUnsafeBytes(of: auditToken) { Data($0) }
        let attributes: [CFString: Any] = [
            kSecGuestAttributeAudit: tokenData
        ]

        var peerCode: SecCode?
        let copyStatus = SecCodeCopyGuestWithAttributes(
            nil, attributes as CFDictionary, [], &peerCode
        )
        guard copyStatus == errSecSuccess, let code = peerCode else {
            NSLog("XPCPeerValidator: rejecting — SecCodeCopyGuestWithAttributes failed (\(copyStatus))")
            return false
        }

        guard let staticCode = staticCode(from: code) else {
            NSLog("XPCPeerValidator: rejecting — could not derive SecStaticCode")
            return false
        }

        let flags = SecCSFlags(rawValue: kSecCSDefaultFlags)
        let checkStatus = SecStaticCodeCheckValidity(staticCode, flags, req)
        if checkStatus != errSecSuccess {
            NSLog("XPCPeerValidator: rejecting — SecStaticCodeCheckValidity failed (\(checkStatus))")
            return false
        }

        return true
    }

    /// Convert a live `SecCode` into a `SecStaticCode` (the on-disk view of
    /// the same code) so we can pass it to APIs that require the static type.
    private static func staticCode(from code: SecCode) -> SecStaticCode? {
        var out: SecStaticCode?
        let status = SecCodeCopyStaticCode(code, [], &out)
        guard status == errSecSuccess else { return nil }
        return out
    }

    // MARK: - Introspection of our own signature

    /// Read our own signing info and return the Team ID, or nil if unsigned/ad-hoc.
    private static func ownTeamIdentifier() -> String? {
        guard let info = ownSigningInfo() else { return nil }
        return info[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Read our own signing info and return the CDHash as a lowercase hex string.
    private static func ownCDHashHex() -> String? {
        guard let info = ownSigningInfo() else { return nil }
        guard let cdhash = info[kSecCodeInfoUnique as String] as? Data else { return nil }
        return cdhash.map { String(format: "%02x", $0) }.joined()
    }

    /// Copy signing information for the current process.
    private static func ownSigningInfo() -> [String: Any]? {
        var selfCode: SecCode?
        let selfStatus = SecCodeCopySelf([], &selfCode)
        guard selfStatus == errSecSuccess, let code = selfCode else { return nil }

        guard let staticCode = staticCode(from: code) else { return nil }

        var cfInfo: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        let infoStatus = SecCodeCopySigningInformation(staticCode, flags, &cfInfo)
        guard infoStatus == errSecSuccess, let dict = cfInfo as? [String: Any] else {
            return nil
        }
        return dict
    }
}

