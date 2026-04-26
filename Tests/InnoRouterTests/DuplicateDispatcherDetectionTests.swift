// MARK: - DuplicateDispatcherDetectionTests.swift
// InnoRouterTests - covers the pure detection rule shared by the
// three *EnvironmentStorage setters. The reporting variant traps via
// `assertionFailure` in Debug, which Swift Testing cannot catch
// without aborting the suite, so the trap path is intentionally not
// exercised here — `Sources/NavigationEnvironmentFailFastProbe`
// already gates fail-fast assertions of this shape from the
// principle-gates script.
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing

@testable import InnoRouterSwiftUI

@Suite("DuplicateDispatcherDetection")
@MainActor
struct DuplicateDispatcherDetectionTests {

    @Test("returns false when both sides are nil")
    func bothNil_returnsFalse() {
        let result = detectDuplicateDispatcher(
            existing: nil as DispatcherRegistration<Probe>?,
            replacement: nil as DispatcherRegistration<Probe>?
        )
        #expect(result == false)
    }

    @Test("returns false when only the existing slot is populated (clear)")
    func existingOnly_returnsFalse() {
        let owner = Owner()
        let existing = registration(owner: owner)
        let result = detectDuplicateDispatcher(
            existing: existing,
            replacement: nil as DispatcherRegistration<Probe>?
        )
        #expect(result == false)
    }

    @Test("returns false when only the replacement is populated (initial set)")
    func replacementOnly_returnsFalse() {
        let owner = Owner()
        let replacement = registration(owner: owner)
        let result = detectDuplicateDispatcher(
            existing: nil as DispatcherRegistration<Probe>?,
            replacement: replacement
        )
        #expect(result == false)
    }

    @Test("returns false when existing and replacement are the same instance")
    func sameInstance_returnsFalse() {
        let owner = Owner()
        let dispatcher = Probe()
        let result = detectDuplicateDispatcher(
            existing: registration(dispatcher: dispatcher, owner: owner),
            replacement: registration(dispatcher: dispatcher, owner: owner)
        )
        #expect(result == false)
    }

    @Test("returns false when the same owner refreshes with a different dispatcher instance")
    func sameOwnerDifferentInstance_returnsFalse() {
        let owner = Owner()
        let result = detectDuplicateDispatcher(
            existing: registration(dispatcher: Probe(), owner: owner),
            replacement: registration(dispatcher: Probe(), owner: owner)
        )
        #expect(result == false)
    }

    @Test("returns true when replacement is owned by a different authority")
    func differentOwner_returnsTrue() {
        let firstOwner = Owner()
        let secondOwner = Owner()
        let result = detectDuplicateDispatcher(
            existing: registration(owner: firstOwner),
            replacement: registration(owner: secondOwner)
        )
        #expect(result == true)
    }
}

private final class Probe {
    init() {}
}

private final class Owner {
    init() {}
}

@MainActor
private func registration(
    dispatcher: Probe = Probe(),
    owner: Owner
) -> DispatcherRegistration<Probe> {
    DispatcherRegistration(
        dispatcher: dispatcher,
        ownerID: ObjectIdentifier(owner)
    )
}
