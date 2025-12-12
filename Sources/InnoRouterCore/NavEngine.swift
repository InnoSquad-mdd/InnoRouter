public struct NavEngine<R: Route>: Sendable {
    public init() {}

    public func apply(_ command: NavCommand<R>, to state: inout NavStack<R>) -> NavResult<R> {
        switch command {
        case .push(let route):
            state.path.append(route)
            return .success

        case .pushAll(let routes):
            state.path.append(contentsOf: routes)
            return .success

        case .pop:
            guard !state.path.isEmpty else { return .stackEmpty }
            _ = state.path.removeLast()
            return .success

        case .popCount(let count):
            guard count > 0, count <= state.path.count else { return .stackEmpty }
            state.path.removeLast(count)
            return .success

        case .popToRoot:
            state.path.removeAll()
            return .success

        case .popTo(let route):
            guard let index = state.path.firstIndex(of: route) else { return .routeNotFound(route) }
            state.path = Array(state.path.prefix(through: index))
            return .success

        case .replace(let routes):
            state.path = routes
            return .success

        case .conditional(let condition, let nested):
            guard condition() else { return .conditionNotMet }
            return apply(nested, to: &state)

        case .sequence(let commands):
            let results = commands.map { apply($0, to: &state) }
            return .multiple(results)
        }
    }
}

