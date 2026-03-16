public struct NavigationBatchResult<R: Route>: Sendable, Equatable {
    public let requestedCommands: [NavigationCommand<R>]
    public let executedCommands: [NavigationCommand<R>]
    public let results: [NavigationResult<R>]
    public let stateBefore: RouteStack<R>
    public let stateAfter: RouteStack<R>
    public let hasStoppedOnFailure: Bool

    public var isSuccess: Bool {
        !results.isEmpty && results.allSatisfy(\.isSuccess)
    }

    public init(
        requestedCommands: [NavigationCommand<R>],
        executedCommands: [NavigationCommand<R>],
        results: [NavigationResult<R>],
        stateBefore: RouteStack<R>,
        stateAfter: RouteStack<R>,
        hasStoppedOnFailure: Bool
    ) {
        self.requestedCommands = requestedCommands
        self.executedCommands = executedCommands
        self.results = results
        self.stateBefore = stateBefore
        self.stateAfter = stateAfter
        self.hasStoppedOnFailure = hasStoppedOnFailure
    }
}
