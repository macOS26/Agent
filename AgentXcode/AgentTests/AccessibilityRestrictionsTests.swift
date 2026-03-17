import Testing
import Foundation
@testable import Agent_

@Suite("AccessibilityRestrictions")
@MainActor
struct AccessibilityRestrictionsTests {

    let restrictions = AccessibilityRestrictions.shared

    // MARK: - Default State

    @Test("All restrictions enabled by default")
    func allEnabledByDefault() {
        // Every known ID should be in enabledRestrictions on a fresh state
        for id in AccessibilityRestrictions.allIds {
            #expect(restrictions.isEnabled(id), "Expected \(id) to be enabled by default")
        }
    }

    // MARK: - AX Action: toggle AXPress

    @Test("AX Action: AXPress enabled means not restricted")
    func axActionEnabledNotRestricted() {
        // Ensure AXPress is enabled
        if !restrictions.isEnabled("AXPress") {
            restrictions.toggle("AXPress")
        }
        #expect(restrictions.isEnabled("AXPress"))
        #expect(!restrictions.isRestricted("AXPress"))
    }

    @Test("AX Action: disabling AXPress makes it restricted")
    func axActionDisabledIsRestricted() {
        // Ensure enabled first, then disable
        if !restrictions.isEnabled("AXPress") {
            restrictions.toggle("AXPress")
        }
        restrictions.toggle("AXPress") // disable
        #expect(!restrictions.isEnabled("AXPress"))
        #expect(restrictions.isRestricted("AXPress"))

        // Restore
        restrictions.toggle("AXPress")
    }

    // MARK: - AX Role: toggle AXSecureTextField

    @Test("AX Role: AXSecureTextField enabled means not restricted")
    func axRoleEnabledNotRestricted() {
        if !restrictions.isEnabled("AXSecureTextField") {
            restrictions.toggle("AXSecureTextField")
        }
        #expect(restrictions.isEnabled("AXSecureTextField"))
        #expect(!restrictions.isRestricted("AXSecureTextField"))
    }

    @Test("AX Role: disabling AXSecureTextField makes it restricted")
    func axRoleDisabledIsRestricted() {
        if !restrictions.isEnabled("AXSecureTextField") {
            restrictions.toggle("AXSecureTextField")
        }
        restrictions.toggle("AXSecureTextField") // disable
        #expect(!restrictions.isEnabled("AXSecureTextField"))
        #expect(restrictions.isRestricted("AXSecureTextField"))

        // Restore
        restrictions.toggle("AXSecureTextField")
    }

    // MARK: - AE Write Selector: toggle delete

    @Test("AE Selector: delete enabled means not restricted")
    func aeSelectorEnabledNotRestricted() {
        if !restrictions.isEnabled("delete") {
            restrictions.toggle("delete")
        }
        #expect(restrictions.isEnabled("delete"))
        #expect(!restrictions.isRestricted("delete"))
    }

    @Test("AE Selector: disabling delete makes it restricted")
    func aeSelectorDisabledIsRestricted() {
        if !restrictions.isEnabled("delete") {
            restrictions.toggle("delete")
        }
        restrictions.toggle("delete") // disable
        #expect(!restrictions.isEnabled("delete"))
        #expect(restrictions.isRestricted("delete"))

        // Restore
        restrictions.toggle("delete")
    }

    // MARK: - Toggle is idempotent round-trip

    @Test("Toggle round-trip restores original state")
    func toggleRoundTrip() {
        let id = "AXConfirm"
        let original = restrictions.isEnabled(id)
        restrictions.toggle(id)
        #expect(restrictions.isEnabled(id) != original)
        restrictions.toggle(id)
        #expect(restrictions.isEnabled(id) == original)
    }

    // MARK: - Unknown IDs

    @Test("Unknown ID is restricted by default")
    func unknownIdRestricted() {
        #expect(restrictions.isRestricted("SomeUnknownAction"))
        #expect(!restrictions.isEnabled("SomeUnknownAction"))
    }

    // MARK: - All Apple Event Write Selectors

    static let allWriteSelectors = [
        "delete", "close", "remove", "quit", "move",
        "moveTo", "duplicate", "save", "set", "sendMessage"
    ]

    @Test("All write selectors enabled by default")
    func allWriteSelectorsEnabled() {
        for sel in Self.allWriteSelectors {
            #expect(restrictions.isEnabled(sel), "Expected '\(sel)' to be enabled by default")
            #expect(!restrictions.isRestricted(sel), "Expected '\(sel)' to not be restricted when enabled")
        }
    }

