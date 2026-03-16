public struct RouteStack<R: Route>: Sendable, Equatable {
    public internal(set) var path: [R]

    public init() {
        self.path = []
    }

    public init(
        validating path: [R],
        using validator: RouteStackValidator<R> = .permissive
    ) throws {
        try validator.validate(path)
        self.path = path
    }

    package init(path: [R]) {
        self.path = path
    }
}
