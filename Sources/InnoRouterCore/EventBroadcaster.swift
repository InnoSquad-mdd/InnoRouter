// MARK: - EventBroadcaster.swift
// InnoRouterCore — MainActor-isolated multi-subscriber event fan-out
// shared by every store authority.
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation

/// Package-internal helper that fans a single event out to multiple
/// `AsyncStream` subscribers.
///
/// Each store (`NavigationStore`, `ModalStore`, `FlowStore`,
/// `SceneStore`) owns one broadcaster keyed by its event enum.
/// Subscribers receive their own `AsyncStream` via `stream()`, and the
/// broadcaster cleans up per-subscriber state through
/// `AsyncStream.Continuation.onTermination` so cancelled `for await`
/// loops do not leak continuations.
///
/// `@MainActor` isolation matches the authority of every store that
/// owns an instance. `isolated deinit` (SE-0371 / Swift 6.2) lets the
/// deinit safely iterate the main-actor state when the store tears
/// down.
///
/// Lives in `InnoRouterCore` (not SwiftUI) because the fan-out is a
/// SwiftUI-free runtime primitive — `AsyncStream` + `UUID` +
/// `@MainActor` are all available without importing SwiftUI. Declared
/// at `package` visibility so every InnoRouter module can use the
/// same instance without paying a new public-API surface.
@MainActor
package final class EventBroadcaster<Event: Sendable> {
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    package init() {}

    /// Returns a fresh `AsyncStream` that will receive every subsequent
    /// `broadcast(_:)` call until the consumer cancels its iterator or
    /// the broadcaster is deallocated.
    package func stream() -> AsyncStream<Event> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        continuations[id] = continuation
        continuation.onTermination = { @Sendable [weak self] _ in
            Task { @MainActor in
                self?.continuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    /// Fans `event` out to every live subscriber. Continuations that
    /// have already terminated are ignored.
    package func broadcast(_ event: Event) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    /// Number of live subscribers — exposed for test observability.
    package var subscriberCount: Int {
        continuations.count
    }

    isolated deinit {
        for continuation in continuations.values {
            continuation.finish()
        }
    }
}
