// MARK: - ConfigurationMutationTests.swift
// InnoRouterTests - covers `var public` exposure of the three
// `*Configuration` structs introduced in v4.0.0.
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation
import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum CfgRoute: Route {
    case home
}

@Suite("Configuration mutation")
@MainActor
struct ConfigurationMutationTests {

    @Test("NavigationStoreConfiguration callbacks can be patched after construction")
    func navigationConfig_callbacksArePatchable() {
        var config = NavigationStoreConfiguration<CfgRoute>()
        #expect(config.onChange == nil)
        #expect(config.onPathMismatch == nil)

        config.onChange = { _, _ in }
        config.onPathMismatch = { _ in }

        #expect(config.onChange != nil)
        #expect(config.onPathMismatch != nil)
    }

    @Test("ModalStoreConfiguration callbacks can be patched after construction")
    func modalConfig_callbacksArePatchable() {
        var config = ModalStoreConfiguration<CfgRoute>()
        #expect(config.onPresented == nil)
        #expect(config.onCommandIntercepted == nil)

        config.onPresented = { _ in }
        config.onCommandIntercepted = { _, _ in }

        #expect(config.onPresented != nil)
        #expect(config.onCommandIntercepted != nil)
    }

    @Test("FlowStoreConfiguration nested configs can be patched after construction")
    func flowConfig_nestedConfigsArePatchable() {
        var config = FlowStoreConfiguration<CfgRoute>()
        #expect(config.navigation.onChange == nil)
        #expect(config.modal.onPresented == nil)

        config.navigation.onChange = { _, _ in }
        config.modal.onPresented = { _ in }
        config.onPathChanged = { _, _ in }

        #expect(config.navigation.onChange != nil)
        #expect(config.modal.onPresented != nil)
        #expect(config.onPathChanged != nil)
    }

    @Test("Patched configuration constructs a working store")
    func patchedConfig_constructsStore() {
        var config = NavigationStoreConfiguration<CfgRoute>()
        var observed = 0
        config.onChange = { _, _ in observed += 1 }

        let store = NavigationStore<CfgRoute>(configuration: config)
        store.execute(.push(.home))

        #expect(observed == 1)
        #expect(store.state.path == [.home])
    }
}
