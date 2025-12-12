public struct NavStack<R: Route>: Sendable, Equatable {
    public var path: [R]

    public init(path: [R] = []) {
        self.path = path
    }
}

