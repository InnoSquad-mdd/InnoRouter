import Foundation

public struct NavigationMiddlewareHandle: Hashable, Sendable {
    private let rawValue: UUID

    public init() {
        self.rawValue = UUID()
    }

    var logValue: String {
        rawValue.uuidString
    }
}
