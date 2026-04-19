import Observation

import InnoRouterCore

/// Unified router store that represents push + modal progression as a single
/// array of `RouteStep`s, delegating execution to an inner `NavigationStore`
/// and `ModalStore`.
///
/// `FlowStore` is the single source of truth for flows where the user moves
/// through a sequence of destinations that may mix `push`, sheet, or
/// full-screen cover presentations — the classic login/checkout flow shape.
/// Consumers dispatch `FlowIntent` values via `send(_:)` or describe the full
/// end state with `FlowPlan` via `apply(_:)`.
///
/// ## Invariants
///
/// 1. Modal steps are always at most one and must be the final element of
///    `path`. `.sheet` / `.cover` in any other position is rejected.
/// 2. `.push` requests are rejected when the current tail is a modal step.
///    Consumers must dismiss first. The reason surfaces through
///    `FlowStoreConfiguration.onIntentRejected` as
///    `.pushBlockedByModalTail`.
/// 3. `.pop` / `.dismiss` against an empty path or missing modal tail are
///    silent no-ops (matching `NavigationIntent.back` conventions).
/// 4. Middleware cancellations from the inner navigation / modal store
///    automatically roll the flow path back and emit
///    `.middlewareRejected(debugName:)`.
@Observable
@MainActor
public final class FlowStore<R: Route> {
    /// Unified flow path. Push steps are the navigation prefix; at most one
    /// trailing modal step (`.sheet` / `.cover`) may sit at the tail.
    public private(set) var path: [RouteStep<R>]

    /// Inner navigation store that owns stack state for `.push` steps.
    public let navigationStore: NavigationStore<R>

    /// Inner modal store that owns presentation state for the tail modal step.
    public let modalStore: ModalStore<R>

    private let onPathChanged: (@MainActor @Sendable ([RouteStep<R>], [RouteStep<R>]) -> Void)?
    private let onIntentRejected: (@MainActor @Sendable (FlowIntent<R>, FlowRejectionReason) -> Void)?
    private let link: FlowStoreLink<R>

    // Bookkeeping toggled while FlowStore drives its own inner stores, so
    // observer callbacks can distinguish user / system-initiated changes.
    private var isApplyingInternalMutation: Bool = false

    /// Creates a new flow store.
    /// - Parameters:
    ///   - initial: Initial flow path. If it contains a tail modal step, that
    ///     step is seeded as `modalStore.currentPresentation`.
    ///   - configuration: Flow, navigation, and modal observation hooks.
    public init(
        initial: [RouteStep<R>] = [],
        configuration: FlowStoreConfiguration<R> = .init()
    ) {
        let validatedInitial = Self.validatedInitial(initial)

        let link = FlowStoreLink<R>()

        let userNavOnChange = configuration.navigation.onChange
        let userModalOnDismissed = configuration.modal.onDismissed

        let composedNavOnChange: @MainActor @Sendable (RouteStack<R>, RouteStack<R>) -> Void = { old, new in
            userNavOnChange?(old, new)
            link.owner?.handleNavigationStoreChange(from: old, to: new)
        }
        let composedModalOnDismissed: @MainActor @Sendable (ModalPresentation<R>, ModalDismissalReason) -> Void = { presentation, reason in
            userModalOnDismissed?(presentation, reason)
            link.owner?.handleModalStoreDismissal(presentation: presentation, reason: reason)
        }

        let navConfig = NavigationStoreConfiguration<R>(
            engine: configuration.navigation.engine,
            middlewares: configuration.navigation.middlewares,
            routeStackValidator: configuration.navigation.routeStackValidator,
            pathMismatchPolicy: configuration.navigation.pathMismatchPolicy,
            logger: configuration.navigation.logger,
            onChange: composedNavOnChange,
            onBatchExecuted: configuration.navigation.onBatchExecuted,
            onTransactionExecuted: configuration.navigation.onTransactionExecuted,
            onMiddlewareMutation: configuration.navigation.onMiddlewareMutation
        )

        let modalConfig = ModalStoreConfiguration<R>(
            logger: configuration.modal.logger,
            middlewares: configuration.modal.middlewares,
            onPresented: configuration.modal.onPresented,
            onDismissed: composedModalOnDismissed,
            onQueueChanged: configuration.modal.onQueueChanged,
            onMiddlewareMutation: configuration.modal.onMiddlewareMutation,
            onCommandIntercepted: configuration.modal.onCommandIntercepted
        )

        let (pushRoutes, modalTail) = Self.decompose(validatedInitial)
        let initialStack = RouteStack<R>(path: pushRoutes)
        let modalPresentation = modalTail.map { Self.presentation(for: $0) }

        self.navigationStore = NavigationStore(
            initial: initialStack,
            configuration: navConfig
        )
        self.modalStore = ModalStore(
            currentPresentation: modalPresentation,
            configuration: modalConfig
        )
        self.path = validatedInitial
        self.onPathChanged = configuration.onPathChanged
        self.onIntentRejected = configuration.onIntentRejected
        self.link = link
        self.link.owner = self
    }

