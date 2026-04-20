// MARK: - TestEventQueue.swift
// InnoRouterTesting - FIFO event queue shared by all test stores
// Copyright © 2026 Inno Squad. All rights reserved.

/// A FIFO queue of events observed by a test store.
///
/// Used internally by `NavigationTestStore`, `ModalTestStore`, and
/// `FlowTestStore` to buffer events produced by their underlying authority
/// between `send(...)` and `receive(...)` calls. All test stores are
/// `@MainActor`-isolated, so the queue does not require an internal lock —
/// the actor isolation itself serialises access.
@MainActor
final class TestEventQueue<Event> {
    private var events: [Event] = []

    init() {}

    /// Appends an event to the tail of the queue.
    func enqueue(_ event: Event) {
        events.append(event)
    }

    /// Dequeues and returns the head of the queue, or `nil` if empty.
    func dequeue() -> Event? {
        guard !events.isEmpty else { return nil }
        return events.removeFirst()
    }

    /// A snapshot of all events currently buffered, in FIFO order.
    var remaining: [Event] {
        events
    }

    /// Whether the queue currently contains no events.
    var isEmpty: Bool {
        events.isEmpty
    }

    /// The number of events currently buffered.
    var count: Int {
        events.count
    }

    /// Drops every buffered event without firing any assertions.
    func drain() {
        events.removeAll()
    }
}
