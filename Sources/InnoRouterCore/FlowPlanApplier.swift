// MARK: - FlowPlanApplier.swift
// InnoRouterCore - cross-module bridge for applying FlowPlan values
// Copyright © 2026 Inno Squad. All rights reserved.

/// A MainActor-isolated authority that can apply a ``FlowPlan`` as a
/// single coordinated operation.
///
/// This protocol exists so higher-level modules (deep-link effect
/// handlers, URL routers, state restoration drivers) can depend on
/// InnoRouterCore without pulling in the SwiftUI-layer `FlowStore`
/// type directly. `FlowStore` in `InnoRouterSwiftUI` already ships
/// `apply(_ plan:)` and conforms to this protocol in an extension.
///
/// Conforming types are expected to honour the `FlowStore`
/// invariants that a `FlowPlan` already respects: at most one modal
/// step, and a modal step only at the tail of the path.
@MainActor
public protocol FlowPlanApplier<RouteType>: AnyObject, Sendable {
    associatedtype RouteType: Route

    /// Applies `plan` to the underlying authority. The call is
    /// expected to complete synchronously on the main actor so the
    /// caller can observe the resulting state immediately.
    func apply(_ plan: FlowPlan<RouteType>)
}
