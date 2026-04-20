// MARK: - ModalTestEvent.swift
// InnoRouterTesting - observable event enum for ModalTestStore
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore
import InnoRouterSwiftUI

/// A single event produced by a `ModalTestStore`.
///
/// Each case mirrors one of the public `ModalStoreConfiguration` observation
/// hooks. Test stores enqueue these events in the order emitted by the
/// underlying store.
public enum ModalTestEvent<M: Route>: Sendable, Equatable {
    /// The underlying `ModalStore` fired `onPresented`.
    case presented(ModalPresentation<M>)

    /// The underlying `ModalStore` fired `onDismissed`.
    case dismissed(ModalPresentation<M>, reason: ModalDismissalReason)

    /// The underlying `ModalStore` fired `onQueueChanged`.
    case queueChanged(old: [ModalPresentation<M>], new: [ModalPresentation<M>])

    /// The underlying `ModalStore` fired `onCommandIntercepted` — one event
    /// per `execute(_:)` call, including cancelled and no-op outcomes.
    case commandIntercepted(command: ModalCommand<M>, result: ModalExecutionResult<M>)

    /// The underlying `ModalStore` fired `onMiddlewareMutation`.
    case middlewareMutation(ModalMiddlewareMutationEvent<M>)
}

extension ModalTestEvent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .presented(let presentation):
            return ".presented(\(presentation.route), style: \(presentation.style))"
        case .dismissed(let presentation, let reason):
            return ".dismissed(\(presentation.route), reason: \(reason))"
        case .queueChanged(let old, let new):
            return ".queueChanged(old.count: \(old.count), new.count: \(new.count))"
        case .commandIntercepted(let command, let result):
            return ".commandIntercepted(\(command), result: \(result))"
        case .middlewareMutation(let event):
            return ".middlewareMutation(action: \(event.action.rawValue))"
        }
    }
}
