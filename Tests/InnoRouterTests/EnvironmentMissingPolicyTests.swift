// MARK: - EnvironmentMissingPolicyTests.swift
// InnoRouterTests - host-backed property-wrapper missing-env coverage
// Copyright © 2026 Inno Squad. All rights reserved.

#if canImport(AppKit)
import AppKit
#endif
import SwiftUI
import Testing

import InnoRouter
import InnoRouterSwiftUI

private enum EnvMissingRoute: Route {
    case home
}

@Suite("EnvironmentMissingPolicy", .tags(.unit))
@MainActor
struct EnvironmentMissingPolicyTests {

    // MARK: - .logAndDegrade returns no-op dispatchers

    @Test(".logAndDegrade resolves a no-op navigation dispatcher through SwiftUI")
    func navigationDispatcher_logAndDegrade_send_does_not_trap() throws {
        var appeared = false

        _ = try render(
            MissingNavigationEnvProbeView {
                appeared = true
            }
            .innoRouterEnvironmentMissingPolicy(.logAndDegrade)
        )

        #expect(appeared)
    }

    @Test(".logAndDegrade resolves a no-op modal dispatcher through SwiftUI")
    func modalDispatcher_logAndDegrade_send_does_not_trap() throws {
        var appeared = false

        _ = try render(
            MissingModalEnvProbeView {
                appeared = true
            }
            .innoRouterEnvironmentMissingPolicy(.logAndDegrade)
        )

        #expect(appeared)
    }

    @Test(".logAndDegrade resolves a no-op flow dispatcher through SwiftUI")
    func flowDispatcher_logAndDegrade_send_does_not_trap() throws {
        var appeared = false

        _ = try render(
            MissingFlowEnvProbeView {
                appeared = true
            }
            .innoRouterEnvironmentMissingPolicy(.logAndDegrade)
        )

        #expect(appeared)
    }

    // MARK: - default policy is .crash

    @Test("default environment policy is .crash")
    func defaultPolicy_isCrash() {
        let environment = EnvironmentValues()
        #expect(environment.innoRouterEnvironmentMissingPolicy == .crash)
    }

    // MARK: - View modifier roundtrips

    @Test(".innoRouterEnvironmentMissingPolicy(_:) writes the environment key")
    func viewModifier_writesEnvironmentKey() throws {
        var observed: EnvironmentMissingPolicy?

        _ = try render(
            PolicyReadingProbe { policy in
                observed = policy
            }
            .innoRouterEnvironmentMissingPolicy(.logAndDegrade)
        )

        #expect(observed == .logAndDegrade)
    }

    // MARK: - .assertAndLog modifier roundtrip
    //
    // `.assertAndLog` traps via `assertionFailure` in Debug builds, so
    // the dispatcher access path cannot be exercised here without
    // aborting the test process. Coverage is limited to the
    // environment-key plumbing; the trap behaviour is already covered
    // by `Sources/NavigationEnvironmentFailFastProbe`, which fails the
    // gate when the missing-host crash path stops trapping.

    @Test(".innoRouterEnvironmentMissingPolicy(.assertAndLog) writes the environment key")
    func viewModifier_writesAssertAndLogPolicy() throws {
        var observed: EnvironmentMissingPolicy?

        _ = try render(
            PolicyReadingProbe { policy in
                observed = policy
            }
            .innoRouterEnvironmentMissingPolicy(.assertAndLog)
        )

        #expect(observed == .assertAndLog)
    }

    @Test("EnvironmentMissingPolicy enumerates crash, logAndDegrade, assertAndLog")
    func policy_caseSet_isStable() {
        let cases: Set<EnvironmentMissingPolicy> = [
            .crash,
            .logAndDegrade,
            .assertAndLog,
        ]
        #expect(cases.count == 3)
    }
}

// MARK: - Probes

private struct MissingNavigationEnvProbeView: View {
    @EnvironmentNavigationIntent(EnvMissingRoute.self)
    private var dispatcher

    let onAppear: @MainActor () -> Void

    var body: some View {
        Color.clear.onAppear {
            dispatcher.send(.go(.home))
            onAppear()
        }
    }
}

private struct MissingModalEnvProbeView: View {
    @EnvironmentModalIntent(EnvMissingRoute.self)
    private var dispatcher

    let onAppear: @MainActor () -> Void

    var body: some View {
        Color.clear.onAppear {
            dispatcher.send(.present(.home, style: .sheet))
            onAppear()
        }
    }
}

private struct MissingFlowEnvProbeView: View {
    @EnvironmentFlowIntent(EnvMissingRoute.self)
    private var dispatcher

    let onAppear: @MainActor () -> Void

    var body: some View {
        Color.clear.onAppear {
            dispatcher.send(.push(.home))
            onAppear()
        }
    }
}

private struct PolicyReadingProbe: View {
    @Environment(\.innoRouterEnvironmentMissingPolicy)
    private var policy

    let onRead: @MainActor (EnvironmentMissingPolicy) -> Void

    var body: some View {
        Color.clear.onAppear {
            onRead(policy)
        }
    }
}

// MARK: - Render helper

#if canImport(AppKit)
@MainActor
@discardableResult
private func render<V: View>(_ view: V) throws -> NSHostingView<V> {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(x: 0, y: 0, width: 24, height: 24)
    hostingView.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    return hostingView
}
#else
@MainActor
private func render<V: View>(_ view: V) throws {
    throw Skip("EnvironmentMissingPolicyTests require AppKit-backed SwiftUI rendering.")
}
#endif
