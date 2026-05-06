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
/// across coordinator types in a future release.
///
/// > Important: This type ships as 5.0 preparation. In 4.x it has
/// > no producers in the SDK — declaring or holding a
/// > `LifecycleSignals` instance has no observable effect today.
/// > Adopters should not depend on which signals fire from which
/// > store until 5.0 finalises the wiring.
///
/// The 5.0 contract will route the following signals through this
/// type:
///
/// - ``onParentCancel`` — fired when the immediate parent cancels
///   (today exposed only on `ChildCoordinator.parentDidCancel()`).
/// - ``onTeardown`` — fired when the coordinator is being released
///   so transient resources (subscriptions, timers, in-flight
///   network requests) can be cancelled.
///
/// Both callbacks are `@MainActor @Sendable` because every current
/// coordinator surface is `@MainActor`-isolated.
@MainActor
public struct LifecycleSignals: Sendable {

    /// Invoked when the immediate parent cancels.
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
    ///
    /// Producers (today: a future 5.0 wiring) call this; consumers
    /// install handlers at coordinator init.
    public func fireParentCancel() {
        onParentCancel?()
    }

    /// Fires the ``onTeardown`` handler if installed.
    public func fireTeardown() {
        onTeardown?()
    }
}
