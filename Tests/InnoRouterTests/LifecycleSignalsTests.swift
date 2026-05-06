// MARK: - LifecycleSignalsTests.swift
// InnoRouterTests - LifecycleSignals callback bag (5.0 prep)
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing

import InnoRouterSwiftUI

@Suite("LifecycleSignals")
@MainActor
struct LifecycleSignalsTests {

    @Test("fireParentCancel invokes the installed onParentCancel handler")
    func fireParentCancel_invokesHandler() {
        var fired = 0
        let signals = LifecycleSignals(onParentCancel: { fired += 1 })

        signals.fireParentCancel()

        #expect(fired == 1)
    }

    @Test("fireTeardown invokes the installed onTeardown handler")
    func fireTeardown_invokesHandler() {
        var fired = 0
        let signals = LifecycleSignals(onTeardown: { fired += 1 })

        signals.fireTeardown()

        #expect(fired == 1)
    }

    @Test("firing without an installed handler is a no-op")
    func firingEmptySignals_isNoop() {
        let signals = LifecycleSignals()

        signals.fireParentCancel()
        signals.fireTeardown()
        // No assertion — the test passes if neither call traps.
    }

    @Test("the two handlers are independent")
    func handlers_areIndependent() {
        var parentFired = 0
        var teardownFired = 0
        let signals = LifecycleSignals(
            onParentCancel: { parentFired += 1 },
            onTeardown: { teardownFired += 1 }
        )

        signals.fireParentCancel()

        #expect(parentFired == 1)
        #expect(teardownFired == 0)
    }
}
