// MARK: - NavigationEvent.swift
// InnoRouterSwiftUI - unified observable event for NavigationStore
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore

/// A single event produced by a `NavigationStore` observation surface.
///
/// Each case mirrors one of the public `NavigationStoreConfiguration`
/// observation hooks. `NavigationStore.events` exposes these as a single
/// `AsyncStream<NavigationEvent<R>>` so analytics, logging, and
/// debugging pipelines can subscribe once instead of wiring the five
/// individual `onChange` / `onBatchExecuted` / `onTransactionExecuted`
/// / `onMiddlewareMutation` / `onPathMismatch` callbacks.
///
/// Test harnesses (`InnoRouterTesting`) reuse this type directly — the
/// legacy `NavigationTestEvent<R>` is preserved as a typealias for
/// source compatibility.
public enum NavigationEvent<R: Route>: Sendable, Equatable {
    /// `NavigationStore` fired `onChange` (single command or external
    /// path binding update).
    case changed(from: RouteStack<R>, to: RouteStack<R>)

    /// `NavigationStore` fired `onBatchExecuted`.
    case batchExecuted(NavigationBatchResult<R>)

    /// `NavigationStore` fired `onTransactionExecuted`.
    case transactionExecuted(NavigationTransactionResult<R>)

    /// `NavigationStore` fired `onMiddlewareMutation`.
    case middlewareMutation(MiddlewareMutationEvent<R>)

    /// `NavigationStore` fired `onPathMismatch`.
    case pathMismatch(NavigationPathMismatchEvent<R>)
}

extension NavigationEvent: CustomStringConvertible {
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
