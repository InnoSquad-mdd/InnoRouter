// MARK: - ChildCoordinatorLifecycleSignalsTests.swift
// InnoRouterTests - 5.0 ChildCoordinator.lifecycleSignals routing.
// Copyright © 2026 Inno Squad. All rights reserved.

import SwiftUI
import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum CancelRoute: Route {
    case home
}

@MainActor
private final class CancelParent: Coordinator {
    typealias RouteType = CancelRoute
    let store = NavigationStore<CancelRoute>()
    @ViewBuilder
    func destination(for route: CancelRoute) -> some View {
        EmptyView()
    }
}

@MainActor
private final class SignalsChild: ChildCoordinator {
    typealias Result = Int
    var onFinish: (@MainActor @Sendable (Int) -> Void)?
    var onCancel: (@MainActor @Sendable () -> Void)?
    var lifecycleSignals: LifecycleSignals = LifecycleSignals()
    private(set) var parentDidCancelCount: Int = 0

    func parentDidCancel() {
        parentDidCancelCount += 1
    }
}

@Suite("ChildCoordinator.lifecycleSignals routing")
struct ChildCoordinatorLifecycleSignalsTests {

    @Test("parent task cancellation fires both parentDidCancel() and lifecycleSignals.onParentCancel")
    @MainActor
    func parentCancel_firesBothSignals() async {
        let parent = CancelParent()
        let child = SignalsChild()

        var lifecycleFired = 0
        child.lifecycleSignals.onParentCancel = { lifecycleFired += 1 }

        let task = parent.push(child: child)
        task.cancel()

        let result = await task.value
        // Yield once so the @MainActor cancellation hop runs.
        await Task.yield()

        #expect(result == nil)
        #expect(child.parentDidCancelCount == 1)
        #expect(lifecycleFired == 1)
    }

    @Test("a child without an installed lifecycleSignals handler still receives parentDidCancel()")
    @MainActor
    func parentCancel_whenSignalNotInstalled_doesNotCrash() async {
        let parent = CancelParent()
        let child = SignalsChild()
        // Do NOT install onParentCancel.

        let task = parent.push(child: child)
        task.cancel()

        _ = await task.value
        await Task.yield()

        #expect(child.parentDidCancelCount == 1)
    }
}
