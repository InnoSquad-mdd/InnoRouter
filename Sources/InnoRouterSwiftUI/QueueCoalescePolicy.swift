// MARK: - QueueCoalescePolicy.swift
// InnoRouterSwiftUI - policy applied to ModalStore.queuedPresentations
// when a NavigationStore middleware cancels a flow-level command.
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore

/// Policy applied to the modal queue when a `NavigationStore`
/// middleware cancels a flow-level command (`.push` / `.reset` /
/// `.replaceStack` / `.backOrPush…`).
///
/// Choose the behaviour that matches the analytics / UX contract of
/// the surrounding feature:
///
/// - ``preserve``: keep `ModalStore.queuedPresentations` exactly as
///   they were before the cancelled command. This is the default and
///   matches the initial 4.0 OSS observable behaviour — appropriate
///   when a queued sheet should outlive a cancelled navigation prefix.
/// - ``dropQueued``: dismiss every entry from the queue and the active
///   modal (effectively `modalStore.dismissAll`) so a cancelled
///   navigation prefix does not leave a stale modal carry-over.
///   Opt-in: useful for `replaceStack` flows where the cancelled
///   reset should drop modal state alongside the navigation prefix.
/// - ``custom(_:)``: hand control to a `@MainActor` closure that
///   inspects the cancelled intent + rejection reason and decides
///   what to do with the queue.
@MainActor
public enum QueueCoalescePolicy<R: Route>: Sendable {
    /// Keep the modal queue intact when a navigation middleware
    /// cancels a flow-level command. The default 4.0 behaviour.
    case preserve
    /// Dismiss the active modal and drop every queued presentation
    /// when a navigation middleware cancels a flow-level command.
    case dropQueued
    /// Hand the cancelled intent and rejection reason to a closure
    /// that decides which `Action` to take. The closure runs on the
    /// main actor and may inspect the intent + queue state before
    /// returning.
    case custom(@MainActor @Sendable (FlowIntent<R>, FlowRejectionReason) -> Action)

    /// Action requested from a ``custom(_:)`` closure.
    public enum Action: Sendable, Equatable {
        /// Keep the modal queue intact.
        case preserve
        /// Dismiss the active modal and drop every queued presentation.
        case dropQueued
    }
}
