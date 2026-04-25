// MARK: - AnyNavigatorResultParityTests.swift
// InnoRouterTests - parity coverage for AnyNavigator / AnyBatchNavigator return surfaces
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import InnoRouter
@testable import InnoRouterSwiftUI

/// AnyNavigator and AnyBatchNavigator both expose convenience methods that
/// mirror NavigationCommand semantics. Both types must surface the same
/// engine-level outcomes so callers can pick either erasure without losing
/// observability.
@Suite("AnyNavigator Result Parity Tests")
struct AnyNavigatorResultParityTests {

    private enum ParityRoute: Route {
        case home
        case detail
    }

    @Test("AnyNavigator.pop on empty stack returns .emptyStack")
    @MainActor
    func testAnyNavigatorPopEmptyStack() {
        let store = NavigationStore<ParityRoute>()
        let any = AnyNavigator(store)

        let result = any.pop()

        #expect(result == .emptyStack)
    }

    @Test("AnyBatchNavigator.pop on empty stack returns .emptyStack")
    @MainActor
    func testAnyBatchNavigatorPopEmptyStack() {
        let store = NavigationStore<ParityRoute>()
        let any = AnyBatchNavigator(store)

        let result = any.pop()

        #expect(result == .emptyStack)
    }

    @Test("AnyNavigator.popToRoot is idempotent and surfaces .success")
    @MainActor
    func testAnyNavigatorPopToRootEmptyStack() {
        let store = NavigationStore<ParityRoute>()
        let any = AnyNavigator(store)

        // popToRoot is engine-level idempotent — clearing an empty stack is
        // still success. The contract verified here is that the typed result
        // mirrors NavigationStore.execute(.popToRoot) exactly.
        let result = any.popToRoot()

        #expect(result == .success)
    }

    @Test("AnyBatchNavigator.popToRoot is idempotent and surfaces .success")
    @MainActor
    func testAnyBatchNavigatorPopToRootEmptyStack() {
        let store = NavigationStore<ParityRoute>()
        let any = AnyBatchNavigator(store)

        let result = any.popToRoot()

        #expect(result == .success)
    }

    @Test("AnyNavigator.push surfaces success on populated stack")
    @MainActor
    func testAnyNavigatorPushSucceeds() {
        let store = NavigationStore<ParityRoute>()
        let any = AnyNavigator(store)

        let pushHome = any.push(.home)
        let pushDetail = any.push(.detail)

        #expect(pushHome == .success)
        #expect(pushDetail == .success)
        #expect(store.state.path == [.home, .detail])
    }

    @Test("AnyNavigator.replace surfaces success and reflects state")
    @MainActor
    func testAnyNavigatorReplaceSucceeds() {
        let store = NavigationStore<ParityRoute>()
        let any = AnyNavigator(store)
        any.push(.home)

        let replaced = any.replace(with: [.detail])

        #expect(replaced == .success)
        #expect(store.state.path == [.detail])
    }

    @Test("Erasures agree with the raw NavigationStore for identical inputs")
    @MainActor
    func testErasureParityAgainstRawStore() {
        let raw = NavigationStore<ParityRoute>()
        let anyStore = NavigationStore<ParityRoute>()
        let batchStore = NavigationStore<ParityRoute>()
        let any = AnyNavigator(anyStore)
        let batch = AnyBatchNavigator(batchStore)

        let rawPop = raw.execute(.pop)
        let anyPop = any.pop()
        let batchPop = batch.pop()

        #expect(rawPop == anyPop)
        #expect(rawPop == batchPop)

        let rawPopRoot = raw.execute(.popToRoot)
        let anyPopRoot = any.popToRoot()
        let batchPopRoot = batch.popToRoot()

        #expect(rawPopRoot == anyPopRoot)
        #expect(rawPopRoot == batchPopRoot)
    }
}
