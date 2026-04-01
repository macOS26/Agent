import Foundation

/// Known accessibility action and role IDs for permission gating.
public enum AccessibilityEnabledIDs {
    /// Core UI actions - buttons, menus, controls
    public static let axCoreActions: [(id: String, label: String)] = [
        ("AXPress", "AXPress"),
        ("AXConfirm", "AXConfirm"),
        ("AXActivate", "AXActivate"),
        ("AXCancel", "AXCancel"),
        ("AXShowMenu", "AXShowMenu"),
        ("AXDismiss", "AXDismiss"),
    ]

    /// Value adjustment - sliders, steppers, progress
    public static let axValueActions: [(id: String, label: String)] = [
        ("AXIncrement", "AXIncrement"),
        ("AXDecrement", "AXDecrement"),
    ]

    /// Disclosure - expandable content, outlines
    public static let axDisclosureActions: [(id: String, label: String)] = [
        ("AXExpand", "AXExpand"),
        ("AXCollapse", "AXCollapse"),
        ("AXOpen", "AXOpen"),
    ]

    /// Window management
    public static let axWindowActions: [(id: String, label: String)] = [
        ("AXRaise", "AXRaise"),
        ("AXZoom", "AXZoom"),
        ("AXMinimize", "AXMinimize"),
    ]

    /// Text/clipboard operations
    public static let axTextActions: [(id: String, label: String)] = [
        ("AXCopy", "AXCopy"),
        ("AXCut", "AXCut"),
        ("AXPaste", "AXPaste"),
        ("AXSelect", "AXSelect"),
        ("AXSelectAll", "AXSelectAll"),
    ]

    /// Scroll operations
    public static let axScrollActions: [(id: String, label: String)] = [
        ("AXScrollToVisible", "AXScrollToVisible"),
    ]

    /// Focus operation
    public static let axFocusActions: [(id: String, label: String)] = [
        ("AXFocus", "AXFocus"),
    ]

    /// All AX actions combined
    public static var axActions: [(id: String, label: String)] {
        axCoreActions + axValueActions + axDisclosureActions + axWindowActions + axTextActions + axScrollActions + axFocusActions
    }

    /// Restricted roles (password fields, etc.)
    public static let axRoles: [(id: String, label: String)] = [
        ("AXSecureTextField", "AXSecureTextField"),
        ("AXPasswordField", "AXPasswordField"),
        ("AXSecureText", "AXSecureText"),
    ]

    /// All known IDs (actions + roles)
    public static let allAxIds: Set<String> = {
        Set(axActions.map(\.id) + axRoles.map(\.id))
    }()
}
