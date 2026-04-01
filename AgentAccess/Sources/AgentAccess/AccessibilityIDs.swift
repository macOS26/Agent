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
        ("AXScrollPageUp", "AXScrollPageUp"),
        ("AXScrollPageDown", "AXScrollPageDown"),
        ("AXScrollPageLeft", "AXScrollPageLeft"),
        ("AXScrollPageRight", "AXScrollPageRight"),
    ]

    /// Focus operation
    public static let axFocusActions: [(id: String, label: String)] = [
        ("AXFocus", "AXFocus"),
    ]

    /// UI reveal actions
    public static let axUIActions: [(id: String, label: String)] = [
        ("AXShowDefaultUI", "AXShowDefaultUI"),
        ("AXShowAlternateUI", "AXShowAlternateUI"),
    ]

    /// Content actions
    public static let axContentActions: [(id: String, label: String)] = [
        ("AXDelete", "AXDelete"),
        ("AXPick", "AXPick"),
    ]

    /// All AX actions combined
    public static var axActions: [(id: String, label: String)] {
        axCoreActions + axValueActions + axDisclosureActions + axWindowActions + axTextActions + axScrollActions + axFocusActions + axUIActions + axContentActions
    }

    /// Restricted roles (password fields, etc.)
    public static let axRoles: [(id: String, label: String)] = [
        ("AXSecureTextField", "AXSecureTextField"),
        ("AXPasswordField", "AXPasswordField"),
        ("AXSecureText", "AXSecureText"),
    ]

    // MARK: - Well-Known Roles (for reference — not gated)

    /// Web content roles (detected automatically, not permission-gated)
    public static let webRoles: [String] = [
        "AXWebArea",        // Root of web content in Safari/Chrome
        "AXLink",           // Clickable hyperlink
        "AXImage",          // Image element
        "AXTable",          // Table element
        "AXRow",            // Table row
        "AXColumn",         // Table column
        "AXCell",           // Table cell
        "AXHeading",        // Heading (h1-h6)
        "AXList",           // List (ul/ol)
        "AXListItem",       // List item (li)
        "AXBlockQuote",     // Blockquote
        "AXForm",           // Form element
    ]

    /// Common app UI roles
    public static let appRoles: [String] = [
        "AXApplication",    // App root
        "AXWindow",         // Window
        "AXSheet",          // Sheet/dialog
        "AXDrawer",         // Drawer panel
        "AXPopover",        // Popover
        "AXDialog",         // Dialog
        "AXToolbar",        // Toolbar
        "AXTabGroup",       // Tab bar
        "AXSplitGroup",     // Split view
        "AXScrollArea",     // Scrollable area
        "AXGroup",          // Generic container
        "AXOutline",        // Outline/tree view
        "AXBrowser",        // Column browser
        "AXMenuBar",        // Menu bar
        "AXMenu",           // Menu
        "AXMenuItem",       // Menu item
        "AXButton",         // Button
        "AXCheckBox",       // Checkbox
        "AXRadioButton",    // Radio button
        "AXRadioGroup",     // Radio group
        "AXPopUpButton",    // Popup/dropdown
        "AXComboBox",       // Combo box
        "AXTextField",      // Text field
        "AXTextArea",       // Multi-line text
        "AXStaticText",     // Label
        "AXSlider",         // Slider
        "AXProgressIndicator", // Progress bar
        "AXStepper",        // Stepper
        "AXDisclosureTriangle", // Disclosure triangle
        "AXColorWell",      // Color picker
        "AXDateField",      // Date picker
    ]

    /// All known IDs (actions + roles)
    public static let allAxIds: Set<String> = {
        Set(axActions.map(\.id) + axRoles.map(\.id))
    }()
}
