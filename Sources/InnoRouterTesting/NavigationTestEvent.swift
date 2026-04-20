// MARK: - NavigationTestEvent.swift
// InnoRouterTesting - observable event enum for NavigationTestStore
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore
import InnoRouterSwiftUI

/// A single event produced by a `NavigationTestStore`.
///
/// Each case mirrors one of the public `NavigationStoreConfiguration`
/// observation hooks. Test stores enqueue these events in the order emitted
/// by the underlying store, and tests dequeue them via `receive(...)` calls.
public enum NavigationTestEvent<R: Route>: Sendable, Equatable {
    /// The underlying `NavigationStore` fired `onChange` (single command or
    /// external path binding update).
    case changed(from: RouteStack<R>, to: RouteStack<R>)

    /// The underlying `NavigationStore` fired `onBatchExecuted`.
    case batchExecuted(NavigationBatchResult<R>)

    /// The underlying `NavigationStore` fired `onTransactionExecuted`.
    case transactionExecuted(NavigationTransactionResult<R>)

    /// The underlying `NavigationStore` fired `onMiddlewareMutation`.
    case middlewareMutation(MiddlewareMutationEvent<R>)

    /// The underlying `NavigationStore` fired `onPathMismatch`.
    case pathMismatch(NavigationPathMismatchEvent<R>)
}

extension NavigationTestEvent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .changed(let from, let to):
            return ".changed(from: \(from.path), to: \(to.path))"
        case .batchExecuted(let result):
            return ".batchExecuted(executed: \(result.executedCommands.count), isSuccess: \(result.isSuccess))"
        case .transactionExecuted(let result):
            return ".transactionExecuted(isCommitted: \(result.isCommitted))"
        case .middlewareMutation(let event):
            return ".middlewareMutation(action: \(event.action.rawValue))"
        case .pathMismatch(let event):
            return ".pathMismatch(policy: \(event.policy.rawValue))"
        }
    }
}
