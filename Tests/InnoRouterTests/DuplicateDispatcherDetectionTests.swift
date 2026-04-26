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
            existing: nil as Probe?,
            replacement: nil as Probe?
        )
        #expect(result == false)
    }

    @Test("returns false when only the existing slot is populated (clear)")
    func existingOnly_returnsFalse() {
        let existing = Probe()
        let result = detectDuplicateDispatcher(
            existing: existing,
            replacement: nil as Probe?
        )
        #expect(result == false)
    }

    @Test("returns false when only the replacement is populated (initial set)")
    func replacementOnly_returnsFalse() {
        let replacement = Probe()
        let result = detectDuplicateDispatcher(
            existing: nil as Probe?,
            replacement: replacement
        )
        #expect(result == false)
    }

    @Test("returns false when existing and replacement are the same instance")
    func sameInstance_returnsFalse() {
        let dispatcher = Probe()
        let result = detectDuplicateDispatcher(
            existing: dispatcher,
            replacement: dispatcher
        )
        #expect(result == false)
    }

    @Test("returns true when replacement is a different instance")
    func differentInstance_returnsTrue() {
        let existing = Probe()
        let replacement = Probe()
        let result = detectDuplicateDispatcher(
            existing: existing,
            replacement: replacement
        )
        #expect(result == true)
    }
}

private final class Probe {
    init() {}
}
