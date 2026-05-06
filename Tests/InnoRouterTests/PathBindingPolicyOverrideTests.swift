// MARK: - PathBindingPolicyOverrideTests.swift
// InnoRouterTests - per-call NavigationPathMismatchPolicy override
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum BindingRoute: Route {
    case home
    case detail(Int)
    case settings
}

@Suite("pathBinding(policy:) per-call override")
@MainActor
struct PathBindingPolicyOverrideTests {

    // MARK: - Default binding uses the store-wide policy

    @Test("default pathBinding routes a non-prefix write through the configured .replace policy")
    func defaultBinding_replacePolicy_appliesNonPrefixPath() {
        let store = try! NavigationStore<BindingRoute>(
            initialPath: [.home],
            configuration: NavigationStoreConfiguration(
                pathMismatchPolicy: .replace
            )
        )

        // Drive a non-prefix change (different first element)
        // through the default binding.
        store.pathBinding.wrappedValue = [.settings, .detail(1)]

        #expect(store.state.path == [.settings, .detail(1)])
    }

    // MARK: - Per-call policy override is honored

    @Test("pathBinding(policy: .ignore) leaves the stack untouched on a non-prefix write")
    func policyOverride_ignore_leavesStackUntouched() {
        let store = try! NavigationStore<BindingRoute>(
            initialPath: [.home],
            configuration: NavigationStoreConfiguration(
                pathMismatchPolicy: .replace // store-wide is replace
            )
        )

        let scopedBinding = store.pathBinding(policy: .ignore)

        // Same non-prefix change as above; with .ignore the store
        // should not mutate.
        scopedBinding.wrappedValue = [.settings, .detail(1)]

        #expect(store.state.path == [.home])
    }

    @Test("pathBinding(policy:) does not affect other bindings on the same store")
    func policyOverride_isScopedToTheBinding() {
        let store = try! NavigationStore<BindingRoute>(
            initialPath: [.home],
            configuration: NavigationStoreConfiguration(
                pathMismatchPolicy: .replace
            )
        )

        // Acquire (but do not write through) the ignore-policy
        // binding; subsequent writes through the default binding
        // must still apply the store-wide replace.
        _ = store.pathBinding(policy: .ignore)

        store.pathBinding.wrappedValue = [.settings]
        #expect(store.state.path == [.settings])
    }

    // MARK: - Prefix changes flow normally regardless of policy

    @Test("pathBinding(policy: .ignore) still accepts a clean prefix expand")
    func policyOverride_ignore_allowsPrefixExpand() {
        let store = try! NavigationStore<BindingRoute>(
            initialPath: [.home],
            configuration: NavigationStoreConfiguration(
                pathMismatchPolicy: .ignore // even store-wide is ignore
            )
        )

        let scopedBinding = store.pathBinding(policy: .ignore)
        scopedBinding.wrappedValue = [.home, .detail(1)]

        // Prefix-expand is not a "mismatch" — it routes through the
        // normal push pipeline regardless of policy.
        #expect(store.state.path == [.home, .detail(1)])
    }
}
