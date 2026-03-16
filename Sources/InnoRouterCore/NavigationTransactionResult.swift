/// Describes the outcome of a transactional navigation execution.
public struct NavigationTransactionResult<R: Route>: Sendable, Equatable {
    /// Commands originally requested for transactional execution.
    public let requestedCommands: [NavigationCommand<R>]
    /// Commands actually executed after middleware interception and rewriting.
    public let executedCommands: [NavigationCommand<R>]
    /// Top-level command results recorded in request order.
    public let results: [NavigationResult<R>]
    /// Navigation state before the transaction started.
    public let stateBefore: RouteStack<R>
    /// Navigation state after the transaction finished.
    ///
    /// On rollback, this is the same snapshot as `stateBefore`.
    public let stateAfter: RouteStack<R>
    /// The index of the first failed top-level command, or `nil` on commit.
    public let failureIndex: Int?
    /// `true` when the transaction committed, `false` when it rolled back.
    public let isCommitted: Bool

    /// Creates a transaction execution result.
    public init(
        requestedCommands: [NavigationCommand<R>],
        executedCommands: [NavigationCommand<R>],
        results: [NavigationResult<R>],
        stateBefore: RouteStack<R>,
        stateAfter: RouteStack<R>,
        failureIndex: Int?,
        isCommitted: Bool
    ) {
        self.requestedCommands = requestedCommands
        self.executedCommands = executedCommands
        self.results = results
        self.stateBefore = stateBefore
        self.stateAfter = stateAfter
        self.failureIndex = failureIndex
        self.isCommitted = isCommitted
    }
}
