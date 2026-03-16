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
}
