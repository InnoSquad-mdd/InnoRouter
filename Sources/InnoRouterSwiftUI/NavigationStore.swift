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

    public var middlewareHandles: [NavigationMiddlewareHandle] {
        middlewareRegistry.handles
    }

    public var middlewareMetadata: [NavigationMiddlewareMetadata] {
        middlewareRegistry.metadata
    }

    public init(
        initial: RouteStack<R> = .init(),
        configuration: NavigationStoreConfiguration<R> = .init()
    ) {
        let telemetrySink = NavigationStoreTelemetrySink<R>(logger: configuration.logger)
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
        let telemetrySink = NavigationStoreTelemetrySink(
            logger: configuration.logger,
            recorder: telemetryRecorder
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
        executeSingle(command, shouldNotifyOnChange: true).result
    }

    @discardableResult
    public func executeBatch(
        _ commands: [NavigationCommand<R>],
        stopOnFailure: Bool = false
    ) -> NavigationBatchResult<R> {
        let stateBefore = state
        var executedCommands: [NavigationCommand<R>] = []
        var results: [NavigationResult<R>] = []
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
        return batch
    }

    @discardableResult
    public func executeTransaction(
        _ commands: [NavigationCommand<R>]
    ) -> NavigationTransactionResult<R> {
        let stateBefore = state
        var shadowState = state
        var outcomes: [TransactionOutcome] = []
        var executedCommands: [NavigationCommand<R>] = []
        var failureIndex: Int?

        for (index, command) in commands.enumerated() {
            let outcome = executeTransactionCommand(command, state: &shadowState)
            outcomes.append(outcome)
            executedCommands.append(contentsOf: outcome.executedCommands)

            if outcome.result.isSuccess {
                continue
            } else {
                failureIndex = index
                break
            }
        }

        let isCommitted = failureIndex == nil
        let results: [NavigationResult<R>]
        if isCommitted {
            state = shadowState
            results = outcomes.map { $0.committedResult(using: middlewareRegistry) }
            if state != stateBefore {
                onChange?(stateBefore, state)
            }
        } else {
            results = outcomes.map(\.result)
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
            if count == state.path.count {
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
                requestedCommand: command,
                executedCommands: outcomes.flatMap(\.executedCommands),
                result: .multiple(outcomes.map(\.result))
            )

        default:
            let stateBefore = currentState
            switch middlewareRegistry.intercept(command, state: stateBefore) {
            case .cancel(let reason):
                let result: NavigationResult<R> = .cancelled(reason)
                return finishExecution(
                    requestedCommand: command,
                    command: command,
                    executedCommands: [],
                    result: result,
                    stateBefore: stateBefore,
                    currentState: &currentState,
                    shouldNotifyOnChange: shouldNotifyOnChange
                )
            case .proceed(let commandToExecute):
                let result = engine.apply(commandToExecute, to: &currentState)
                return finishExecution(
                    requestedCommand: command,
                    command: commandToExecute,
                    executedCommands: [commandToExecute],
                    result: result,
                    stateBefore: stateBefore,
                    currentState: &currentState,
                    shouldNotifyOnChange: shouldNotifyOnChange
                )
            }
        }
    }

    private func finishExecution(
        requestedCommand: NavigationCommand<R>,
        command: NavigationCommand<R>,
        executedCommands: [NavigationCommand<R>],
        result: NavigationResult<R>,
        stateBefore: RouteStack<R>,
        currentState: inout RouteStack<R>,
        shouldNotifyOnChange: Bool
    ) -> ExecutionOutcome {
        let finalResult = middlewareRegistry.didExecute(command, result: result, state: currentState)

        if shouldNotifyOnChange, currentState != stateBefore {
            onChange?(stateBefore, currentState)
        }
        return ExecutionOutcome(
            requestedCommand: requestedCommand,
            executedCommands: executedCommands,
            result: finalResult
        )
    }

    private func executeTransactionCommand(
        _ command: NavigationCommand<R>,
        state currentState: inout RouteStack<R>
    ) -> TransactionOutcome {
        switch command {
        case .sequence(let commands):
            var outcomes: [TransactionOutcome] = []
            var executedCommands: [NavigationCommand<R>] = []

            for nestedCommand in commands {
                let outcome = executeTransactionCommand(nestedCommand, state: &currentState)
                outcomes.append(outcome)
                executedCommands.append(contentsOf: outcome.executedCommands)
                if !outcome.result.isSuccess {
                    return TransactionOutcome(
                        requestedCommand: command,
                        executedCommands: executedCommands,
                        result: .multiple(outcomes.map(\.result)),
                        node: nil
                    )
                }
            }

            return TransactionOutcome(
                requestedCommand: command,
                executedCommands: executedCommands,
                result: .multiple(outcomes.map(\.result)),
                node: .sequence(outcomes)
            )

        default:
            let stateBefore = currentState
            switch middlewareRegistry.intercept(command, state: stateBefore) {
            case .cancel(let reason):
                return TransactionOutcome(
                    requestedCommand: command,
                    executedCommands: [],
                    result: .cancelled(reason),
                    node: nil
                )
            case .proceed(let commandToExecute):
                let result = engine.apply(commandToExecute, to: &currentState)
                guard result.isSuccess else {
                    return TransactionOutcome(
                        requestedCommand: command,
                        executedCommands: [commandToExecute],
                        result: result,
                        node: nil
                    )
                }

                return TransactionOutcome(
                    requestedCommand: command,
                    executedCommands: [commandToExecute],
                    result: result,
                    node: .leaf(
                        CommittedStep(
                            command: commandToExecute,
                            result: result,
                            stateAfter: currentState
                        )
                    )
                )
            }
        }
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

    private struct CommittedStep {
        let command: NavigationCommand<R>
        let result: NavigationResult<R>
        let stateAfter: RouteStack<R>
    }

    private struct ExecutionOutcome {
        let requestedCommand: NavigationCommand<R>
        let executedCommands: [NavigationCommand<R>]
        let result: NavigationResult<R>
    }

    private indirect enum TransactionNode {
        case leaf(CommittedStep)
        case sequence([TransactionOutcome])
    }

    private struct TransactionOutcome {
        let requestedCommand: NavigationCommand<R>
        let executedCommands: [NavigationCommand<R>]
        let result: NavigationResult<R>

        let node: TransactionNode?

        @MainActor
        func committedResult(
            using middlewareRegistry: NavigationMiddlewareRegistry<R>
        ) -> NavigationResult<R> {
            switch node {
            case .leaf(let step):
                return middlewareRegistry.didExecute(
                    step.command,
                    result: step.result,
                    state: step.stateAfter
                )
            case .sequence(let outcomes):
                var committedResults: [NavigationResult<R>] = []
                committedResults.reserveCapacity(outcomes.count)
                for outcome in outcomes {
                    committedResults.append(outcome.committedResult(using: middlewareRegistry))
                }
                return .multiple(committedResults)
            case nil:
                return result
            }
        }
    }
}