    @Test("Each write selector can be disabled and re-enabled")
    func writeSelectorsToggle() {
        for sel in Self.allWriteSelectors {
            // Ensure enabled
            if !restrictions.isEnabled(sel) { restrictions.toggle(sel) }
            #expect(restrictions.isEnabled(sel))

            // Disable
            restrictions.toggle(sel)
            #expect(!restrictions.isEnabled(sel), "'\(sel)' should be disabled after toggle")
            #expect(restrictions.isRestricted(sel), "'\(sel)' should be restricted when disabled")

            // Re-enable
            restrictions.toggle(sel)
            #expect(restrictions.isEnabled(sel), "'\(sel)' should be re-enabled after second toggle")
            #expect(!restrictions.isRestricted(sel), "'\(sel)' should not be restricted when re-enabled")
        }
    }

    @Test("close: enabled = allowed, disabled = blocked")
    func closeSelector() {
        if !restrictions.isEnabled("close") { restrictions.toggle("close") }
        #expect(!restrictions.isRestricted("close"))
        restrictions.toggle("close")
        #expect(restrictions.isRestricted("close"))
        restrictions.toggle("close") // restore
    }

    @Test("remove: enabled = allowed, disabled = blocked")
    func removeSelector() {
        if !restrictions.isEnabled("remove") { restrictions.toggle("remove") }
        #expect(!restrictions.isRestricted("remove"))
        restrictions.toggle("remove")
        #expect(restrictions.isRestricted("remove"))
        restrictions.toggle("remove") // restore
    }

    @Test("quit: enabled = allowed, disabled = blocked")
    func quitSelector() {
        if !restrictions.isEnabled("quit") { restrictions.toggle("quit") }
        #expect(!restrictions.isRestricted("quit"))
        restrictions.toggle("quit")
        #expect(restrictions.isRestricted("quit"))
        restrictions.toggle("quit") // restore
    }

    @Test("move: enabled = allowed, disabled = blocked")
    func moveSelector() {
        if !restrictions.isEnabled("move") { restrictions.toggle("move") }
        #expect(!restrictions.isRestricted("move"))
        restrictions.toggle("move")
        #expect(restrictions.isRestricted("move"))
        restrictions.toggle("move") // restore
    }

    @Test("moveTo: enabled = allowed, disabled = blocked")
    func moveToSelector() {
        if !restrictions.isEnabled("moveTo") { restrictions.toggle("moveTo") }
        #expect(!restrictions.isRestricted("moveTo"))
        restrictions.toggle("moveTo")
        #expect(restrictions.isRestricted("moveTo"))
        restrictions.toggle("moveTo") // restore
    }

    @Test("duplicate: enabled = allowed, disabled = blocked")
    func duplicateSelector() {
        if !restrictions.isEnabled("duplicate") { restrictions.toggle("duplicate") }
        #expect(!restrictions.isRestricted("duplicate"))
        restrictions.toggle("duplicate")
        #expect(restrictions.isRestricted("duplicate"))
        restrictions.toggle("duplicate") // restore
    }

    @Test("save: enabled = allowed, disabled = blocked")
    func saveSelector() {
        if !restrictions.isEnabled("save") { restrictions.toggle("save") }
        #expect(!restrictions.isRestricted("save"))
        restrictions.toggle("save")
        #expect(restrictions.isRestricted("save"))
        restrictions.toggle("save") // restore
    }

    @Test("set: enabled = allowed, disabled = blocked")
    func setSelector() {
        if !restrictions.isEnabled("set") { restrictions.toggle("set") }
        #expect(!restrictions.isRestricted("set"))
        restrictions.toggle("set")
        #expect(restrictions.isRestricted("set"))
        restrictions.toggle("set") // restore
    }

    @Test("sendMessage: enabled = allowed, disabled = blocked")
    func sendMessageSelector() {
        if !restrictions.isEnabled("sendMessage") { restrictions.toggle("sendMessage") }
        #expect(!restrictions.isRestricted("sendMessage"))
        restrictions.toggle("sendMessage")
        #expect(restrictions.isRestricted("sendMessage"))
        restrictions.toggle("sendMessage") // restore
    }

    // MARK: - Non-write methods should never be in the restriction set

    @Test("Non-write methods are not known restriction IDs")
    func nonWriteMethodsNotInAllIds() {
        let readMethods = ["playlists", "searchFor", "currentTrack", "accounts",
                           "mailboxes", "folders", "notes", "reminders", "windows",
                           "documents", "paragraphs", "tracks", "name", "artist"]
        for method in readMethods {
            #expect(!AccessibilityRestrictions.allIds.contains(method),
                    "'\(method)' should NOT be in allIds — it's a read method")
        }
    }
}
