// MARK: - NavigationExecutionResultProtocolTests.swift
// InnoRouterTests - shared protocol contract for batch + transaction
// result types.
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing

import InnoRouterCore

private enum SharedRoute: Route {
    case home
    case detail(Int)
}

@Suite("NavigationExecutionResult shared shape")
struct NavigationExecutionResultProtocolTests {

    // MARK: - Generic helper

    /// A trivial helper that only reads the protocol's surface —
    /// proves both concrete types are usable through it.
    private func aggregateState<R>(
        from result: some NavigationExecutionResult<R>
    ) -> (before: RouteStack<R>, after: RouteStack<R>, isSuccess: Bool) {
        (result.stateBefore, result.stateAfter, result.isSuccess)
    }

    // MARK: - NavigationBatchResult conforms

    @Test("NavigationBatchResult satisfies NavigationExecutionResult and isSuccess matches results.allSatisfy")
    func batchResult_conforms() {
        let stateBefore = RouteStack<SharedRoute>()
        let stateAfter = RouteStack<SharedRoute>(path: [.home])

        let batch = NavigationBatchResult<SharedRoute>(
            requestedCommands: [.push(.home)],
            executedCommands: [.push(.home)],
            results: [.success],
            stateBefore: stateBefore,
            stateAfter: stateAfter,
            hasStoppedOnFailure: false
        )

        let aggregate = aggregateState(from: batch)
        #expect(aggregate.isSuccess)
        #expect(aggregate.before == stateBefore)
        #expect(aggregate.after == stateAfter)
    }

    // MARK: - NavigationTransactionResult conforms

    @Test("NavigationTransactionResult.isSuccess mirrors isCommitted on commit")
    func transactionResult_conforms_committed() {
        let stateBefore = RouteStack<SharedRoute>()
        let stateAfter = RouteStack<SharedRoute>(path: [.detail(1)])

        let transaction = NavigationTransactionResult<SharedRoute>(
            requestedCommands: [.push(.detail(1))],
            executedCommands: [.push(.detail(1))],
            results: [.success],
            stateBefore: stateBefore,
            stateAfter: stateAfter,
            failureIndex: nil,
            isCommitted: true
        )

        let aggregate = aggregateState(from: transaction)
        #expect(aggregate.isSuccess)
        #expect(transaction.isSuccess == transaction.isCommitted)
    }

    @Test("NavigationTransactionResult.isSuccess is false on rollback")
    func transactionResult_conforms_rolledBack() {
        let stateBefore = RouteStack<SharedRoute>()

        let transaction = NavigationTransactionResult<SharedRoute>(
            requestedCommands: [.push(.detail(1))],
            executedCommands: [],
            results: [],
            stateBefore: stateBefore,
            stateAfter: stateBefore,
            failureIndex: 0,
            isCommitted: false
        )

        #expect(!transaction.isSuccess)
        #expect(transaction.isSuccess == transaction.isCommitted)
    }
}
