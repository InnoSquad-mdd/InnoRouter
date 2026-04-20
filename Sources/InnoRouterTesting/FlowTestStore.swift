// MARK: - FlowTestStore.swift
// InnoRouterTesting - host-less flow test harness
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore
import InnoRouterSwiftUI

/// A host-less, Swift-Testing native assertion harness for `FlowStore`.
///
/// `FlowTestStore` wraps a private `FlowStore<R>` and subscribes to:
///
/// - the FlowStore-level `onPathChanged` and `onIntentRejected` callbacks,
/// - every `NavigationStoreConfiguration` observation hook on the inner
///   navigation store,
/// - every `ModalStoreConfiguration` observation hook on the inner modal
///   store.
///
/// All events land in a single FIFO queue and preserve their real emission
/// order. This lets a test assert, for example, that a single
/// `.send(.presentSheet(...))` actually reached the modal store's middleware
/// pipeline and then updated the path, or — with a blocking middleware —
/// that the navigation store was never touched.
///
/// ```swift
/// let store = FlowTestStore<AppRoute>()
/// store.send(.push(.home))
/// store.receive(.navigation(.changed(from: .init(), to: ...)))
/// store.receive(.pathChanged(old: [], new: [.push(.home)]))
/// ```
@MainActor
public final class FlowTestStore<R: Route> {

    // MARK: - Stored

    private let underlying: FlowStore<R>
    private let queue: TestEventQueue<FlowTestEvent<R>>
    private var exhaustivity: TestExhaustivity
    private var hasFinished: Bool

    // MARK: - Init

    public init(
        initial: [RouteStep<R>] = [],
        configuration: FlowStoreConfiguration<R> = .init(),
        exhaustivity: TestExhaustivity = .strict
    ) {
        let queue = TestEventQueue<FlowTestEvent<R>>()
        self.queue = queue
        self.exhaustivity = exhaustivity
        self.hasFinished = false
        self.underlying = FlowStore(
            initial: initial,
            configuration: Self.wrapConfiguration(configuration, queue: queue)
        )
    }

    isolated deinit {
        if !hasFinished {
            performExhaustivityCheck(
                fileID: #fileID,
                filePath: #filePath,
                line: #line,
                column: #column
            )
        }
    }

    // MARK: - Accessors

    public var store: FlowStore<R> {
        underlying
    }

    public var path: [RouteStep<R>] {
        underlying.path
    }

    public var unassertedEvents: [FlowTestEvent<R>] {
        queue.remaining
    }

    // MARK: - Execution

    public func send(_ intent: FlowIntent<R>) {
        underlying.send(intent)
    }

    public func apply(_ plan: FlowPlan<R>) {
        underlying.apply(plan)
    }

    // MARK: - Assertion