    // MARK: - Public API

    /// Dispatches a `FlowIntent`, delegating to inner stores after validating
    /// the request against FlowStore invariants.
    public func send(_ intent: FlowIntent<R>) {
        switch intent {
        case .push(let route):
            dispatchPush(route, intent: intent)
        case .presentSheet(let route):
            dispatchModal(route, step: .sheet(route), intent: intent)
        case .presentCover(let route):
            dispatchModal(route, step: .cover(route), intent: intent)
        case .pop:
            dispatchPop(intent: intent)
        case .dismiss:
            dispatchDismiss(intent: intent)
        case .reset(let steps):
            dispatchReset(steps, intent: intent)
        }
    }

    /// Applies a `FlowPlan` to the store, replacing the current path in one
    /// coordinated mutation. Equivalent to `send(.reset(plan.steps))` but
    /// communicates intent at the API boundary.
    public func apply(_ plan: FlowPlan<R>) {
        send(.reset(plan.steps))
    }

    // MARK: - Dispatch

    private func dispatchPush(_ route: R, intent: FlowIntent<R>) {
        if let last = path.last, last.isModal {
            onIntentRejected?(intent, .pushBlockedByModalTail)
            return
        }

        let pathBefore = path
        let newStep = RouteStep<R>.push(route)
        path.append(newStep)

        let result = withInternalMutation {
            navigationStore.execute(.push(route))
        }

        if case .cancelled(let reason) = result {
            path = pathBefore
            onIntentRejected?(intent, .middlewareRejected(debugName: Self.debugName(from: reason)))
            return
        }

        emitPathChangedIfNeeded(from: pathBefore)
    }

    private func dispatchModal(_ route: R, step: RouteStep<R>, intent: FlowIntent<R>) {
        // A modal tail already exists: queue-behaviour is delegated to ModalStore.
        // The path reflects only the visible tail, so only update when this is
        // the first modal step.
        let pathBefore = path
        let appending = path.last?.isModal != true

        if appending {
            path.append(step)
        }

        let presentation = Self.presentation(for: step)
        let result = withInternalMutation {
            modalStore.execute(.present(presentation))
        }

        switch result {
        case .executed, .queued:
            emitPathChangedIfNeeded(from: pathBefore)
        case .cancelled(let reason):
            path = pathBefore
            onIntentRejected?(intent, .middlewareRejected(debugName: Self.debugName(from: reason)))
        case .noop:
            emitPathChangedIfNeeded(from: pathBefore)
        }
    }

    private func dispatchPop(intent: FlowIntent<R>) {
        guard !path.isEmpty else { return }
        // If the tail is a modal, `.pop` targets push steps only — no-op.
        if path.last?.isModal == true { return }

        let pathBefore = path
        path.removeLast()

        let result = withInternalMutation {
            navigationStore.execute(.pop)
        }

        if case .cancelled(let reason) = result {
            path = pathBefore
            onIntentRejected?(intent, .middlewareRejected(debugName: Self.debugName(from: reason)))
            return
        }

        emitPathChangedIfNeeded(from: pathBefore)
    }

    private func dispatchDismiss(intent: FlowIntent<R>) {
        guard let last = path.last, last.isModal else { return }

        let pathBefore = path
        path.removeLast()

        let result = withInternalMutation {
            modalStore.execute(.dismissCurrent(reason: .dismiss))
        }

        switch result {
        case .executed, .noop:
            emitPathChangedIfNeeded(from: pathBefore)
        case .cancelled(let reason):
            path = pathBefore
            onIntentRejected?(intent, .middlewareRejected(debugName: Self.debugName(from: reason)))
        case .queued:
            // Dismiss commands never produce `.queued`.
            emitPathChangedIfNeeded(from: pathBefore)
        }
    }

