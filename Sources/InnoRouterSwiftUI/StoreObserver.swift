// MARK: - StoreObserver.swift
// InnoRouterSwiftUI - protocol-style adapter over store events streams
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation
import InnoRouterCore

/// Protocol-style adapter over the `events` `AsyncStream` that
/// ``NavigationStore`` / ``ModalStore`` / ``FlowStore`` expose.
///
/// Use `StoreObserver` when routing events to static methods reads
/// clearer than a `for await` loop (AppDelegate wiring, analytics
/// adapters, plugin-like integration layers). Use the raw stream
/// when cancellation flow or composition with async sequences
/// matters more.
///
/// This is a **convenience** — the underlying events stream remains
/// the single source of truth. Multiple observers can be attached
/// to the same store; each gets its own subscription and their
/// cancellation is independent.
@MainActor
public protocol StoreObserver: AnyObject {
    associatedtype RouteType: Route

    /// Called for every `NavigationStore` or inner navigation event
    /// the observer is attached to.
    func handle(_ event: NavigationEvent<RouteType>)

    /// Called for every `ModalStore` or inner modal event the
    /// observer is attached to.
    func handle(_ event: ModalEvent<RouteType>)

    /// Called for every `FlowStore` event the observer is attached to.
    func handle(_ event: FlowEvent<RouteType>)
}

public extension StoreObserver {
    func handle(_ event: NavigationEvent<RouteType>) {}
    func handle(_ event: ModalEvent<RouteType>) {}
    func handle(_ event: FlowEvent<RouteType>) {}
}

/// Opaque subscription handle returned from `observe(_:)`. Cancel
/// explicitly, or let the subscription deinit cancel itself when the
/// owner (typically the observer itself, or a scene coordinator)
/// goes away.
@MainActor
public final class StoreObserverSubscription {
    private var task: Task<Void, Never>?

    init(task: Task<Void, Never>) {
        self.task = task
    }

    /// Cancels the subscription. Idempotent.
    public func cancel() {
        task?.cancel()
        task = nil
    }

    isolated deinit {
        task?.cancel()
    }
}

public extension NavigationStore {
    /// Subscribes `observer` to this store's `events` stream. The
    /// observer's `handle(_: NavigationEvent<R>)` is invoked for
    /// every emitted event until the returned subscription is
    /// cancelled or the observer deinitialises.
    @discardableResult
    func observe<O: StoreObserver>(_ observer: O) -> StoreObserverSubscription
    where O.RouteType == R {
        let eventsStream = events
        let task = Task { [weak observer] in
            for await event in eventsStream {
                guard let observer else { return }
                observer.handle(event)
            }
        }
        return StoreObserverSubscription(task: task)
    }
}

public extension ModalStore {
    /// Subscribes `observer` to this store's `events` stream. The
    /// observer's `handle(_: ModalEvent<M>)` is invoked for every
    /// emitted event until the subscription is cancelled.
    @discardableResult
    func observe<O: StoreObserver>(_ observer: O) -> StoreObserverSubscription
    where O.RouteType == M {
        let eventsStream = events
        let task = Task { [weak observer] in
            for await event in eventsStream {
                guard let observer else { return }
                observer.handle(event)
            }
        }
        return StoreObserverSubscription(task: task)
    }
}

public extension FlowStore {
    /// Subscribes `observer` to this store's `events` stream.
    /// `FlowStore.events` wraps inner navigation / modal emissions,
    /// so a single subscription routes all three event types
    /// through the observer's typed `handle(_:)` overloads.
    @discardableResult
    func observe<O: StoreObserver>(_ observer: O) -> StoreObserverSubscription
    where O.RouteType == R {
        let eventsStream = events
        let task = Task { [weak observer] in
            for await event in eventsStream {
                guard let observer else { return }
                switch event {
                case .navigation(let navEvent):
                    observer.handle(navEvent)
                case .modal(let modalEvent):
                    observer.handle(modalEvent)
                default:
                    observer.handle(event)
                }
            }
        }
        return StoreObserverSubscription(task: task)
    }
}
