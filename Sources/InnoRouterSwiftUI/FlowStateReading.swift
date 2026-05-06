// MARK: - FlowStateReading.swift
// InnoRouterSwiftUI - public read contract for FlowStore-shaped
// state. Replaces the @_spi(FlowStoreInternals) inner-store
// peephole as of 5.0.
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore

/// Read-only view of the FlowStore-shaped flow state.
///
/// `FlowStore` conforms via projections derived from the public
/// `path` accessor. Tests, telemetry adapters, and migration
/// helpers should target this protocol rather than reaching into
/// the inner navigation or modal store — those are deliberately
/// internal as of 5.0.
@MainActor
public protocol FlowStateReading<R>: Sendable {
    associatedtype R: Route

    /// The full flow timeline — push prefix plus optional
    /// trailing modal step. Mirrors `FlowStore.path`.
    var path: [RouteStep<R>] { get }

    /// The push prefix of `path` projected as plain routes (i.e.
    /// the same routes that would be visible in a
    /// `NavigationStack(path:)`).
    var navigationPath: [R] { get }

    /// The currently visible modal route if `path` ends in a
    /// `.sheet(_)` or `.cover(_)` step, otherwise `nil`.
    var currentModalRoute: R? { get }

    /// The currently visible modal presentation if `path` ends in
    /// a modal step, including its presentation style. Returns
    /// `nil` when there is no trailing modal.
    var currentModalPresentation: ModalPresentation<R>? { get }

    /// Whether the flow currently has a trailing modal step. Equivalent
    /// to `currentModalRoute != nil`, surfaced as a named predicate
    /// so call sites read as intent rather than a nil check.
    var hasModalTail: Bool { get }
}

extension FlowStore: FlowStateReading {
    public var navigationPath: [R] {
        path.compactMap { step in
            if case .push(let route) = step { return route }
            return nil
        }
    }

    public var currentModalRoute: R? {
        guard let last = path.last else { return nil }
        switch last {
        case .sheet(let route), .cover(let route):
            return route
        case .push:
            return nil
        }
    }

    public var currentModalPresentation: ModalPresentation<R>? {
        guard let last = path.last else { return nil }
        switch last {
        case .sheet(let route):
            return ModalPresentation(route: route, style: .sheet)
        case .cover(let route):
            return ModalPresentation(route: route, style: .fullScreenCover)
        case .push:
            return nil
        }
    }

    public var hasModalTail: Bool {
        currentModalRoute != nil
    }
}
