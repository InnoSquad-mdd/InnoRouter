import SwiftUI

/// A coordinator that reports completion back to a parent with a typed result.
///
/// Used together with ``Coordinator/push(child:)`` to await a child flow's
/// outcome without hand-wiring closures per call site. The child is
/// responsible for invoking ``onFinish`` exactly once on success or
/// ``onCancel`` on dismissal; subsequent callback firings are ignored.
///
/// Child lifetimes are orchestrated at the coordinator layer — the
/// parent owns the strong reference until the returned `Task` resolves.
/// See `Docs/design-child-coordinator-handoff.md` for the full contract.
@MainActor
public protocol ChildCoordinator: AnyObject {
    associatedtype Result: Sendable

    /// Called by the child to report a successful completion.
    var onFinish: (@MainActor (Result) -> Void)? { get set }

    /// Called by the child to report cancellation or user-driven dismissal.
    var onCancel: (@MainActor () -> Void)? { get set }
}

public extension Coordinator {
    /// Installs completion callbacks on the given child and returns a Task
    /// that resolves with the child's result, or `nil` on cancellation.
    ///
    /// The parent is responsible for placing the child's view in its tree
    /// (push, sheet, cover) and for tearing that placement down after the
    /// Task resolves. This API covers **result propagation only**; the
    /// child's view lifecycle is deliberately not automated.
    ///
    /// Callbacks are installed synchronously before the returned Task
    /// begins awaiting, so it is safe for the child to fire `onFinish`
    /// or `onCancel` at any point after this call — even before the
    /// parent's `await`. Subsequent callback firings are ignored.
    @MainActor
    @discardableResult
    func push<Child: ChildCoordinator>(
        child: Child
    ) -> Task<Child.Result?, Never> {
        let (stream, continuation) = AsyncStream<Child.Result?>.makeStream()
        child.onFinish = { result in
            continuation.yield(result)
            continuation.finish()
        }
        child.onCancel = {
            continuation.yield(nil)
            continuation.finish()
        }
        return Task { @MainActor in
            var iterator = stream.makeAsyncIterator()
            return await iterator.next() ?? nil
        }
    }
}
