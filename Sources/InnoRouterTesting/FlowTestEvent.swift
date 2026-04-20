// MARK: - FlowTestEvent.swift
// InnoRouterTesting - observable event enum for FlowTestStore
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore
import InnoRouterSwiftUI

/// A single event produced by a `FlowTestStore`.
///
/// `.pathChanged` and `.intentRejected` mirror the FlowStore-level callbacks.
/// `.navigation(...)` and `.modal(...)` wrap events from the inner
/// `NavigationStore` / `ModalStore`, so a single `FlowTestStore` can assert
/// "this intent triggered this specific internal command sequence" end-to-end.
public enum FlowTestEvent<R: Route>: Sendable, Equatable {
    /// The underlying `FlowStore` fired `onPathChanged`.
    case pathChanged(old: [RouteStep<R>], new: [RouteStep<R>])

    /// The underlying `FlowStore` fired `onIntentRejected`.
    case intentRejected(FlowIntent<R>, FlowRejectionReason)

    /// The inner `NavigationStore` fired one of its observation callbacks.
    case navigation(NavigationTestEvent<R>)

    /// The inner `ModalStore` fired one of its observation callbacks.
    case modal(ModalTestEvent<R>)
}

extension FlowTestEvent: CustomStringConvertible {
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
