import OSLog
@_spi(InternalTrace) import InnoRouterCore
import Observation
import SwiftUI

@Observable
@MainActor
public final class NavigationStore<R: Route>: Navigator, NavigationBatchExecutor, NavigationTransactionExecutor {
    public typealias RouteType = R

    public private(set) var state: RouteStack<R>

    private let engine: NavigationEngine<R>
    private let onChange: (@MainActor @Sendable (RouteStack<R>, RouteStack<R>) -> Void)?
    private let onBatchExecuted: (@MainActor @Sendable (NavigationBatchResult<R>) -> Void)?
    private let onTransactionExecuted: (@MainActor @Sendable (NavigationTransactionResult<R>) -> Void)?
    private let telemetrySink: NavigationStoreTelemetrySink<R>
    private let middlewareRegistry: NavigationMiddlewareRegistry<R>
    private let pathReconciler: NavigationPathReconciler<R>
    private let pathMismatchPolicy: NavigationPathMismatchPolicy<R>
    private let pathMismatchAssertionHandler: @MainActor @Sendable ([R], [R]) -> Void
    private let broadcaster: EventBroadcaster<NavigationEvent<R>>
    private let traceLogger: Logger?
    private var traceRecorder: InternalExecutionTraceRecorder?
    private var cachedEffectiveTraceRecorder: InternalExecutionTraceRecorder?
    /// Cached intent dispatcher that lives for the lifetime of this store.
    /// Built on first access by ``intentDispatcher`` so SwiftUI hosts do
    /// not allocate a fresh closure on every render.
    @ObservationIgnored
    private var cachedIntentDispatcher: AnyNavigationIntentDispatcher<R>?

    /// A type-erased dispatcher that forwards `NavigationIntent` values to
    /// this store's ``send(_:)`` entry point.
    ///
    /// Hosts publish this through the SwiftUI environment so descendants can
    /// use ``EnvironmentNavigationIntent`` to dispatch view-layer intents
    /// without holding a direct store reference. The dispatcher is created
    /// on first access and reused for the lifetime of the store, so a
    /// SwiftUI host does not allocate a fresh closure on every render.
    public var intentDispatcher: AnyNavigationIntentDispatcher<R> {
        if let cachedIntentDispatcher {
            return cachedIntentDispatcher
        }
        let dispatcher = AnyNavigationIntentDispatcher<R> { [weak self] intent in
            self?.send(intent)
        }
        cachedIntentDispatcher = dispatcher
        return dispatcher
    }

    public var middlewareHandles: [NavigationMiddlewareHandle] {
        middlewareRegistry.handles
    }

    public var middlewareMetadata: [NavigationMiddlewareMetadata] {
        middlewareRegistry.metadata
    }

    /// A multicast `AsyncStream` that emits every observation event the
    /// store produces — stack changes, batch / transaction completions,
    /// middleware mutations, and path-mismatch resolutions — in the
    /// same order as the individual `onChange` / `onBatchExecuted` /
    /// `onTransactionExecuted` / `onMiddlewareMutation` /
    /// `onPathMismatch` callbacks fire.
    ///
    /// Each call to `events` returns a fresh stream with its own
    /// continuation; multiple subscribers see every event
    /// independently. When a subscriber cancels its iterator (or the
    /// store deallocates) its continuation is cleaned up automatically.
    public var events: AsyncStream<NavigationEvent<R>> {
        broadcaster.stream()
    }

