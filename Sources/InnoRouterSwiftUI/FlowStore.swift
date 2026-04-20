import Observation

import InnoRouterCore

/// Unified router store that represents push + modal progression as a single
/// array of `RouteStep`s, delegating execution to an inner `NavigationStore`
/// and `ModalStore`.
///
/// `FlowStore` projects the committed navigation + modal state owned by its
/// inner stores into a single array of `RouteStep`s. Consumers dispatch
/// `FlowIntent` values via `send(_:)` or describe the full end state with
/// `FlowPlan` via `apply(_:)`.
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
/// 4. `path` is rebuilt from committed inner state after each successful
///    mutation, so middleware rewrites are reflected in the projection.
/// 5. Middleware cancellations from the inner navigation / modal store
///    leave the committed state untouched and emit
///    `.middlewareRejected(debugName:)`.
@Observable
@MainActor
public final class FlowStore<R: Route> {
    /// Canonical projection of the committed navigation prefix and visible
    /// modal tail owned by the inner stores.
    public private(set) var path: [RouteStep<R>]

    /// Inner navigation store that owns stack state for `.push` steps.
    public let navigationStore: NavigationStore<R>

    /// Inner modal store that owns presentation state for the tail modal step.
    public let modalStore: ModalStore<R>

    private let onPathChanged: (@MainActor @Sendable ([RouteStep<R>], [RouteStep<R>]) -> Void)?
    private let onIntentRejected: (@MainActor @Sendable (FlowIntent<R>, FlowRejectionReason) -> Void)?
    private let link: FlowStoreLink<R>
    private let broadcaster: EventBroadcaster<FlowEvent<R>>
    private var innerNavigationEventsTask: Task<Void, Never>?
    private var innerModalEventsTask: Task<Void, Never>?

    // Bookkeeping toggled while FlowStore drives its own inner stores, so
    // observer callbacks can distinguish user / system-initiated changes.
    private var isApplyingInternalMutation: Bool = false

    /// A multicast `AsyncStream` that emits every observation event the
    /// flow store and its inner navigation / modal stores produce —
    /// `.pathChanged` and `.intentRejected` from the flow level, plus
    /// `.navigation(...)` and `.modal(...)` wrappers around the inner
    /// stores' events — in the same order as the matching callbacks
    /// fire.
    ///
    /// This lets a single subscriber assert the complete chain
    /// triggered by one `FlowIntent` (including middleware
    /// cancellation paths) without wiring the ten individual
    /// navigation + modal + flow callbacks.
    public var events: AsyncStream<FlowEvent<R>> {
        broadcaster.stream()
    }

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
        let userModalOnPresented = configuration.modal.onPresented
        let userModalOnDismissed = configuration.modal.onDismissed

        let composedNavOnChange: @MainActor @Sendable (RouteStack<R>, RouteStack<R>) -> Void = { old, new in
            userNavOnChange?(old, new)
            link.owner?.handleNavigationStoreChange(from: old, to: new)
        }
        let composedModalOnPresented: @MainActor @Sendable (ModalPresentation<R>) -> Void = { presentation in
            userModalOnPresented?(presentation)
            link.owner?.handleModalStorePresentation(presentation)
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
            onMiddlewareMutation: configuration.navigation.onMiddlewareMutation,
            onPathMismatch: configuration.navigation.onPathMismatch
        )

        let modalConfig = ModalStoreConfiguration<R>(
            logger: configuration.modal.logger,
            middlewares: configuration.modal.middlewares,
            onPresented: composedModalOnPresented,
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
        self.path = FlowProjection(
            pushRoutes: self.navigationStore.state.path,
            currentPresentation: self.modalStore.currentPresentation,
            queuedPresentations: self.modalStore.queuedPresentations
        ).path
        self.onPathChanged = configuration.onPathChanged
        self.onIntentRejected = configuration.onIntentRejected
        self.link = link
        let broadcaster = EventBroadcaster<FlowEvent<R>>()
        self.broadcaster = broadcaster
        self.link.owner = self

        // Pipe the inner stores' unified event streams into our own
        // broadcaster so a single FlowStore.events subscriber can
        // observe the full chain.
        let navStream = self.navigationStore.events
        let modalStream = self.modalStore.events
        self.innerNavigationEventsTask = Task { [weak self] in
            for await event in navStream {
                self?.broadcaster.broadcast(.navigation(event))
            }
        }
        self.innerModalEventsTask = Task { [weak self] in
            for await event in modalStream {
                self?.broadcaster.broadcast(.modal(event))
            }
        }
    }

