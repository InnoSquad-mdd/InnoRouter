// MARK: - LifecycleSignals.swift
// InnoRouterSwiftUI - cross-cutting coordinator lifecycle signals
// Copyright © 2026 Inno Squad. All rights reserved.
//
// `Coordinator`, `FlowCoordinator`, `TabCoordinator`, and
// `ChildCoordinator` each carry one-off lifecycle hooks that don't
// compose: today only `ChildCoordinator` exposes
// `parentDidCancel()`, even though every coordinator could benefit
// from the same parent → child teardown signal.
//
// `LifecycleSignals` is a composition layer that 5.0 will adopt
// across every coordinator type: a small `@MainActor` value-type
// bag of optional callbacks any coordinator can install once at
// init and trigger uniformly. It is **not yet wired in 4.x** — the
// existing coordinator protocols keep their current shape, and
// `ChildCoordinator.parentDidCancel()` continues to be the only
// teardown signal.
//
// The type ships as additive surface in 4.2.0 so the 5.0 wiring
// can land without re-introducing a new public type at major-bump
// time.

import Foundation

/// A bag of optional, fire-and-forget lifecycle callbacks shared
/// across coordinator types via the ``LifecycleAware`` capability
/// protocol.
///
/// As of 5.0 the SDK routes the following signals through this
/// bag (more may be added in subsequent minors):
///
/// - ``onParentCancel`` — fired when a parent task cancels.
///   `Coordinator.push(child:)` calls this on the child after
///   invoking ``ChildCoordinator/parentDidCancel()``.
/// - ``onTeardown`` — fired when the owning coordinator is
///   released so transient resources (subscriptions, timers,
///   in-flight network requests) can be cancelled. Hosts and
///   coordinator-owning code call this from their teardown path.
///
/// Both callbacks are `@MainActor @Sendable` because every current
/// coordinator surface is `@MainActor`-isolated.
@MainActor
public struct LifecycleSignals: Sendable {

    /// Invoked when a parent task cancels. `Coordinator.push(child:)`
    /// fires this through the child's ``LifecycleAware/lifecycleSignals``.
    public var onParentCancel: (@MainActor @Sendable () -> Void)?

    /// Invoked when the owning coordinator is being released so
    /// transient state (subscriptions, timers, in-flight network
    /// requests) can be cancelled.
    public var onTeardown: (@MainActor @Sendable () -> Void)?

    public init(
        onParentCancel: (@MainActor @Sendable () -> Void)? = nil,
        onTeardown: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.onParentCancel = onParentCancel
        self.onTeardown = onTeardown
    }

    /// Fires the ``onParentCancel`` handler if installed.
    public func fireParentCancel() {
        onParentCancel?()
    }

    /// Fires the ``onTeardown`` handler if installed.
    public func fireTeardown() {
        onTeardown?()
    }
}

/// Capability protocol for any coordinator that wants to expose
/// lifecycle signals through the unified ``LifecycleSignals`` bag.
///
/// `ChildCoordinator` requires this conformance because the parent
/// push helper fires ``LifecycleSignals/fireParentCancel()`` on
/// task cancellation. Other coordinator types (`Coordinator`,
/// `FlowCoordinator`, `TabCoordinator`) opt in by adopting
/// `LifecycleAware` directly and declaring a
/// ``lifecycleSignals`` storage property.
@MainActor
public protocol LifecycleAware: AnyObject {
    /// The lifecycle-signals bag installed on this coordinator.
    /// Must be `var` so producers (push helpers, host teardown
    /// paths, future signal dispatchers) can mutate the installed
    /// handlers.
    var lifecycleSignals: LifecycleSignals { get set }
}
