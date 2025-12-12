import Observation
import SwiftUI

import InnoRouterCore

@Observable
@MainActor
public final class NavStore<R: Route>: Navigator, @unchecked Sendable {
    public typealias RouteType = R

    public var state: NavStack<R>

    @ObservationIgnored
    private let engine: NavEngine<R>

    @ObservationIgnored
    private var middlewares: [AnyNavMiddleware<R>]

    @ObservationIgnored
    private var onChange: (@MainActor (_ old: NavStack<R>, _ new: NavStack<R>) -> Void)?

    public init(
        initial: NavStack<R> = .init(),
        engine: NavEngine<R> = .init(),
        middlewares: [AnyNavMiddleware<R>] = [],
        onChange: (@MainActor (_ old: NavStack<R>, _ new: NavStack<R>) -> Void)? = nil
    ) {
        self.state = initial
        self.engine = engine
        self.middlewares = middlewares
        self.onChange = onChange
    }

    public convenience init(
        initialPath: [R],
        onChange: (@MainActor (_ old: NavStack<R>, _ new: NavStack<R>) -> Void)? = nil
    ) {
        self.init(initial: NavStack(path: initialPath), onChange: onChange)
    }

    public func addMiddleware(_ middleware: AnyNavMiddleware<R>) {
        middlewares.append(middleware)
    }

    @discardableResult
    public func execute(_ command: NavCommand<R>) -> NavResult<R> {
        switch command {
        case .sequence(let commands):
            return .multiple(commands.map { execute($0) })

        case .conditional(let condition, let nested):
            guard condition() else { return .conditionNotMet }
            return execute(nested)

        default:
            break
        }

        let stateBefore = state
        var effectiveCommand: NavCommand<R>? = command
        var executedMiddlewares: [AnyNavMiddleware<R>] = []

        for middleware in middlewares {
            guard let current = effectiveCommand else { break }
            effectiveCommand = middleware.willExecute(current, state: stateBefore)
            executedMiddlewares.append(middleware)
        }

        guard let commandToRun = effectiveCommand else {
            for middleware in executedMiddlewares {
                middleware.didExecute(command, result: .cancelled, state: state)
            }
            return .cancelled
        }

        var newState = state
        let result = engine.apply(commandToRun, to: &newState)
        state = newState

        if stateBefore != state {
            onChange?(stateBefore, state)
        }

        for middleware in executedMiddlewares {
            middleware.didExecute(commandToRun, result: result, state: state)
        }

        return result
    }
}

public extension NavStore {
    var pathBinding: Binding<[R]> {
        Binding(
            get: { self.state.path },
            set: { newPath in
                _ = self.execute(.replace(newPath))
            }
        )
    }
}
