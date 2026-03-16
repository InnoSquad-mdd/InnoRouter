import Foundation

/// Opaque identifier for a registered navigation middleware instance.
public struct NavigationMiddlewareHandle: Hashable, Sendable {
    private let rawValue: UUID

    /// Creates a new middleware handle.
    public init() {
        self.rawValue = UUID()
    }

    var logValue: String {
        rawValue.uuidString
    }
}
