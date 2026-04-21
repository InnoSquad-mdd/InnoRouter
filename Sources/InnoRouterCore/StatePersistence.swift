import Foundation

/// A small helper that serialises and restores `FlowPlan` / `RouteStack`
/// values through user-supplied `JSONEncoder` and `JSONDecoder` instances.
///
/// `StatePersistence` deliberately focuses on the Data ↔ value boundary
/// and stays out of file I/O, `UserDefaults`, iCloud, or lifecycle
/// callbacks. That lets apps decide where to persist restoration
/// snapshots while still getting a cohesive typed entry point:
///
/// ```swift
/// let persistence = StatePersistence<AppRoute>()
/// let data = try persistence.encode(flowStore.path.toFlowPlan())
/// try data.write(to: restorationURL)
///
/// // ...on next launch:
/// let restored = try persistence.decode(Data(contentsOf: restorationURL))
/// flowStore.apply(restored)
/// ```
///
/// Both encoding and decoding are `throws`; they surface the underlying
/// `EncodingError` / `DecodingError` so callers can make recovery
/// decisions without losing diagnostic context.
public struct StatePersistence<R: Route & Codable>: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a persistence helper.
    ///
    /// - Parameters:
    ///   - encoder: The `JSONEncoder` used for all `encode(_:)` calls.
    ///     Supply a configured encoder (for example, with
    ///     `.sortedKeys` for deterministic snapshots) if the default
    ///     isn't suitable.
    ///   - decoder: The `JSONDecoder` used for all `decode(_:)` calls.
    public init(
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.encoder = encoder
        self.decoder = decoder
    }

    // MARK: - FlowPlan

    /// Encodes a `FlowPlan` into `Data`.
    public func encode(_ plan: FlowPlan<R>) throws -> Data {
        try encoder.encode(plan)
    }

    /// Decodes a `FlowPlan` previously written by `encode(_:)`.
    public func decode(_ data: Data) throws -> FlowPlan<R> {
        try decoder.decode(FlowPlan<R>.self, from: data)
    }

    // MARK: - RouteStack

    /// Encodes a `RouteStack` into `Data`.
    public func encode(_ stack: RouteStack<R>) throws -> Data {
        try encoder.encode(stack)
    }

    /// Decodes a `RouteStack` previously written by `encode(_:)`.
    public func decodeStack(_ data: Data) throws -> RouteStack<R> {
        try decoder.decode(RouteStack<R>.self, from: data)
    }
}