    public init(
        initial: RouteStack<R> = .init(),
        configuration: NavigationStoreConfiguration<R> = .init()
    ) {
        let broadcaster = EventBroadcaster<NavigationEvent<R>>(
            bufferingPolicy: configuration.eventBufferingPolicy
        )
        let publicRecorder = Self.makePublicTelemetryRecorder(
            onMiddlewareMutation: configuration.onMiddlewareMutation,
            onPathMismatch: configuration.onPathMismatch
        )
        let broadcastRecorder = Self.makeBroadcastRecorder(broadcaster: broadcaster)
        let telemetrySink = NavigationStoreTelemetrySink<R>(
            logger: configuration.logger,
            recorder: Self.combineRecorders(publicRecorder, broadcastRecorder)
        )
        let middlewareRegistry = NavigationMiddlewareRegistry(
            registrations: configuration.middlewares,
            telemetrySink: telemetrySink
        )
        self.state = initial
        self.engine = configuration.engine
        self.onChange = configuration.onChange
        self.onBatchExecuted = configuration.onBatchExecuted
        self.onTransactionExecuted = configuration.onTransactionExecuted
        self.pathMismatchPolicy = configuration.pathMismatchPolicy
        self.pathMismatchAssertionHandler = Self.defaultPathMismatchAssertionHandler
        self.telemetrySink = telemetrySink
        self.middlewareRegistry = middlewareRegistry
        self.pathReconciler = NavigationPathReconciler()
        self.broadcaster = broadcaster
        self.traceLogger = configuration.logger
        self.traceRecorder = nil
        self.cachedEffectiveTraceRecorder = nil
        updateEffectiveTraceRecorder()
    }

    public convenience init(
        initialPath: [R],
        configuration: NavigationStoreConfiguration<R> = .init()
    ) throws {
        let initial = try RouteStack(validating: initialPath, using: configuration.routeStackValidator)
        self.init(initial: initial, configuration: configuration)
    }

    init(
        initial: RouteStack<R> = .init(),
        configuration: NavigationStoreConfiguration<R> = .init(),
        nonPrefixAssertionHandler: @escaping @MainActor @Sendable ([R], [R]) -> Void,
        telemetryRecorder: NavigationStoreTelemetryRecorder<R>? = nil
    ) {
        let broadcaster = EventBroadcaster<NavigationEvent<R>>(
            bufferingPolicy: configuration.eventBufferingPolicy
        )
        let publicRecorder = Self.makePublicTelemetryRecorder(
            onMiddlewareMutation: configuration.onMiddlewareMutation,
            onPathMismatch: configuration.onPathMismatch
        )
        let broadcastRecorder = Self.makeBroadcastRecorder(broadcaster: broadcaster)
        let combinedRecorder = Self.combineRecorders(
            Self.combineRecorders(telemetryRecorder, publicRecorder),
            broadcastRecorder
        )
        let telemetrySink = NavigationStoreTelemetrySink(
            logger: configuration.logger,
            recorder: combinedRecorder
        )
        let middlewareRegistry = NavigationMiddlewareRegistry(
            registrations: configuration.middlewares,
            telemetrySink: telemetrySink
        )
        self.state = initial
        self.engine = configuration.engine
        self.onChange = configuration.onChange
        self.onBatchExecuted = configuration.onBatchExecuted
        self.onTransactionExecuted = configuration.onTransactionExecuted
        self.pathMismatchPolicy = configuration.pathMismatchPolicy
        self.pathMismatchAssertionHandler = nonPrefixAssertionHandler
        self.telemetrySink = telemetrySink
        self.middlewareRegistry = middlewareRegistry
        self.pathReconciler = NavigationPathReconciler()
        self.broadcaster = broadcaster
        self.traceLogger = configuration.logger
        self.traceRecorder = nil
        self.cachedEffectiveTraceRecorder = nil
        updateEffectiveTraceRecorder()
    }

    // Telemetry adapter helpers live in
    // `NavigationStore+TelemetryAdapters.swift` so this file stays
    // focused on the `Observable` storage and execution surface.

    func installTraceRecorder(_ recorder: InternalExecutionTraceRecorder?) {
        self.traceRecorder = recorder
        updateEffectiveTraceRecorder()
    }

    private func updateEffectiveTraceRecorder() {
        if traceRecorder == nil && traceLogger == nil {
            cachedEffectiveTraceRecorder = nil
            return
        }

        cachedEffectiveTraceRecorder = { [weak self] record in
            self?.traceRecorder?(record)
            self?.logTraceRecord(record)
        }
    }

    private var effectiveTraceRecorder: InternalExecutionTraceRecorder? {
        cachedEffectiveTraceRecorder
    }

