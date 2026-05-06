// MARK: - ModalQueueCancellationPolicy.swift
// InnoRouterSwiftUI - policy applied to ModalStore's queued
// presentations when a ModalMiddleware cancels a command.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// `ModalStore` keeps `queuedPresentations` intact by default when
// a middleware cancels any command. That matches the "cancellation
// did not happen" reading: the cancelled command did not run, so
// the queue stays where it was.
//
// Some apps want a stronger statement — for example, "if a
// `.dismissAll` is cancelled by a guard middleware, also clear the
// queued presentations so the screen does not surface them next."
// `ModalQueueCancellationPolicy` is the configuration knob for
// that decision. The matching FlowStore-level concept is
// ``QueueCoalescePolicy`` — that one operates on `FlowIntent` /
// `FlowRejectionReason` for FlowStore-driven cancellations and is
// orthogonal to this policy.

import InnoRouterCore

/// Policy applied to ``ModalStore/queuedPresentations`` when a
/// ``ModalMiddleware`` cancels a ``ModalCommand``.
///
/// Choose the behaviour that matches the surrounding feature's
/// analytics / UX contract:
///
/// - ``preserve``: keep the queue untouched. This is the default
///   and matches the historical 4.x behaviour — the cancelled
///   command did not run, so the queue stays where it was.
/// - ``dropQueued``: clear every queued presentation (the active
///   modal stays untouched). Useful for apps that interpret a
///   cancelled `.dismissAll` as also voiding the queued backlog.
/// - ``custom(_:)``: hand the cancelled command and reason to a
///   closure that returns an explicit ``Action``.
@MainActor
public enum ModalQueueCancellationPolicy<M: Route>: Sendable {
    /// Keep the queue untouched when middleware cancels a command
    /// (default).
    case preserve
    /// Clear every queued presentation when middleware cancels a
    /// command.
    case dropQueued
    /// Hand the cancelled command and reason to a closure that
    /// returns one of the explicit ``Action`` values.
    case custom(@MainActor @Sendable (ModalCommand<M>, ModalCancellationReason<M>) -> Action)

    /// Action requested from a ``custom(_:)`` closure.
    public enum Action: Sendable, Equatable {
        case preserve
        case dropQueued
    }

    /// Resolves the configured policy into an effective ``Action``
    /// for the supplied cancellation. Internal use.
    func resolve(
        command: ModalCommand<M>,
        reason: ModalCancellationReason<M>
    ) -> Action {
        switch self {
        case .preserve:
            return .preserve
        case .dropQueued:
            return .dropQueued
        case .custom(let decide):
            return decide(command, reason)
        }
    }
}
