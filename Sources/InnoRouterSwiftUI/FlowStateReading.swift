// MARK: - FlowStateReading.swift
// InnoRouterSwiftUI - non-SPI read contract for FlowStore-shaped
// state, prepared for 5.0's inner-store encapsulation.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// FlowStore exposes its inner navigation + modal stores through
// `@_spi(FlowStoreInternals)` so tests and FlowHost can reach the
// nested authority surface without giving every adopter a foothold
// into FlowStore's internals. The SPI works, but it leaks the
// concrete `NavigationStore` / `ModalStore` types — replacing the
// inner-store implementation later (a 5.0 goal) would necessarily
// be a breaking change.
//
// `FlowStateReading` is the non-SPI read contract that lets host
// code, telemetry adapters, and migration helpers express what
// they actually need from a flow store ("current push stack,
// current modal, queued modals") without holding the inner store
// references. Today it is purely additive: the existing SPI
// remains the primary consumer interface, the protocol just
// documents the shape so 5.0 can swap the SPI for this
// without churning every call site.

import InnoRouterCore

/// Read-only view of the FlowStore-shaped flow state that 5.0
/// will adopt as the canonical inner-state accessor.
///
/// > Note: In 4.2.0 this protocol is observational. Adopters
/// > should not yet drop their SPI imports — the protocol exists
/// > here so the 5.0 wiring lands as a behaviour-preserving swap
/// > rather than a new public surface at major-bump time.
@MainActor
public protocol FlowStateReading<R> {
    associatedtype R: Route

    /// The full flow timeline — push prefix plus optional
    /// trailing modal step. This is the same value `FlowStore.path`
    /// already exposes; the protocol surfaces it as a contract so
    /// 5.0 implementers can target the protocol rather than a
    /// specific concrete type.
    var path: [RouteStep<R>] { get }

    /// The push prefix of `path` projected as plain routes (i.e.
    /// the same routes that would be visible in a
    /// `NavigationStack(path:)`).
    var navigationPath: [R] { get }

    /// The currently visible modal route if `path` ends in a
    /// `.sheet(_)` or `.cover(_)` step, otherwise `nil`.
    var currentModalRoute: R? { get }
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
}
