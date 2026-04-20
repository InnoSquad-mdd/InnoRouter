/// A declarative description of a `FlowStore` path suitable for value-level
/// serialization, deep-link plans, or state restoration.
///
/// `FlowStore.apply(_:)` is the canonical entry point that transforms a
/// `FlowPlan` into a sequence of navigation + modal commands, observing the
/// same invariants as `FlowStore.send(.reset(_:))`:
///
/// - At most one modal step is permitted.
/// - A modal step must be the final element of `steps`.
/// - All other steps must be `.push`.
public struct FlowPlan<R: Route>: Sendable, Equatable {
    /// Ordered steps describing the desired flow stack state.
    public var steps: [RouteStep<R>]

    /// Creates a new flow plan.
    public init(steps: [RouteStep<R>] = []) {
        self.steps = steps
    }
}
