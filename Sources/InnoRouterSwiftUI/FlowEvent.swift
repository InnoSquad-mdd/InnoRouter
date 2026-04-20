// MARK: - FlowEvent.swift
// InnoRouterSwiftUI - unified observable event for FlowStore
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore

/// A single event produced by a `FlowStore` observation surface.
///
/// `.pathChanged` and `.intentRejected` mirror the FlowStore-level
/// callbacks. `.navigation(...)` and `.modal(...)` wrap events from the
/// inner `NavigationStore` / `ModalStore`, so subscribers can assert
/// "this intent triggered this specific internal command sequence"
/// end-to-end from a single `AsyncStream`.
///
/// Test harnesses (`InnoRouterTesting`) reuse this type directly — the
/// legacy `FlowTestEvent<R>` is preserved as a typealias for source
/// compatibility.
public enum FlowEvent<R: Route>: Sendable, Equatable {
    /// `FlowStore` fired `onPathChanged`.
    case pathChanged(old: [RouteStep<R>], new: [RouteStep<R>])

    /// `FlowStore` fired `onIntentRejected`.
    case intentRejected(FlowIntent<R>, FlowRejectionReason)

    /// The inner `NavigationStore` fired one of its observation callbacks.
    case navigation(NavigationEvent<R>)

    /// The inner `ModalStore` fired one of its observation callbacks.
    case modal(ModalEvent<R>)
}

extension FlowEvent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathChanged(let old, let new):
            return ".pathChanged(old: \(old), new: \(new))"
        case .intentRejected(let intent, let reason):
            return ".intentRejected(\(intent), reason: \(reason))"
        case .navigation(let event):
            return ".navigation(\(event))"
        case .modal(let event):
            return ".modal(\(event))"
        }
    }
}