    private func dispatchReset(_ steps: [RouteStep<R>], intent: FlowIntent<R>) {
        guard Self.isValidPath(steps) else {
            onIntentRejected?(intent, .invalidResetPath)
            return
        }

        let pathBefore = path
        let (pushRoutes, modalTail) = Self.decompose(steps)

        path = steps

        // Replace navigation prefix.
        let navResult = withInternalMutation {
            navigationStore.execute(.replace(pushRoutes))
        }

        if case .cancelled(let reason) = navResult {
            path = pathBefore
            onIntentRejected?(intent, .middlewareRejected(debugName: Self.debugName(from: reason)))
            return
        }

        // Reconcile modal tail.
        if let modalTail {
            let presentation = Self.presentation(for: modalTail)
            // If there is already an active modal and the new tail differs,
            // dismiss first to avoid stacking presentations.
            if modalStore.currentPresentation?.route != modalTail.route
                || modalStore.currentPresentation?.style != modalTail.modalStyle {
                if modalStore.currentPresentation != nil {
                    _ = withInternalMutation {
                        modalStore.execute(.dismissAll)
                    }
                }
                let modalResult = withInternalMutation {
                    modalStore.execute(.present(presentation))
                }
                if case .cancelled(let reason) = modalResult {
                    path = pathBefore
                    onIntentRejected?(intent, .middlewareRejected(debugName: Self.debugName(from: reason)))
                    return
                }
            }
        } else if modalStore.currentPresentation != nil || !modalStore.queuedPresentations.isEmpty {
            _ = withInternalMutation {
                modalStore.execute(.dismissAll)
            }
        }

        emitPathChangedIfNeeded(from: pathBefore)
    }

    // MARK: - Reverse sync

    private func handleNavigationStoreChange(
        from oldStack: RouteStack<R>,
        to newStack: RouteStack<R>
    ) {
        guard !isApplyingInternalMutation else { return }
        // External / system-driven change (e.g. SwiftUI swipe-back) — reconcile
        // `path`'s push prefix to match the new navigation path, preserving
        // any modal tail.
        reconcilePushPrefix(with: newStack.path)
    }

    private func handleModalStoreDismissal(
        presentation: ModalPresentation<R>,
        reason: ModalDismissalReason
    ) {
        guard !isApplyingInternalMutation else { return }
        guard reason == .systemDismiss else { return }
        // SwiftUI-driven modal dismissal (e.g. sheet swipe-down) — drop the
        // modal tail from the flow path if it still matches.
        guard let last = path.last, last.isModal, last.route == presentation.route else { return }

        let pathBefore = path
        path.removeLast()
        emitPathChangedIfNeeded(from: pathBefore)
    }

    private func reconcilePushPrefix(with newPushRoutes: [R]) {
        let pathBefore = path
        let (currentPushes, modalTail) = Self.decompose(path)

        guard currentPushes != newPushRoutes else { return }

        var newPath: [RouteStep<R>] = newPushRoutes.map { .push($0) }
        if let modalTail {
            newPath.append(modalTail)
        }
        path = newPath
        emitPathChangedIfNeeded(from: pathBefore)
    }

    // MARK: - Helpers

    private func emitPathChangedIfNeeded(from oldPath: [RouteStep<R>]) {
        guard oldPath != path else { return }
        onPathChanged?(oldPath, path)
    }

    private func withInternalMutation<T>(_ body: () -> T) -> T {
        let wasApplying = isApplyingInternalMutation
        isApplyingInternalMutation = true
        defer { isApplyingInternalMutation = wasApplying }
        return body()
    }

    private static func validatedInitial(_ steps: [RouteStep<R>]) -> [RouteStep<R>] {
        isValidPath(steps) ? steps : []
    }

    private static func isValidPath(_ steps: [RouteStep<R>]) -> Bool {
        let modalIndices = steps.enumerated().filter { $0.element.isModal }.map(\.offset)
        if modalIndices.isEmpty { return true }
        if modalIndices.count > 1 { return false }
        return modalIndices.first == steps.count - 1
    }

    private static func decompose(
        _ steps: [RouteStep<R>]
    ) -> (pushRoutes: [R], modalTail: RouteStep<R>?) {
        guard let last = steps.last, last.isModal else {
            return (steps.map(\.route), nil)
        }
        return (steps.dropLast().map(\.route), last)
    }

    private static func presentation(for step: RouteStep<R>) -> ModalPresentation<R> {
        guard let style = step.modalStyle else {
            preconditionFailure("Cannot build ModalPresentation from non-modal step \(step)")
        }
        return ModalPresentation(route: step.route, style: style)
    }

    private static func debugName(from reason: NavigationCancellationReason<R>) -> String? {
        switch reason {
        case .middleware(let debugName, _): return debugName
        case .conditionFailed: return nil
        case .custom: return nil
        }
    }

    private static func debugName(from reason: ModalCancellationReason<R>) -> String? {
        switch reason {
        case .middleware(let debugName, _): return debugName
        case .conditionFailed: return nil
        case .custom: return nil
        }
    }

    private static func debugName(from result: NavigationResult<R>) -> String? {
        guard case .cancelled(let reason) = result else { return nil }
        return debugName(from: reason)
    }
}

@MainActor
private final class FlowStoreLink<R: Route> {
    weak var owner: FlowStore<R>?
}