    isolated deinit {
        innerNavigationEventsTask?.cancel()
        innerModalEventsTask?.cancel()
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
        if currentProjection.currentPresentation != nil {
            emitIntentRejected(intent, reason: .pushBlockedByModalTail)
            return
        }

        let pathBefore = path
        let preview = navigationStore.previewFlowCommand(.push(route))
        if !preview.result.isSuccess {
            if case .cancelled(let reason) = preview.result {
                emitIntentRejected(intent, reason: .middlewareRejected(debugName: Self.debugName(from: reason)))
            }
            return
        }

        withInternalMutation {
            _ = navigationStore.commitFlowPreview(preview)
        }

        syncPathFromStores(from: pathBefore)
    }

    private func dispatchModal(_ route: R, step: RouteStep<R>, intent: FlowIntent<R>) {
        let pathBefore = path
        let preview = modalStore.previewFlowCommand(.present(Self.presentation(for: step)))

        if case .cancelled(let reason) = preview.result {
            emitIntentRejected(intent, reason: .middlewareRejected(debugName: Self.debugName(from: reason)))
            return
        }

        withInternalMutation {
            _ = modalStore.commitFlowPreview(preview)
        }

        syncPathFromStores(from: pathBefore)
    }

    private func dispatchPop(intent: FlowIntent<R>) {
        guard !navigationStore.state.path.isEmpty else { return }
        guard currentProjection.currentPresentation == nil else { return }

        let pathBefore = path
        let preview = navigationStore.previewFlowCommand(.pop)
        if !preview.result.isSuccess {
            if case .cancelled(let reason) = preview.result {
                emitIntentRejected(intent, reason: .middlewareRejected(debugName: Self.debugName(from: reason)))
            }
            return
        }

        withInternalMutation {
            _ = navigationStore.commitFlowPreview(preview)
        }

        syncPathFromStores(from: pathBefore)
    }

    private func dispatchDismiss(intent: FlowIntent<R>) {
        guard currentProjection.currentPresentation != nil else { return }
        let pathBefore = path
        let preview = modalStore.previewFlowCommand(.dismissCurrent(reason: .dismiss))
        if case .cancelled(let reason) = preview.result {
            emitIntentRejected(intent, reason: .middlewareRejected(debugName: Self.debugName(from: reason)))
            return
        }

        withInternalMutation {
            _ = modalStore.commitFlowPreview(preview)
        }

        syncPathFromStores(from: pathBefore)
    }

    private func dispatchReset(_ steps: [RouteStep<R>], intent: FlowIntent<R>) {
        guard Self.isValidPath(steps) else {
            emitIntentRejected(intent, reason: .invalidResetPath)
            return
        }

        let pathBefore = path
        let (pushRoutes, modalTail) = Self.decompose(steps)

        let navPreview = navigationStore.previewFlowCommand(.replace(pushRoutes))
        if !navPreview.result.isSuccess {
            if case .cancelled(let reason) = navPreview.result {
                emitIntentRejected(intent, reason: .middlewareRejected(debugName: Self.debugName(from: reason)))
            }
            return
        }

        let modalPlan = previewModalReset(to: modalTail)
        switch modalPlan {
        case .rejected(let reason):
            emitIntentRejected(intent, reason: .middlewareRejected(debugName: Self.debugName(from: reason)))
            return
        case .commit(let modalPreviews):
            withInternalMutation {
                _ = navigationStore.commitFlowPreview(navPreview)
                modalStore.commitFlowPreviews(modalPreviews)
            }
        }

        syncPathFromStores(from: pathBefore)
    }

    // MARK: - Reverse sync

