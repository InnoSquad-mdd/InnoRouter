public struct RouteStack<R: Route>: Sendable, Equatable {
    public internal(set) var path: [R] {
        didSet {
            #if DEBUG
            // Module-internal mutators (`NavigationEngine`,
            // `FlowStore` path projection, `NavigationStore`
            // reconciliation) all funnel through this `path`
            // setter, so it is the canonical place to anchor
            // future RouteStack invariants. The DEBUG-only call to
            // `assertPathIsConsistent(oldValue:)` runs the hook
            // that subsequent commits will fill in (path-level
            // duplicate policies, modal-tail invariants outside
            // `FlowStore`, etc.) without churning the public API.
            // Production builds compile the call out entirely.
            assertPathIsConsistent(oldValue: oldValue)
            #endif
        }
    }

    #if DEBUG
    /// DEBUG-only invariant hook. Called from the `path` `didSet`
    /// after every internal mutation. Intentionally a no-op today;
    /// future commits attach domain-level invariants here without
    /// touching the public surface or affecting production-build
    /// performance.
    private func assertPathIsConsistent(oldValue: [R]) {
        // Hook reserved for future invariants.
    }
    #endif

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

// MARK: - Codable (opt-in when the underlying route is Codable)

extension RouteStack: Encodable where R: Encodable {}
extension RouteStack: Decodable where R: Decodable {}
