import Observation
import SwiftUI

import InnoRouterCore

@Observable
@MainActor
public final class NavigationStore<R: Route>: Navigator {
    public typealias RouteType = R

    public var state: RouteStack<R>

    @ObservationIgnored
    private let engine: NavigationEngine<R>

    @ObservationIgnored
    private var middlewares: [AnyNavigationMiddleware<R>]

    @ObservationIgnored
    private var onChange: (@MainActor (_ old: RouteStack<R>, _ new: RouteStack<R>) -> Void)?

    public init(
        initial: RouteStack<R> = .init(),
        engine: NavigationEngine<R> = .init(),
        middlewares: [AnyNavigationMiddleware<R>] = [],
        onChange: (@MainActor (_ old: RouteStack<R>, _ new: RouteStack<R>) -> Void)? = nil
    ) {
        self.state = initial
        self.engine = engine
        self.middlewares = middlewares
        self.onChange = onChange
    }

    public convenience init(
        initialPath: [R],
        onChange: (@MainActor (_ old: RouteStack<R>, _ new: RouteStack<R>) -> Void)? = nil
    ) {
        self.init(initial: RouteStack(path: initialPath), onChange: onChange)
    }

    public func addMiddleware(_ middleware: AnyNavigationMiddleware<R>) {
        middlewares.append(middleware)
    }

    @discardableResult
    public func execute(_ command: NavigationCommand<R>) -> NavigationResult<R> {
        switch command {
        case .sequence(let commands):
            return .multiple(commands.map { execute($0) })

        default:
            break
        }

        let stateBefore = state
        var effectiveCommand: NavigationCommand<R>? = command
        var executedMiddlewares: [AnyNavigationMiddleware<R>] = []

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

public extension NavigationStore {
    func send(_ intent: NavigationIntent<R>) {
        switch intent {
        case .go(let route):
            _ = execute(.push(route))

        case .goMany(let routes):
            guard !routes.isEmpty else { return }
            let commands = routes.map { NavigationCommand<R>.push($0) }
            _ = execute(.sequence(commands))

        case .back:
            _ = execute(.pop)

        case .backBy(let count):
            _ = execute(.popCount(count))

        case .backTo(let route):
            _ = execute(.popTo(route))

        case .backToRoot:
            _ = execute(.popToRoot)

        case .resetTo(let routes):
            _ = execute(.replace(routes))

        case .deepLink:
            // Handled by DeepLinkPipeline entry points (Coordinator/Effect handlers); intentionally no-op here.
            break
        }
    }

    var pathBinding: Binding<[R]> {
        Binding(
            get: { self.state.path },
            set: { newPath in
                _ = self.execute(.replace(newPath))
            }
        )
    }
}