    public func receive(
        _ expected: FlowTestEvent<R>,
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        guard let actual = queue.dequeue() else {
            recordTestStoreIssue(
                "FlowTestStore.receive(\(expected)) — queue is empty.",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
            return
        }
        if actual != expected {
            recordTestStoreIssue(
                """
                FlowTestStore.receive mismatch.
                Expected: \(expected)
                Actual:   \(actual)
                """,
                fileID: fileID, filePath: filePath, line: line, column: column
            )
        }
    }

    public func receivePathChanged(
        _ predicate: ([RouteStep<R>], [RouteStep<R>]) -> Bool = { _, _ in true },
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        guard let actual = queue.dequeue() else {
            recordTestStoreIssue(
                "FlowTestStore.receivePathChanged — queue is empty.",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
            return
        }
        guard case .pathChanged(let old, let new) = actual else {
            recordTestStoreIssue(
                "FlowTestStore.receivePathChanged — expected .pathChanged, got \(actual).",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
            return
        }
        if !predicate(old, new) {
            recordTestStoreIssue(
                "FlowTestStore.receivePathChanged predicate failed.",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
        }
    }

    public func receiveIntentRejected(
        intent: FlowIntent<R>,
        reason: FlowRejectionReason,
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        guard let actual = queue.dequeue() else {
            recordTestStoreIssue(
                "FlowTestStore.receiveIntentRejected — queue is empty.",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
            return
        }
        guard case .intentRejected(let observedIntent, let observedReason) = actual else {
            recordTestStoreIssue(
                "FlowTestStore.receiveIntentRejected — expected .intentRejected, got \(actual).",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
            return
        }
        if observedIntent != intent || observedReason != reason {
            recordTestStoreIssue(
                """
                FlowTestStore.receiveIntentRejected mismatch.
                Expected: (\(intent), \(reason))
                Actual:   (\(observedIntent), \(observedReason))
                """,
                fileID: fileID, filePath: filePath, line: line, column: column
            )
        }
    }

    public func receiveNavigation(
        _ predicate: (NavigationTestEvent<R>) -> Bool = { _ in true },
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        guard let actual = queue.dequeue() else {
            recordTestStoreIssue(
                "FlowTestStore.receiveNavigation — queue is empty.",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
            return
        }
        guard case .navigation(let event) = actual else {
            recordTestStoreIssue(
                "FlowTestStore.receiveNavigation — expected .navigation, got \(actual).",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
            return
        }
        if !predicate(event) {
            recordTestStoreIssue(
                "FlowTestStore.receiveNavigation predicate failed for \(event).",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
        }
    }

    public func receiveModal(
        _ predicate: (ModalTestEvent<R>) -> Bool = { _ in true },
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        guard let actual = queue.dequeue() else {
            recordTestStoreIssue(
                "FlowTestStore.receiveModal — queue is empty.",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
            return
        }
        guard case .modal(let event) = actual else {
            recordTestStoreIssue(
                "FlowTestStore.receiveModal — expected .modal, got \(actual).",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
            return
        }
        if !predicate(event) {
            recordTestStoreIssue(
                "FlowTestStore.receiveModal predicate failed for \(event).",
                fileID: fileID, filePath: filePath, line: line, column: column
            )
        }
    }

    // MARK: - Completion

    public func expectNoMoreEvents(
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        guard !queue.isEmpty else { return }
        recordTestStoreIssue(
            """
            FlowTestStore has \(queue.count) unasserted event(s):
            \(queue.remaining.map { "  - \($0)" }.joined(separator: "\n"))
            """,
            fileID: fileID, filePath: filePath, line: line, column: column
        )
    }

    public func finish(
        fileID: String = #fileID,
        filePath: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        guard !hasFinished else { return }
        performExhaustivityCheck(fileID: fileID, filePath: filePath, line: line, column: column)
    }

    public func skipReceivedEvents() {
        queue.drain()
    }

    // MARK: - Internals

    private func performExhaustivityCheck(
        fileID: String,
        filePath: String,
        line: Int,
        column: Int
    ) {
        hasFinished = true
        guard exhaustivity == .strict else { return }
        guard !queue.isEmpty else { return }
        recordTestStoreIssue(
            """
            FlowTestStore deallocated with \(queue.count) unasserted event(s):
            \(queue.remaining.map { "  - \($0)" }.joined(separator: "\n"))
            """,
            fileID: fileID, filePath: filePath, line: line, column: column
        )
    }

    private static func wrapConfiguration(
        _ original: FlowStoreConfiguration<R>,
        queue: TestEventQueue<FlowTestEvent<R>>
    ) -> FlowStoreConfiguration<R> {
        let wrappedNavigation = Self.wrapNavigationConfiguration(
            original.navigation,
            queue: queue
        )
        let wrappedModal = Self.wrapModalConfiguration(
            original.modal,
            queue: queue
        )
        return FlowStoreConfiguration(
            navigation: wrappedNavigation,
            modal: wrappedModal,
            onPathChanged: { @MainActor [queue] old, new in
                original.onPathChanged?(old, new)
                queue.enqueue(.pathChanged(old: old, new: new))
            },
            onIntentRejected: { @MainActor [queue] intent, reason in
                original.onIntentRejected?(intent, reason)
                queue.enqueue(.intentRejected(intent, reason))
            }
        )
    }

    private static func wrapNavigationConfiguration(
        _ original: NavigationStoreConfiguration<R>,
        queue: TestEventQueue<FlowTestEvent<R>>
    ) -> NavigationStoreConfiguration<R> {
        NavigationStoreConfiguration(
            engine: original.engine,
            middlewares: original.middlewares,
            routeStackValidator: original.routeStackValidator,
            pathMismatchPolicy: original.pathMismatchPolicy,
            logger: original.logger,
            onChange: { @MainActor [queue] old, new in
                original.onChange?(old, new)
                queue.enqueue(.navigation(.changed(from: old, to: new)))
            },
            onBatchExecuted: { @MainActor [queue] result in
                original.onBatchExecuted?(result)
                queue.enqueue(.navigation(.batchExecuted(result)))
            },
            onTransactionExecuted: { @MainActor [queue] result in
                original.onTransactionExecuted?(result)
                queue.enqueue(.navigation(.transactionExecuted(result)))
            },
            onMiddlewareMutation: { @MainActor [queue] event in
                original.onMiddlewareMutation?(event)
                queue.enqueue(.navigation(.middlewareMutation(event)))
            },
            onPathMismatch: { @MainActor [queue] event in
                original.onPathMismatch?(event)
                queue.enqueue(.navigation(.pathMismatch(event)))
            }
        )
    }

    private static func wrapModalConfiguration(
        _ original: ModalStoreConfiguration<R>,
        queue: TestEventQueue<FlowTestEvent<R>>
    ) -> ModalStoreConfiguration<R> {
        ModalStoreConfiguration(
            logger: original.logger,
            middlewares: original.middlewares,
            onPresented: { @MainActor [queue] presentation in
                original.onPresented?(presentation)
                queue.enqueue(.modal(.presented(presentation)))
            },
            onDismissed: { @MainActor [queue] presentation, reason in
                original.onDismissed?(presentation, reason)
                queue.enqueue(.modal(.dismissed(presentation, reason: reason)))
            },
            onQueueChanged: { @MainActor [queue] old, new in
                original.onQueueChanged?(old, new)
                queue.enqueue(.modal(.queueChanged(old: old, new: new)))
            },
            onMiddlewareMutation: { @MainActor [queue] event in
                original.onMiddlewareMutation?(event)
                queue.enqueue(.modal(.middlewareMutation(event)))
            },
            onCommandIntercepted: { @MainActor [queue] command, result in
                original.onCommandIntercepted?(command, result)
                queue.enqueue(.modal(.commandIntercepted(command: command, result: result)))
            }
        )
    }
}
