// MARK: - FlowPendingDeepLinkPersistence.swift
// InnoRouterDeepLink - Data ↔ FlowPendingDeepLink bridge
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation
import InnoRouterCore

/// Serialises and restores ``FlowPendingDeepLink`` values so a
/// pending deep link queued while the user is signed out can survive
/// a process kill and replay on next launch.
///
/// Mirrors `StatePersistence<R>` (InnoRouterCore): Data ↔ value
/// discipline, no file I/O policy baked in (the app chooses file
/// URL, `UserDefaults`, iCloud, etc.). Pushes the underlying
/// `EncodingError` / `DecodingError` through so callers can
/// distinguish schema drift from I/O failures.
///
/// Only the flow-level pipeline's pending type is Codable —
/// push-only `PendingDeepLink` wraps `NavigationPlan` which is a
/// runtime type and deliberately non-Codable. Use
/// `FlowDeepLinkPipeline` + this helper for cross-launch pending
/// state.
public struct FlowPendingDeepLinkPersistence<R: Route & Codable>: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.encoder = encoder
        self.decoder = decoder
    }

    /// Encodes a `FlowPendingDeepLink` to `Data` for persistence.
    public func encode(_ pending: FlowPendingDeepLink<R>) throws -> Data {
        try encoder.encode(pending)
    }

    /// Decodes a persisted `FlowPendingDeepLink` back into memory.
    public func decode(_ data: Data) throws -> FlowPendingDeepLink<R> {
        try decoder.decode(FlowPendingDeepLink<R>.self, from: data)
    }
}
