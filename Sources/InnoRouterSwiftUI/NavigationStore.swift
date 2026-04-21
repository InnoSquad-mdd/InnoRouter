import InnoRouterCore
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
        let broadcaster = EventBroadcaster<NavigationEvent<R>>()
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
        let broadcaster = EventBroadcaster<NavigationEvent<R>>()
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
    }

    // MARK: - Public telemetry adapters

    private static func makePublicTelemetryRecorder(
        onMiddlewareMutation: (@MainActor @Sendable (MiddlewareMutationEvent<R>) -> Void)?,
        onPathMismatch: (@MainActor @Sendable (NavigationPathMismatchEvent<R>) -> Void)?
    ) -> NavigationStoreTelemetryRecorder<R>? {
        if onMiddlewareMutation == nil && onPathMismatch == nil {
            return nil
        }
        return { @MainActor event in
            switch event {
            case .middlewareMutation(let action, let metadata, let index):
                onMiddlewareMutation?(
                    MiddlewareMutationEvent(
                        action: Self.publicAction(for: action),
                        metadata: metadata,
                        index: index
                    )
                )
            case .pathMismatch(let policy, let resolution, let oldPath, let newPath):
                onPathMismatch?(
                    NavigationPathMismatchEvent(
                        policy: Self.publicPolicy(for: policy),
                        resolution: Self.publicResolution(for: resolution),
                        oldPath: oldPath,
                        newPath: newPath
                    )
                )
            }
        }
    }

    private static func makeBroadcastRecorder(
        broadcaster: EventBroadcaster<NavigationEvent<R>>
    ) -> NavigationStoreTelemetryRecorder<R>? {
        { @MainActor event in
            switch event {
            case .middlewareMutation(let action, let metadata, let index):
                broadcaster.broadcast(
                    .middlewareMutation(
                        MiddlewareMutationEvent(
                            action: Self.publicAction(for: action),
                            metadata: metadata,
                            index: index
                        )
                    )
                )
            case .pathMismatch(let policy, let resolution, let oldPath, let newPath):
                broadcaster.broadcast(
                    .pathMismatch(
                        NavigationPathMismatchEvent(
                            policy: Self.publicPolicy(for: policy),
                            resolution: Self.publicResolution(for: resolution),
                            oldPath: oldPath,
                            newPath: newPath
                        )
                    )
                )
            }
        }
    }

    private static func publicPolicy(
        for policy: NavigationStoreTelemetryEvent<R>.PathMismatchPolicy
    ) -> NavigationPathMismatchEvent<R>.Policy {
        switch policy {
        case .replace: return .replace
        case .assertAndReplace: return .assertAndReplace
        case .ignore: return .ignore
        case .custom: return .custom
        }
    }

    private static func publicResolution(
        for resolution: NavigationStoreTelemetryEvent<R>.PathMismatchResolution
    ) -> NavigationPathMismatchEvent<R>.Resolution {
        switch resolution {
        case .single(let command): return .single(command)
        case .batch(let commands): return .batch(commands)
        case .ignore: return .ignore
        }
    }

    private static func combineRecorders(
        _ primary: NavigationStoreTelemetryRecorder<R>?,
        _ secondary: NavigationStoreTelemetryRecorder<R>?
    ) -> NavigationStoreTelemetryRecorder<R>? {
        switch (primary, secondary) {
        case (nil, nil):
            return nil
        case (let primary?, nil):
            return primary
        case (nil, let secondary?):
            return secondary
        case (let primary?, let secondary?):
            return { event in
                primary(event)
                secondary(event)
            }
        }
    }

    private static func publicAction(
        for action: NavigationStoreTelemetryEvent<R>.MiddlewareMutation
    ) -> MiddlewareMutationEvent<R>.Action {
        switch action {
        case .added: return .added
        case .inserted: return .inserted
        case .removed: return .removed
        case .replaced: return .replaced
        case .moved: return .moved
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
        let journal = NavigationExecutionJournal.planLive(
            command,
            state: &state,
            middlewareRegistry: middlewareRegistry,
            engine: engine
        )
        return journal.realizeLive(
            using: middlewareRegistry,
            emitChange: { [weak self] oldState, newState in
                self?.onChange?(oldState, newState)
                self?.broadcaster.broadcast(.changed(from: oldState, to: newState))
            },
            shouldNotifyOnChange: true
        )
    }

    @discardableResult
    public func executeBatch(
        _ commands: [NavigationCommand<R>],
        stopOnFailure: Bool = false
    ) -> NavigationBatchResult<R> {
        let stateBefore = state
        var journals: [NavigationExecutionJournal<R>] = []
        var hasStoppedOnFailure = false

        for command in commands {
            let journal = NavigationExecutionJournal.planLive(
                command,
                state: &state,
                middlewareRegistry: middlewareRegistry,
                engine: engine
            )
            journals.append(journal)

            if stopOnFailure && !journal.result.isSuccess {
                hasStoppedOnFailure = true
                break
            }
        }

        let executedCommands = journals.flatMap(\.executedCommands)
        let results = journals.map {
            $0.realizeLive(
                using: middlewareRegistry,
                emitChange: { _, _ in },
                shouldNotifyOnChange: false
            )
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
    }

    @discardableResult
    public func executeTransaction(
        _ commands: [NavigationCommand<R>]
    ) -> NavigationTransactionResult<R> {
        let stateBefore = state
        var shadowState = state
        var journals: [NavigationExecutionJournal<R>] = []
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
        var shadowState = stateBefore
        return NavigationExecutionJournal.planLive(
            command,
            state: &shadowState,
            middlewareRegistry: middlewareRegistry,
            engine: engine
        )
    }

    @discardableResult
    func commitFlowPreview(_ preview: NavigationExecutionJournal<R>) -> NavigationResult<R> {
        let committedStateBefore = state
        state = preview.stateAfter

        let finalResult = preview.realizeLive(
            using: middlewareRegistry,
            emitChange: { [weak self] oldState, newState in
                self?.onChange?(oldState, newState)
                self?.broadcaster.broadcast(.changed(from: oldState, to: newState))
            },
            shouldNotifyOnChange: false
        )

        if state != committedStateBefore {
            onChange?(committedStateBefore, state)
            broadcaster.broadcast(.changed(from: committedStateBefore, to: state))
        }

        return finalResult
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
}