    private func handleNavigationStoreChange(
        from oldStack: RouteStack<R>,
        to newStack: RouteStack<R>
    ) {
        guard !isApplyingInternalMutation else { return }
        syncPath(
            from: path,
            projection: FlowProjection(
                pushRoutes: newStack.path,
                currentPresentation: modalStore.currentPresentation,
                queuedPresentations: modalStore.queuedPresentations
            )
        )
    }

    private func handleModalStoreDismissal(
        presentation: ModalPresentation<R>,
        reason: ModalDismissalReason
    ) {
        guard !isApplyingInternalMutation else { return }
        syncPathFromStores(from: path)
    }

    private func handleModalStorePresentation(_ presentation: ModalPresentation<R>) {
        guard !isApplyingInternalMutation else { return }
        syncPathFromStores(from: path)
    }

    // MARK: - Helpers

    private func emitPathChangedIfNeeded(from oldPath: [RouteStep<R>]) {
        guard oldPath != path else { return }
        onPathChanged?(oldPath, path)
        broadcaster.broadcast(.pathChanged(old: oldPath, new: path))
    }

    private func emitIntentRejected(_ intent: FlowIntent<R>, reason: FlowRejectionReason) {
        onIntentRejected?(intent, reason)
        broadcaster.broadcast(.intentRejected(intent, reason))
    }

    private func withInternalMutation<T>(_ body: () -> T) -> T {
        let wasApplying = isApplyingInternalMutation
        isApplyingInternalMutation = true
        defer { isApplyingInternalMutation = wasApplying }
        return body()
    }

    private var currentProjection: FlowProjection {
        FlowProjection(
            pushRoutes: navigationStore.state.path,
            currentPresentation: modalStore.currentPresentation,
            queuedPresentations: modalStore.queuedPresentations
        )
    }

    private func syncPathFromStores(from oldPath: [RouteStep<R>]) {
        syncPath(from: oldPath, projection: currentProjection)
    }

    private func syncPath(
        from oldPath: [RouteStep<R>],
        projection: FlowProjection
    ) {
        path = projection.path
        emitPathChangedIfNeeded(from: oldPath)
    }

    private func previewModalReset(to modalTail: RouteStep<R>?) -> ModalPreviewPlan {
        let targetPresentation = modalTail.map(Self.presentation(for:))
        let currentSnapshot = modalStore.flowStateSnapshot

        if currentSnapshot.currentPresentation == targetPresentation,
            currentSnapshot.queuedPresentations.isEmpty {
            return .commit([])
        }

        var previews: [ModalStore<R>.FlowCommandPreview] = []
        var shadow = currentSnapshot

        if shadow.currentPresentation != nil || !shadow.queuedPresentations.isEmpty {
            let dismissPreview = modalStore.previewFlowCommand(.dismissAll, from: shadow)
            if case .cancelled(let reason) = dismissPreview.result {
                return .rejected(reason)
            }
            previews.append(dismissPreview)
            shadow = dismissPreview.stateAfter
        }

        if let targetPresentation {
            let presentPreview = modalStore.previewFlowCommand(.present(targetPresentation), from: shadow)
            if case .cancelled(let reason) = presentPreview.result {
                return .rejected(reason)
            }
            previews.append(presentPreview)
        }

        return .commit(previews)
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

    nonisolated private static func step(for presentation: ModalPresentation<R>) -> RouteStep<R> {
        switch presentation.style {
        case .sheet:
            return .sheet(presentation.route)
        case .fullScreenCover:
            return .cover(presentation.route)
        }
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

    private struct FlowProjection {
        let pushRoutes: [R]
        let currentPresentation: ModalPresentation<R>?
        let queuedPresentations: [ModalPresentation<R>]

        var path: [RouteStep<R>] {
            var projectedPath = pushRoutes.map(RouteStep.push)
            if let currentPresentation {
                projectedPath.append(FlowStore.step(for: currentPresentation))
            }
            return projectedPath
        }
    }

    private enum ModalPreviewPlan {
        case commit([ModalStore<R>.FlowCommandPreview])
        case rejected(ModalCancellationReason<R>)
    }
}

@MainActor
private final class FlowStoreLink<R: Route> {
    weak var owner: FlowStore<R>?
}
