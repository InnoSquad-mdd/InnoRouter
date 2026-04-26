// MARK: - NavigationEffectHandler.swift
// InnoRouterNavigationEffects - Navigation Effect Handler
// Copyright © 2025 Inno Squad. All rights reserved.

import Foundation
@_exported import InnoRouterCore

/// App-boundary helper that executes navigation intents emitted from
/// non-SwiftUI features (InnoFlow effects, coordinator-owned async
/// pipelines) against a navigator while keeping the call sites on the
/// main actor.
@MainActor
public final class NavigationEffectHandler<R: Route> {
    private let executeCommand: @MainActor (NavigationCommand<R>) -> NavigationResult<R>
    private let executeBatchCommands: @MainActor ([NavigationCommand<R>], Bool) -> NavigationBatchResult<R>
    private let executeTransactionCommands: @MainActor ([NavigationCommand<R>]) -> NavigationTransactionResult<R>
    private let readState: @MainActor () -> RouteStack<R>

    /// Result of the most recent single-command execution, or `nil`
    /// when the last call was a batch / transaction.
    public private(set) var lastResult: NavigationResult<R>?

    /// Result of the most recent batch execution, or `nil` when the
    /// last call was a single command or transaction.
    public private(set) var lastBatchResult: NavigationBatchResult<R>?

    public init<N: Navigator & NavigationBatchExecutor & NavigationTransactionExecutor>(
        navigator: N
    ) where N.RouteType == R {
        self.executeCommand = { command in
            navigator.execute(command)
        }
        self.executeBatchCommands = { commands, stopOnFailure in
            navigator.executeBatch(commands, stopOnFailure: stopOnFailure)
        }
        self.executeTransactionCommands = { commands in
            navigator.executeTransaction(commands)
        }
        self.readState = {
            navigator.state
        }
    }

    @discardableResult
    public func execute(_ command: NavigationCommand<R>) -> NavigationResult<R> {
        let result = executeCommand(command)
        lastResult = result
        lastBatchResult = nil
        return result
    }

    @discardableResult
    public func execute(_ commands: [NavigationCommand<R>]) -> NavigationBatchResult<R> {
        execute(commands, stopOnFailure: false)
    }

    @discardableResult
    public func execute(
        _ commands: [NavigationCommand<R>],
        stopOnFailure: Bool
    ) -> NavigationBatchResult<R> {
        let batchResult = executeBatchCommands(commands, stopOnFailure)
        lastBatchResult = batchResult
        lastResult = batchResult.results.last
        return batchResult
    }

    @discardableResult
    public func executeTransaction(
        _ commands: [NavigationCommand<R>]
    ) -> NavigationTransactionResult<R> {
        let transactionResult = executeTransactionCommands(commands)
        lastResult = transactionResult.results.last
        lastBatchResult = nil
        return transactionResult
    }

    public func push(_ route: R) {
        _ = execute(.push(route))
    }

    public func pop() {
        _ = execute(.pop)
    }

    public func popToRoot() {
        _ = execute(.popToRoot)
    }

    public func replace(with routes: [R]) {
        _ = execute(.replace(routes))
    }

    @discardableResult
    public func executeIf(
        _ shouldExecute: @escaping @Sendable () -> Bool,
        command: NavigationCommand<R>
    ) -> NavigationResult<R> {
        guard shouldExecute() else {
            let result: NavigationResult<R> = .cancelled(.conditionFailed)
            lastResult = result
            lastBatchResult = nil
            return result
        }
        return execute(command)
    }

    /// Returns `true` when every command in the batch would succeed against the current
    /// ``RouteStack`` when executed sequentially. Used by async guards to pre-flight a
    /// plan after `await` without committing any change.
    public func canExecuteSequentially(_ commands: [NavigationCommand<R>]) -> Bool {
        var preview = readState()
        let engine = NavigationEngine<R>()
        for command in commands {
            if !engine.apply(command, to: &preview).isSuccess {
                return false
            }
        }
        return true
    }

    @discardableResult
    public func executeGuarded(
        _ command: NavigationCommand<R>,
        prepare: @escaping @MainActor @Sendable (NavigationCommand<R>) async -> NavigationInterception<R>
    ) async -> NavigationResult<R> {
        switch await prepare(command) {
        case .proceed(let updatedCommand):
            guard updatedCommand.canExecute(on: readState()) else {
                let result: NavigationResult<R> = .cancelled(.staleAfterPrepare(command: updatedCommand))
                lastResult = result
                lastBatchResult = nil
                return result
            }
            return execute(updatedCommand)
        case .cancel(let reason):
            let result: NavigationResult<R> = .cancelled(reason)
            lastResult = result
            lastBatchResult = nil
            return result
        }
    }
}

public protocol NavigationEffect {
    associatedtype RouteType: Route
    var navigationCommand: NavigationCommand<RouteType>? { get }
    static func navigation(_ command: NavigationCommand<RouteType>) -> Self
}

public extension NavigationEffectHandler {
    @discardableResult
    func handle<E: NavigationEffect>(_ effect: E) -> NavigationResult<R>? where E.RouteType == R {
        guard let command = effect.navigationCommand else { return nil }
        return execute(command)
    }
}