    private func logTraceRecord(_ record: InternalExecutionTraceRecord) {
        guard let traceLogger else { return }

        switch record {
        case .start(let context, let operation, let metadata):
            let metadataSummary = metadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ",")
            traceLogger.debug(
                """
                navigation trace start \
                root=\(context.rootID, privacy: .public) \
                span=\(context.spanID, privacy: .public) \
                parent=\(context.parentSpanID ?? "nil", privacy: .public) \
                operation=\(operation, privacy: .public) \
                metadata=\(metadataSummary, privacy: .private)
                """
            )

        case .finish(let context, let operation, let outcome):
            traceLogger.debug(
                """
                navigation trace finish \
                root=\(context.rootID, privacy: .public) \
                span=\(context.spanID, privacy: .public) \
                parent=\(context.parentSpanID ?? "nil", privacy: .public) \
                operation=\(operation, privacy: .public) \
                outcome=\(outcome, privacy: .private)
                """
            )
        }
    }

    @discardableResult
    public func addMiddleware(
        _ middleware: AnyNavigationMiddleware<R>,
        debugName: String? = nil
    ) -> NavigationMiddlewareHandle {
        middlewareRegistry.add(middleware, debugName: debugName)
    }

    @discardableResult
    public func insertMiddleware(
        _ middleware: AnyNavigationMiddleware<R>,
        at index: Int,
        debugName: String? = nil
    ) -> NavigationMiddlewareHandle {
        middlewareRegistry.insert(middleware, at: index, debugName: debugName)
    }

    @discardableResult
    public func removeMiddleware(_ handle: NavigationMiddlewareHandle) -> AnyNavigationMiddleware<R>? {
        middlewareRegistry.remove(handle)
    }

    @discardableResult
    public func replaceMiddleware(
        _ handle: NavigationMiddlewareHandle,
        with middleware: AnyNavigationMiddleware<R>,
        debugName: String? = nil
    ) -> Bool {
        middlewareRegistry.replace(handle, with: middleware, debugName: debugName)
    }

    @discardableResult
    public func moveMiddleware(_ handle: NavigationMiddlewareHandle, to index: Int) -> Bool {
        middlewareRegistry.move(handle, to: index)
    }

    @discardableResult
    public func execute(_ command: NavigationCommand<R>) -> NavigationResult<R> {
        InternalExecutionTrace.withSpan(
            domain: .navigation,
            operation: "execute",
            recorder: effectiveTraceRecorder,
            metadata: ["command": String(describing: command)]
        ) {
            executeSingle(command, shouldNotifyOnChange: true).result
        } outcome: { result in
            String(describing: result)
        }
    }

    @discardableResult
    public func executeBatch(
        _ commands: [NavigationCommand<R>],
        stopOnFailure: Bool = false
    ) -> NavigationBatchResult<R> {
        InternalExecutionTrace.withSpan(
            domain: .navigation,
            operation: "executeBatch",
            recorder: effectiveTraceRecorder,
            metadata: [
                "count": String(commands.count),
                "stopOnFailure": String(stopOnFailure),
            ]
        ) {
            let stateBefore = state
            var executedCommands: [NavigationCommand<R>] = []
            executedCommands.reserveCapacity(commands.count)
            var results: [NavigationResult<R>] = []
            results.reserveCapacity(commands.count)
            var hasStoppedOnFailure = false

            for command in commands {
                let outcome = executeSingle(command, shouldNotifyOnChange: false)
                executedCommands.append(contentsOf: outcome.executedCommands)
                results.append(outcome.result)

                if stopOnFailure && !outcome.result.isSuccess {
                    hasStoppedOnFailure = true
                    break
                }
            }

            let stateAfter = state
            if stateAfter != stateBefore {
                onChange?(stateBefore, stateAfter)
                broadcaster.broadcast(.changed(from: stateBefore, to: stateAfter))
            }

            let batch = NavigationBatchResult(
                requestedCommands: commands,
                executedCommands: executedCommands,
                results: results,
                stateBefore: stateBefore,
                stateAfter: stateAfter,
                hasStoppedOnFailure: hasStoppedOnFailure
            )
            onBatchExecuted?(batch)
            broadcaster.broadcast(.batchExecuted(batch))
            return batch
        } outcome: { batch in
            batch.isSuccess ? "success" : "failure"
        }
    }

    @discardableResult
    public func executeTransaction(
        _ commands: [NavigationCommand<R>]
    ) -> NavigationTransactionResult<R> {
        InternalExecutionTrace.withSpan(
            domain: .navigation,
            operation: "executeTransaction",
            recorder: effectiveTraceRecorder,
            metadata: ["count": String(commands.count)]
        ) {
            let stateBefore = state
            var shadowState = state
            var journals: [NavigationExecutionJournal<R>] = []
            journals.reserveCapacity(commands.count)
            var failureIndex: Int?

            for (index, command) in commands.enumerated() {
                let journal = NavigationExecutionJournal.planTransaction(
                    command,
                    state: &shadowState,
                    middlewareRegistry: middlewareRegistry,
                    engine: engine
                )
                journals.append(journal)

                if journal.result.isSuccess {
                    continue
                } else {
                    failureIndex = index
                    break
                }
            }

            let isCommitted = failureIndex == nil
            let executedCommands = journals.flatMap(\.executedCommands)
            let results: [NavigationResult<R>]
            if isCommitted {
                state = shadowState
                results = journals.map { $0.finalizeCommittedTransaction(using: middlewareRegistry) }
                if state != stateBefore {
                    onChange?(stateBefore, state)
                    broadcaster.broadcast(.changed(from: stateBefore, to: state))
                }
            } else {
                journals
                    .map { $0.forDiscardedTransaction() }
                    .forEach { $0.discardExecuted(using: middlewareRegistry) }
                results = journals.map(\.result)
            }

            let transaction = NavigationTransactionResult(
                requestedCommands: commands,
                executedCommands: executedCommands,
                results: results,
                stateBefore: stateBefore,
                stateAfter: isCommitted ? state : stateBefore,
                failureIndex: failureIndex,
                isCommitted: isCommitted
            )
            onTransactionExecuted?(transaction)
            broadcaster.broadcast(.transactionExecuted(transaction))
            return transaction
        } outcome: { transaction in
            transaction.isCommitted ? "committed" : "rolledBack"
        }
    }

    public func send(_ intent: NavigationIntent<R>) {
        switch intent {
        case .go(let route):
            _ = execute(.push(route))
        case .goMany(let routes):
            switch routes.count {
            case 0:
                return
            case 1:
                _ = execute(.push(routes[0]))
            default:
                _ = executeBatch(routes.map(NavigationCommand.push), stopOnFailure: false)
            }
        case .back:
            _ = execute(.pop)
        case .backBy(let count):
            if count > 0, count == state.path.count {
                _ = execute(.popToRoot)
            } else {
                _ = execute(.popCount(count))
            }
        case .backTo(let route):
            _ = execute(.popTo(route))
        case .backToRoot:
            _ = execute(.popToRoot)
        case .resetTo(let routes):
            _ = execute(.replace(routes))
        case .replaceStack(let routes):
            _ = execute(.replace(routes))
        case .backOrPush(let route):
            if state.path.contains(route) {
                _ = execute(.popTo(route))
            } else {
                _ = execute(.push(route))
            }
        case .pushUniqueRoot(let route):
            if !state.path.contains(route) {
                _ = execute(.push(route))
            }
        }
    }

    public var pathBinding: Binding<[R]> {
        Binding(
            get: { self.state.path },
            set: { newPath in
                self.reconcileNavigationPath(with: newPath)
            }
        )
    }

    /// A binding that reflects the top-of-stack route when it matches the given case.
    ///
    /// Writing a non-nil value pushes the embedded route through the regular command
    /// pipeline when the active destination is a different case. When the top
    /// route already matches the case, the binding replaces that top route in
    /// place instead of pushing a duplicate screen. Writing `nil` pops the top
    /// route only when it currently matches the case — other stack states are
    /// left untouched.
    public func binding<Value>(case casePath: CasePath<R, Value>) -> Binding<Value?> {
        Binding(
            get: { [weak self] in
                self?.state.path.last.flatMap(casePath.extract)
            },
            set: { [weak self] newValue in
                guard let self else { return }
                if let value = newValue {
                    let route = casePath.embed(value)
                    if let currentRoute = self.state.path.last,
                       casePath.extract(currentRoute) != nil {
                        guard currentRoute != route else { return }
                        let replacementPath = Array(self.state.path.dropLast()) + [route]
                        _ = self.execute(.replace(replacementPath))
                    } else {
                        _ = self.execute(.push(route))
                    }
                } else if self.state.path.last.flatMap(casePath.extract) != nil {
                    _ = self.execute(.pop)
                }
            }
        )
    }

    func previewFlowCommand(_ command: NavigationCommand<R>) -> NavigationExecutionJournal<R> {
        previewFlowCommand(command, from: state)
    }

    func previewFlowCommand(
        _ command: NavigationCommand<R>,
        from stateBefore: RouteStack<R>
    ) -> NavigationExecutionJournal<R> {
        NavigationExecutionJournal.preview(
            command,
            from: stateBefore,
            middlewareRegistry: middlewareRegistry,
            engine: engine
        )
    }

    @discardableResult
    func commitFlowPreview(_ preview: NavigationExecutionJournal<R>) -> NavigationResult<R> {
        InternalExecutionTrace.withSpan(
            domain: .navigation,
            operation: "commitFlowPreview",
            recorder: effectiveTraceRecorder,
            metadata: ["command": String(describing: preview.requestedCommand)]
        ) {
            let committedStateBefore = state
            state = preview.stateAfter

            let finalResult = preview.finalizePreview(using: middlewareRegistry)

            if state != committedStateBefore {
                onChange?(committedStateBefore, state)
                broadcaster.broadcast(.changed(from: committedStateBefore, to: state))
            }

            return finalResult
        } outcome: { result in
            String(describing: result)
        }
    }

    private func reconcileNavigationPath(with newPath: [R]) {
        pathReconciler.reconcile(
            from: state.path,
            to: newPath,
            resolveMismatch: { [weak self] oldPath, newPath in
                guard let self else { return .single(.replace(newPath)) }
                return self.resolvePathMismatch(from: oldPath, to: newPath)
            },
            execute: { [weak self] command in
                guard let self else { return }
                _ = self.execute(command)
            },
            executeBatch: { [weak self] commands in
                guard let self else { return }
                _ = self.executeBatch(commands, stopOnFailure: false)
            }
        )
    }

    private func executeSingle(
        _ command: NavigationCommand<R>,
        shouldNotifyOnChange: Bool
    ) -> ExecutionOutcome {
        executeSingle(command, state: &state, shouldNotifyOnChange: shouldNotifyOnChange)
    }

    private func executeSingle(
        _ command: NavigationCommand<R>,
        state currentState: inout RouteStack<R>,
        shouldNotifyOnChange: Bool
    ) -> ExecutionOutcome {
        switch command {
        case .sequence(let commands):
            let outcomes = commands.map {
                executeSingle($0, state: &currentState, shouldNotifyOnChange: shouldNotifyOnChange)
            }
            return ExecutionOutcome(
                executedCommands: outcomes.flatMap(\.executedCommands),
                result: .multiple(outcomes.map(\.result))
            )

        case .whenCancelled(let primary, let fallback):
            let snapshot = currentState
            let primaryOutcome = executeSingle(
                primary,
                state: &currentState,
                shouldNotifyOnChange: false
            )
            if primaryOutcome.result.isSuccess {
                emitChangeIfNeeded(
                    from: snapshot,
                    to: currentState,
                    shouldNotifyOnChange: shouldNotifyOnChange
                )
                return ExecutionOutcome(
                    executedCommands: primaryOutcome.executedCommands,
                    result: primaryOutcome.result
                )
            }

            currentState = snapshot
            let fallbackOutcome = executeSingle(
                fallback,
                state: &currentState,
                shouldNotifyOnChange: false
            )
            emitChangeIfNeeded(
                from: snapshot,
                to: currentState,
                shouldNotifyOnChange: shouldNotifyOnChange
            )
            return ExecutionOutcome(
                executedCommands: primaryOutcome.executedCommands + fallbackOutcome.executedCommands,
                result: fallbackOutcome.result
            )

        default:
            let stateBefore = currentState
            let interceptionOutcome = middlewareRegistry.intercept(command, state: stateBefore)
            switch interceptionOutcome.interception {
            case .cancel(let reason):
                let result: NavigationResult<R> = .cancelled(reason)
                return finishExecution(
                    command: interceptionOutcome.command,
                    executedCommands: [],
                    result: result,
                    participants: interceptionOutcome.participants,
                    stateBefore: stateBefore,
                    currentState: &currentState,
                    shouldNotifyOnChange: shouldNotifyOnChange
                )

            case .proceed(let commandToExecute):
                let result = engine.apply(commandToExecute, to: &currentState)
                return finishExecution(
                    command: commandToExecute,
                    executedCommands: [commandToExecute],
                    result: result,
                    participants: interceptionOutcome.participants,
                    stateBefore: stateBefore,
                    currentState: &currentState,
                    shouldNotifyOnChange: shouldNotifyOnChange
                )
            }
        }
    }

    private func finishExecution(
        command: NavigationCommand<R>,
        executedCommands: [NavigationCommand<R>],
        result: NavigationResult<R>,
        participants: [AnyNavigationMiddleware<R>],
        stateBefore: RouteStack<R>,
        currentState: inout RouteStack<R>,
        shouldNotifyOnChange: Bool
    ) -> ExecutionOutcome {
        let finalResult = middlewareRegistry.didExecute(
            command,
            result: result,
            state: currentState,
            participants: participants
        )

        emitChangeIfNeeded(
            from: stateBefore,
            to: currentState,
            shouldNotifyOnChange: shouldNotifyOnChange
        )
        return ExecutionOutcome(
            executedCommands: executedCommands,
            result: finalResult
        )
    }

    private func resolvePathMismatch(
        from oldPath: [R],
        to newPath: [R]
    ) -> NavigationPathMismatchResolution<R> {
        let policy: NavigationStoreTelemetryEvent<R>.PathMismatchPolicy
        let resolution: NavigationPathMismatchResolution<R>

        switch pathMismatchPolicy {
        case .replace:
            policy = .replace
            resolution = .single(.replace(newPath))

        case .assertAndReplace:
            policy = .assertAndReplace
            pathMismatchAssertionHandler(oldPath, newPath)
            resolution = .single(.replace(newPath))

        case .ignore:
            policy = .ignore
            resolution = .ignore

        case .custom(let transform):
            policy = .custom
            resolution = transform(oldPath, newPath)
        }

        telemetrySink.recordPathMismatch(
            policy: policy,
            resolution: resolution,
            oldPath: oldPath,
            newPath: newPath
        )
        return resolution
    }

    private func emitChangeIfNeeded(
        from oldState: RouteStack<R>,
        to newState: RouteStack<R>,
        shouldNotifyOnChange: Bool
    ) {
        guard shouldNotifyOnChange, newState != oldState else { return }
        onChange?(oldState, newState)
        broadcaster.broadcast(.changed(from: oldState, to: newState))
    }

    private static var defaultPathMismatchAssertionHandler: @MainActor @Sendable ([R], [R]) -> Void {
        { oldPath, newPath in
            assertionFailure(
                """
                Navigation path mismatch detected. \
                Falling back to replace.
                oldPath: \(String(describing: oldPath))
                newPath: \(String(describing: newPath))
                """
            )
        }
    }

    private struct ExecutionOutcome {
        let executedCommands: [NavigationCommand<R>]
        let result: NavigationResult<R>
    }
}
