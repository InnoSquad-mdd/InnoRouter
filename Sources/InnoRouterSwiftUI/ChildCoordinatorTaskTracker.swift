// MARK: - ChildCoordinatorTaskTracker.swift
// InnoRouterSwiftUI - opt-in task bookkeeping for child coordinators
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation

/// Tracks transient `Task`s a `ChildCoordinator` spawns so
/// ``ChildCoordinator/parentDidCancel()`` can cancel them all in one
/// call. Opt-in: child coordinators that don't need task tracking
/// simply don't create a tracker.
///
/// ```swift
/// final class SignUpCoordinator: ChildCoordinator {
///     private let tasks = ChildCoordinatorTaskTracker()
///
///     func fetchAccount() {
///         tasks.track {
///             _ = try? await AccountClient.shared.load()
///         }
///     }
///
///     func parentDidCancel() {
///         tasks.cancelAll()
///     }
/// }
/// ```
///
/// When the tracker deallocates it cancels any outstanding tasks so
/// callers don't have to remember to invoke `cancelAll()` in every
/// teardown path.
@MainActor
public final class ChildCoordinatorTaskTracker {
    private var tasks: [UUID: Task<Void, Never>] = [:]

    public init() {}

    /// Launches `operation` inside a tracked `Task` and returns the
    /// Task so callers that need to `await` it directly can do so.
    /// The tracker retains the Task until it finishes or
    /// ``cancelAll()`` / deinit cancels it.
    @discardableResult
    public func track(
        priority: TaskPriority? = nil,
        _ operation: @escaping @MainActor @Sendable () async -> Void
    ) -> Task<Void, Never> {
        let id = UUID()
        let task = Task(priority: priority) { [weak self] in
            await operation()
            await MainActor.run { [weak self] in
                self?.tasks[id] = nil
            }
        }
        tasks[id] = task
        return task
    }

    /// Cancels every tracked task and clears the tracker.
    public func cancelAll() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
    }

    /// Number of tasks currently tracked (for observability / tests).
    public var activeCount: Int {
        tasks.count
    }

    isolated deinit {
        for task in tasks.values { task.cancel() }
    }
}
