import OSLog
import Observation
import SwiftUI

@_spi(InternalTrace) import InnoRouterCore

/// View-layer intent dispatched to ``ModalStore/send(_:)``.
///
/// Conformance to `Sendable` is **unconditional** because every ``Route`` is
/// required to be `Sendable`. Callers can therefore freely move `ModalIntent`
/// values across actor boundaries without additional `where M: Sendable`
/// constraints.
public enum ModalIntent<M: Route>: Sendable, Equatable {
    case present(M, style: ModalPresentationStyle)
    case dismiss
    case dismissAll
}

@Observable
@MainActor
public final class ModalStore<M: Route> {
    public private(set) var currentPresentation: ModalPresentation<M>?
    public private(set) var queuedPresentations: [ModalPresentation<M>] = []
    private let onPresented: (@MainActor @Sendable (ModalPresentation<M>) -> Void)?
    private let onDismissed: (@MainActor @Sendable (ModalPresentation<M>, ModalDismissalReason) -> Void)?
    private let onQueueChanged: (@MainActor @Sendable ([ModalPresentation<M>], [ModalPresentation<M>]) -> Void)?
    private let onCommandIntercepted: (@MainActor @Sendable (ModalCommand<M>, ModalExecutionResult<M>) -> Void)?
    private let telemetrySink: ModalStoreTelemetrySink<M>
    private let middlewareRegistry: ModalMiddlewareRegistry<M>
    private let broadcaster: EventBroadcaster<ModalEvent<M>>
    private let traceLogger: Logger?
    private var traceRecorder: InternalExecutionTraceRecorder?
    /// Memoised forwarding closure that fans out trace records to both
    /// the externally-installed recorder (if any) and the internal
    /// `Logger`. Recomputed only when `installTraceRecorder(_:)` flips
    /// the underlying recorder so we don't allocate a new closure on
    /// every command execution.
    private var cachedEffectiveTraceRecorder: InternalExecutionTraceRecorder?
    /// Cached intent dispatcher that lives for the lifetime of this store.
    /// Built on first access by ``intentDispatcher`` so SwiftUI hosts do
    /// not allocate a fresh closure on every render.
    @ObservationIgnored
    private var cachedIntentDispatcher: AnyModalIntentDispatcher<M>?

    /// A type-erased dispatcher that forwards `ModalIntent` values to this
    /// store's ``send(_:)`` entry point.
    ///
    /// Hosts publish this through the SwiftUI environment so descendants can
    /// use ``EnvironmentModalIntent`` to dispatch view-layer intents without
    /// holding a direct store reference. The dispatcher is created on first
    /// access and reused for the lifetime of the store, so a SwiftUI host
    /// does not allocate a fresh closure on every render.
    public var intentDispatcher: AnyModalIntentDispatcher<M> {
        if let cachedIntentDispatcher {
            return cachedIntentDispatcher
        }
        let dispatcher = AnyModalIntentDispatcher<M> { [weak self] intent in
            self?.send(intent)
        }
        cachedIntentDispatcher = dispatcher
        return dispatcher
    }

    public var middlewareHandles: [ModalMiddlewareHandle] {
        middlewareRegistry.handles
    }

    public var middlewareMetadata: [ModalMiddlewareMetadata] {
        middlewareRegistry.metadata
    }

    /// A multicast `AsyncStream` that emits every observation event the
    /// modal store produces — presentations, dismissals, queue changes,
    /// command interceptions, and middleware registry mutations — in
    /// the same order as the matching `onPresented` / `onDismissed` /
    /// `onQueueChanged` / `onCommandIntercepted` /
    /// `onMiddlewareMutation` callbacks fire.
    ///
    /// Each call to `events` returns a fresh stream with its own
    /// continuation; multiple subscribers see every event
    /// independently. Subscriber teardown (cancelled `for await` loop
    /// or store deallocation) cleans up the associated continuation.
    public var events: AsyncStream<ModalEvent<M>> {
        broadcaster.stream()
    }

    public init(
        currentPresentation: ModalPresentation<M>? = nil,
        queuedPresentations: [ModalPresentation<M>] = [],
        configuration: ModalStoreConfiguration<M> = .init()
    ) {
        let normalizedState = Self.normalize(
            currentPresentation: currentPresentation,
            queuedPresentations: queuedPresentations
        )
        let broadcaster = EventBroadcaster<ModalEvent<M>>(
            bufferingPolicy: configuration.eventBufferingPolicy
        )
        let publicRecorder = Self.makePublicTelemetryRecorder(
            onMiddlewareMutation: configuration.onMiddlewareMutation
        )
        let broadcastRecorder = Self.makeBroadcastRecorder(broadcaster: broadcaster)
        let telemetrySink = ModalStoreTelemetrySink<M>(
            logger: configuration.logger,
            recorder: Self.combineRecorders(publicRecorder, broadcastRecorder)
        )
        let middlewareRegistry = ModalMiddlewareRegistry(
            registrations: configuration.middlewares,
            telemetrySink: telemetrySink
        )
        self.currentPresentation = normalizedState.current
        self.queuedPresentations = normalizedState.queue
        self.onPresented = configuration.onPresented
        self.onDismissed = configuration.onDismissed
        self.onQueueChanged = configuration.onQueueChanged
        self.onCommandIntercepted = configuration.onCommandIntercepted
        self.telemetrySink = telemetrySink
        self.middlewareRegistry = middlewareRegistry
        self.broadcaster = broadcaster
        self.traceLogger = configuration.logger
        self.traceRecorder = nil
        updateEffectiveTraceRecorder()
    }

    init(
        currentPresentation: ModalPresentation<M>? = nil,
        queuedPresentations: [ModalPresentation<M>] = [],
        configuration: ModalStoreConfiguration<M> = .init(),
        telemetryRecorder: ModalStoreTelemetryRecorder<M>? = nil
    ) {
        let normalizedState = Self.normalize(
            currentPresentation: currentPresentation,
            queuedPresentations: queuedPresentations
        )
        let broadcaster = EventBroadcaster<ModalEvent<M>>(
            bufferingPolicy: configuration.eventBufferingPolicy
        )
        let publicRecorder = Self.makePublicTelemetryRecorder(
            onMiddlewareMutation: configuration.onMiddlewareMutation
        )
        let broadcastRecorder = Self.makeBroadcastRecorder(broadcaster: broadcaster)
        let combinedRecorder = Self.combineRecorders(
            Self.combineRecorders(telemetryRecorder, publicRecorder),
            broadcastRecorder
        )
        let telemetrySink = ModalStoreTelemetrySink(
            logger: configuration.logger,
            recorder: combinedRecorder
        )
        let middlewareRegistry = ModalMiddlewareRegistry(
            registrations: configuration.middlewares,
            telemetrySink: telemetrySink
        )
        self.currentPresentation = normalizedState.current
        self.queuedPresentations = normalizedState.queue
        self.onPresented = configuration.onPresented
        self.onDismissed = configuration.onDismissed
        self.onQueueChanged = configuration.onQueueChanged
        self.onCommandIntercepted = configuration.onCommandIntercepted
        self.telemetrySink = telemetrySink
        self.middlewareRegistry = middlewareRegistry
        self.broadcaster = broadcaster
        self.traceLogger = configuration.logger
        self.traceRecorder = nil
        updateEffectiveTraceRecorder()
    }

    // MARK: - Public telemetry adapters

    private static func makePublicTelemetryRecorder(
        onMiddlewareMutation: (@MainActor @Sendable (ModalMiddlewareMutationEvent<M>) -> Void)?
    ) -> ModalStoreTelemetryRecorder<M>? {
        guard let onMiddlewareMutation else { return nil }
        return { @MainActor event in
            switch event {
            case .middlewareMutation(let action, let metadata, let index):
                onMiddlewareMutation(
                    ModalMiddlewareMutationEvent(
                        action: Self.publicAction(for: action),
                        metadata: metadata,
                        index: index
                    )
                )
            case .presented, .dismissed, .queued, .queueChanged, .commandIntercepted:
                break
            }
        }
    }

    private static func makeBroadcastRecorder(
        broadcaster: EventBroadcaster<ModalEvent<M>>
    ) -> ModalStoreTelemetryRecorder<M>? {
        { @MainActor event in
            switch event {
            case .presented(let presentation):
                broadcaster.broadcast(.presented(presentation))
            case .dismissed(let presentation, let reason):
                broadcaster.broadcast(.dismissed(presentation, reason: reason))
            case .queueChanged(let oldQueue, let newQueue):
                broadcaster.broadcast(.queueChanged(old: oldQueue, new: newQueue))
            case .middlewareMutation(let action, let metadata, let index):
                broadcaster.broadcast(
                    .middlewareMutation(
                        ModalMiddlewareMutationEvent(
                            action: Self.publicAction(for: action),
                            metadata: metadata,
                            index: index
                        )
                    )
                )
            case .commandIntercepted(let command, let outcome, let cancellationReason):
                let result = Self.executionResult(
                    for: command,
                    outcome: outcome,
                    cancellationReason: cancellationReason
                )
                broadcaster.broadcast(
                    .commandIntercepted(command: command, result: result)
                )
            case .queued:
                // .queued is an internal side-signal emitted alongside
                // .queueChanged; the public ModalEvent surface folds
                // queueing into queueChanged, so we skip it here.
                break
            }
        }
    }

    private static func executionResult(
        for command: ModalCommand<M>,
        outcome: ModalStoreTelemetryEvent<M>.InterceptionOutcomeKind,
        cancellationReason: ModalCancellationReason<M>?
    ) -> ModalExecutionResult<M> {
        switch outcome {
        case .executed:
            return .executed(command)
        case .queued:
            // .queued is only produced by `.present(presentation)`
            // commands that were deferred behind an active modal.
            if case .present(let presentation) = command {
                return .queued(presentation)
            }
            // Should be unreachable — fall through as .executed so the
            // surface still type-checks.
            return .executed(command)
        case .cancelled:
            return .cancelled(cancellationReason ?? .custom("unknown"))
        case .noop:
            return .noop
        }
    }

    private static func combineRecorders(
        _ primary: ModalStoreTelemetryRecorder<M>?,
        _ secondary: ModalStoreTelemetryRecorder<M>?
    ) -> ModalStoreTelemetryRecorder<M>? {
        switch (primary, secondary) {
        case (nil, nil):
            return nil
        case (let primary?, nil):
            return primary
        case (nil, let secondary?):
            return secondary
        case (let primary?, let secondary?):
            return { event in
                primary(event)
                secondary(event)
            }
        }
    }

    private static func publicAction(
        for action: ModalStoreTelemetryEvent<M>.MiddlewareMutation
    ) -> ModalMiddlewareMutationEvent<M>.Action {
        switch action {
        case .added: return .added
        case .inserted: return .inserted
        case .removed: return .removed
        case .replaced: return .replaced
        case .moved: return .moved
        }
    }

    func installTraceRecorder(_ recorder: InternalExecutionTraceRecorder?) {
        self.traceRecorder = recorder
        updateEffectiveTraceRecorder()
    }

    private func updateEffectiveTraceRecorder() {
        if traceRecorder == nil && traceLogger == nil {
            cachedEffectiveTraceRecorder = nil
            return
        }

        cachedEffectiveTraceRecorder = { [weak self] record in
            self?.traceRecorder?(record)
            self?.logTraceRecord(record)
        }
    }

    private var effectiveTraceRecorder: InternalExecutionTraceRecorder? {
        cachedEffectiveTraceRecorder
    }

    private func logTraceRecord(_ record: InternalExecutionTraceRecord) {
        guard let traceLogger else { return }

        switch record {
        case .start(let context, let operation, let metadata):
            let metadataSummary = metadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ",")
            traceLogger.debug(
                """
                modal trace start \
                root=\(context.rootID, privacy: .public) \
                span=\(context.spanID, privacy: .public) \
                parent=\(context.parentSpanID ?? "nil", privacy: .public) \
                operation=\(operation, privacy: .public) \
                metadata=\(metadataSummary, privacy: .public)
                """
            )

        case .finish(let context, let operation, let outcome):
            traceLogger.debug(
                """
                modal trace finish \
                root=\(context.rootID, privacy: .public) \
                span=\(context.spanID, privacy: .public) \
                parent=\(context.parentSpanID ?? "nil", privacy: .public) \
                operation=\(operation, privacy: .public) \
                outcome=\(outcome, privacy: .public)
                """
            )
        }
    }

    // MARK: - Public middleware API

    @discardableResult
    public func addMiddleware(
        _ middleware: AnyModalMiddleware<M>,
        debugName: String? = nil
    ) -> ModalMiddlewareHandle {
        middlewareRegistry.add(middleware, debugName: debugName)
    }

    @discardableResult
    public func insertMiddleware(
        _ middleware: AnyModalMiddleware<M>,
        at index: Int,
        debugName: String? = nil
    ) -> ModalMiddlewareHandle {
        middlewareRegistry.insert(middleware, at: index, debugName: debugName)
    }

    @discardableResult
    public func removeMiddleware(_ handle: ModalMiddlewareHandle) -> AnyModalMiddleware<M>? {
        middlewareRegistry.remove(handle)
    }

    @discardableResult
    public func replaceMiddleware(
        _ handle: ModalMiddlewareHandle,
        with middleware: AnyModalMiddleware<M>,
        debugName: String? = nil
    ) -> Bool {
        middlewareRegistry.replace(handle, with: middleware, debugName: debugName)
    }

    @discardableResult
    public func moveMiddleware(_ handle: ModalMiddlewareHandle, to index: Int) -> Bool {
        middlewareRegistry.move(handle, to: index)
    }

    // MARK: - Public command API

    public func send(_ intent: ModalIntent<M>) {
        switch intent {
        case .present(let route, let style):
            present(route, style: style)
        case .dismiss:
            dismissCurrent()
        case .dismissAll:
            dismissAll()
        }
    }

    @discardableResult
    public func execute(_ command: ModalCommand<M>) -> ModalExecutionResult<M> {
        InternalExecutionTrace.withSpan(
            domain: .modal,
            operation: "execute",
            recorder: effectiveTraceRecorder,
            metadata: ["command": String(describing: command)]
        ) {
            let outcome = middlewareRegistry.intercept(
                command,
                currentPresentation: currentPresentation,
                queuedPresentations: queuedPresentations
            )

            switch outcome.interception {
            case .cancel(let reason):
                let result: ModalExecutionResult<M> = .cancelled(reason)
                middlewareRegistry.didExecute(
                    outcome.command,
                    currentPresentation: currentPresentation,
                    queuedPresentations: queuedPresentations,
                    participantCount: outcome.participantCount
                )
                telemetrySink.recordCommandIntercepted(
                    command: outcome.command,
                    outcome: .cancelled,
                    cancellationReason: reason
                )
                onCommandIntercepted?(outcome.command, result)
                return result

            case .proceed(let effectiveCommand):
                let result = applyCommand(effectiveCommand)

                middlewareRegistry.didExecute(
                    effectiveCommand,
                    currentPresentation: currentPresentation,
                    queuedPresentations: queuedPresentations,
                    participantCount: outcome.participantCount
                )

                telemetrySink.recordCommandIntercepted(
                    command: effectiveCommand,
                    outcome: Self.outcomeKind(for: result),
                    cancellationReason: nil
                )
                onCommandIntercepted?(effectiveCommand, result)
                return result
            }
        } outcome: { result in
            String(describing: result)
        }
    }

    /// Presents a route and reports whether it became the active modal
    /// immediately or was deferred behind an already-active one.
    ///
    /// The return value is `@discardableResult` — callers that ignore
    /// queued vs shown semantics continue to compile unchanged. Callers
    /// that branch on the outcome can pattern-match the
    /// ``ModalPresentResult`` cases instead of inspecting
    /// ``ModalExecutionResult`` payloads.
    @discardableResult
    public func present(_ route: M, style: ModalPresentationStyle) -> ModalPresentResult<M> {
        let presentation = ModalPresentation(route: route, style: style)
        let result = execute(.present(presentation))
        return Self.presentResult(from: result, requestedID: presentation.id)
    }

    private static func presentResult(
        from result: ModalExecutionResult<M>,
        requestedID: UUID
    ) -> ModalPresentResult<M> {
        switch result {
        case .executed:
            return .shownImmediately(id: requestedID)
        case .queued(let queued):
            return .queuedBehind(id: queued.id)
        case .cancelled(let reason):
            return .cancelled(reason)
        case .noop:
            return .noop
        }
    }

    public func replaceCurrent(_ route: M, style: ModalPresentationStyle) {
        let replacement: ModalPresentation<M>
        if let currentPresentation {
            replacement = ModalPresentation(
                id: currentPresentation.id,
                route: route,
                style: style
            )
        } else {
            replacement = ModalPresentation(route: route, style: style)
        }
        _ = execute(.replaceCurrent(replacement))
    }

    public func dismissCurrent() {
        dismissCurrent(reason: .dismiss)
    }

    func dismissCurrent(reason: ModalDismissalReason) {
        _ = execute(.dismissCurrent(reason: reason))
    }

    public func dismissAll() {
        _ = execute(.dismissAll)
    }

    var flowStateSnapshot: ModalExecutionState<M> {
        Self.makeSnapshot(
            currentPresentation: currentPresentation,
            queuedPresentations: queuedPresentations
        )
    }

    func previewFlowCommand(_ command: ModalCommand<M>) -> ModalExecutionJournal<M> {
        previewFlowCommand(command, from: flowStateSnapshot)
    }

    func previewFlowCommand(
        _ command: ModalCommand<M>,
        from stateBefore: ModalExecutionState<M>
    ) -> ModalExecutionJournal<M> {
        let outcome = middlewareRegistry.intercept(
            command,
            currentPresentation: stateBefore.currentPresentation,
            queuedPresentations: stateBefore.queuedPresentations
        )

        switch outcome.interception {
        case .cancel(let reason):
            return ModalExecutionJournal(
                requestedCommand: command,
                effectiveCommand: outcome.command,
                result: .cancelled(reason),
                participantCount: outcome.participantCount,
                stateBefore: stateBefore,
                stateAfter: stateBefore
            )
        case .proceed(let effectiveCommand):
            let previewOutcome = previewApplyCommand(effectiveCommand, to: stateBefore)
            return ModalExecutionJournal(
                requestedCommand: command,
                effectiveCommand: effectiveCommand,
                result: previewOutcome.result,
                participantCount: outcome.participantCount,
                stateBefore: stateBefore,
                stateAfter: previewOutcome.stateAfter
            )
        }
    }

    @discardableResult
    func commitFlowPreview(_ preview: ModalExecutionJournal<M>) -> ModalExecutionResult<M> {
        InternalExecutionTrace.withSpan(
            domain: .modal,
            operation: "commitFlowPreview",
            recorder: effectiveTraceRecorder,
            metadata: ["command": String(describing: preview.requestedCommand)]
        ) {
            currentPresentation = preview.stateAfter.currentPresentation
            queuedPresentations = preview.stateAfter.queuedPresentations

            emitCommittedEvents(for: preview)

            middlewareRegistry.didExecute(
                preview.effectiveCommand,
                currentPresentation: currentPresentation,
                queuedPresentations: queuedPresentations,
                participantCount: preview.participantCount
            )

            if case .cancelled(let reason) = preview.result {
                telemetrySink.recordCommandIntercepted(
                    command: preview.effectiveCommand,
                    outcome: .cancelled,
                    cancellationReason: reason
                )
            } else {
                telemetrySink.recordCommandIntercepted(
                    command: preview.effectiveCommand,
                    outcome: Self.outcomeKind(for: preview.result),
                    cancellationReason: nil
                )
            }

            onCommandIntercepted?(preview.effectiveCommand, preview.result)
            return preview.result
        } outcome: { result in
            String(describing: result)
        }
    }

    func commitFlowPreviews(_ previews: [ModalExecutionJournal<M>]) {
        for preview in previews {
            _ = commitFlowPreview(preview)
        }
    }

    // MARK: - Command application (post-interception)

    private func applyCommand(_ command: ModalCommand<M>) -> ModalExecutionResult<M> {
        switch command {
        case .present(let presentation):
            return applyPresent(presentation)
        case .replaceCurrent(let presentation):
            return applyReplaceCurrent(presentation)
        case .dismissCurrent(let reason):
            return applyDismissCurrent(reason: reason)
        case .dismissAll:
            return applyDismissAll()
        }
    }

    private func previewApplyCommand(
        _ command: ModalCommand<M>,
        to snapshot: ModalExecutionState<M>
    ) -> (result: ModalExecutionResult<M>, stateAfter: ModalExecutionState<M>) {
        switch command {
        case .present(let presentation):
            return previewPresent(presentation, on: snapshot)
        case .replaceCurrent(let presentation):
            return previewReplaceCurrent(presentation, on: snapshot)
        case .dismissCurrent(let reason):
            return previewDismissCurrent(reason: reason, on: snapshot)
        case .dismissAll:
            return previewDismissAll(on: snapshot)
        }
    }

    private func previewPresent(
        _ presentation: ModalPresentation<M>,
        on snapshot: ModalExecutionState<M>
    ) -> (result: ModalExecutionResult<M>, stateAfter: ModalExecutionState<M>) {
        if snapshot.currentPresentation == nil {
            return (
                .executed(.present(presentation)),
                Self.makeSnapshot(
                    currentPresentation: presentation,
                    queuedPresentations: snapshot.queuedPresentations
                )
            )
        }

        return (
            .queued(presentation),
            Self.makeSnapshot(
                currentPresentation: snapshot.currentPresentation,
                queuedPresentations: snapshot.queuedPresentations + [presentation]
            )
        )
    }

    private func previewDismissCurrent(
        reason: ModalDismissalReason,
        on snapshot: ModalExecutionState<M>
    ) -> (result: ModalExecutionResult<M>, stateAfter: ModalExecutionState<M>) {
        guard snapshot.currentPresentation != nil else {
            return (.noop, snapshot)
        }

        let nextPresentation = snapshot.queuedPresentations.first
        let remainingQueue = nextPresentation == nil
            ? snapshot.queuedPresentations
            : Array(snapshot.queuedPresentations.dropFirst())

        return (
            .executed(.dismissCurrent(reason: reason)),
            Self.makeSnapshot(
                currentPresentation: nextPresentation,
                queuedPresentations: remainingQueue
            )
        )
    }

    private func previewDismissAll(
        on snapshot: ModalExecutionState<M>
    ) -> (result: ModalExecutionResult<M>, stateAfter: ModalExecutionState<M>) {
        guard snapshot.currentPresentation != nil || !snapshot.queuedPresentations.isEmpty else {
            return (.noop, snapshot)
        }

        return (
            .executed(.dismissAll),
            Self.makeSnapshot(currentPresentation: nil, queuedPresentations: [])
        )
    }

    private func previewReplaceCurrent(
        _ presentation: ModalPresentation<M>,
        on snapshot: ModalExecutionState<M>
    ) -> (result: ModalExecutionResult<M>, stateAfter: ModalExecutionState<M>) {
        guard let currentPresentation = snapshot.currentPresentation else {
            return (.noop, snapshot)
        }

        guard currentPresentation != presentation else {
            return (.noop, snapshot)
        }

        return (
            .executed(.replaceCurrent(presentation)),
            Self.makeSnapshot(
                currentPresentation: presentation,
                queuedPresentations: snapshot.queuedPresentations
            )
        )
    }

    private func applyPresent(_ presentation: ModalPresentation<M>) -> ModalExecutionResult<M> {
        if currentPresentation == nil {
            currentPresentation = presentation
            telemetrySink.recordPresented(presentation)
            onPresented?(presentation)
            return .executed(.present(presentation))
        } else {
            let oldQueue = queuedPresentations
            queuedPresentations.append(presentation)
            telemetrySink.recordQueued(presentation)
            telemetrySink.recordQueueChanged(oldQueue: oldQueue, newQueue: queuedPresentations)
            onQueueChanged?(oldQueue, queuedPresentations)
            return .queued(presentation)
        }
    }

    private func applyReplaceCurrent(_ presentation: ModalPresentation<M>) -> ModalExecutionResult<M> {
        guard let currentPresentation else {
            return .noop
        }

        guard currentPresentation != presentation else {
            return .noop
        }

        self.currentPresentation = presentation
        return .executed(.replaceCurrent(presentation))
    }

    private func applyDismissCurrent(reason: ModalDismissalReason) -> ModalExecutionResult<M> {
        guard let dismissedPresentation = currentPresentation else {
            return .noop
        }
        currentPresentation = nil
        telemetrySink.recordDismissed(dismissedPresentation, reason: reason)
        onDismissed?(dismissedPresentation, reason)
        promoteNextPresentationIfNeeded()
        return .executed(.dismissCurrent(reason: reason))
    }

    private func applyDismissAll() -> ModalExecutionResult<M> {
        let dismissedPresentation = currentPresentation
        let oldQueue = queuedPresentations
        if dismissedPresentation == nil && oldQueue.isEmpty {
            return .noop
        }
        currentPresentation = nil
        queuedPresentations.removeAll()
        if oldQueue != queuedPresentations {
            telemetrySink.recordQueueChanged(oldQueue: oldQueue, newQueue: queuedPresentations)
            onQueueChanged?(oldQueue, queuedPresentations)
        }
        if let dismissedPresentation {
            telemetrySink.recordDismissed(dismissedPresentation, reason: .dismissAll)
            onDismissed?(dismissedPresentation, .dismissAll)
        }
        return .executed(.dismissAll)
    }

    func binding(for style: ModalPresentationStyle) -> Binding<ModalPresentation<M>?> {
        binding(for: [style])
    }

    func binding(for styles: Set<ModalPresentationStyle>) -> Binding<ModalPresentation<M>?> {
        Binding(
            get: { [self] in
                guard let currentPresentation, styles.contains(currentPresentation.style) else { return nil }
                return currentPresentation
            },
            set: { [self] newValue in
                guard newValue == nil else { return }
                self.dismissCurrent(reason: .systemDismiss)
            }
        )
    }

    /// A binding that reflects the current presentation when it matches the
    /// given case and presentation style.
    ///
    /// Writing a non-nil value presents the embedded route through the regular command
    /// pipeline with the supplied style, so middleware and telemetry observe the
    /// presentation. When the active presentation already matches the same case
    /// and style, the binding replaces it in place rather than queueing a
    /// duplicate presentation. Writing `nil` dismisses the current presentation
    /// only when both the case and style match.
    public func binding<Value>(
        case casePath: CasePath<M, Value>,
        style: ModalPresentationStyle = .sheet
    ) -> Binding<Value?> {
        Binding(
            get: { [weak self] in
                guard let presentation = self?.currentPresentation,
                      presentation.style == style else { return nil }
                return casePath.extract(presentation.route)
            },
            set: { [weak self] newValue in
                guard let self else { return }
                if let value = newValue {
                    let route = casePath.embed(value)
                    if let currentPresentation = self.currentPresentation,
                       currentPresentation.style == style,
                       casePath.extract(currentPresentation.route) != nil {
                        let replacement = ModalPresentation(
                            id: currentPresentation.id,
                            route: route,
                            style: style
                        )
                        guard replacement != currentPresentation else { return }
                        _ = self.execute(.replaceCurrent(replacement))
                    } else {
                        self.present(route, style: style)
                    }
                } else if let currentPresentation = self.currentPresentation,
                          currentPresentation.style == style,
                          casePath.extract(currentPresentation.route) != nil {
                    self.dismissCurrent(reason: .systemDismiss)
                }
            }
        )
    }

    private func promoteNextPresentationIfNeeded() {
        guard currentPresentation == nil, !queuedPresentations.isEmpty else { return }
        let oldQueue = queuedPresentations
        let promotedPresentation = queuedPresentations.removeFirst()
        currentPresentation = promotedPresentation
        telemetrySink.recordQueueChanged(oldQueue: oldQueue, newQueue: queuedPresentations)
        onQueueChanged?(oldQueue, queuedPresentations)
        telemetrySink.recordPresented(promotedPresentation)
        onPresented?(promotedPresentation)
    }

    private func emitCommittedEvents(for preview: ModalExecutionJournal<M>) {
        switch preview.result {
        case .executed(.present(let presentation)):
            telemetrySink.recordPresented(presentation)
            onPresented?(presentation)

        case .executed(.replaceCurrent):
            break

        case .executed(.dismissCurrent(let reason)):
            guard let dismissedPresentation = preview.stateBefore.currentPresentation else { return }
            telemetrySink.recordDismissed(dismissedPresentation, reason: reason)
            onDismissed?(dismissedPresentation, reason)

            if preview.stateBefore.queuedPresentations != preview.stateAfter.queuedPresentations {
                telemetrySink.recordQueueChanged(
                    oldQueue: preview.stateBefore.queuedPresentations,
                    newQueue: preview.stateAfter.queuedPresentations
                )
                onQueueChanged?(preview.stateBefore.queuedPresentations, preview.stateAfter.queuedPresentations)
            }

            if let promotedPresentation = preview.stateAfter.currentPresentation {
                telemetrySink.recordPresented(promotedPresentation)
                onPresented?(promotedPresentation)
            }

        case .executed(.dismissAll):
            if preview.stateBefore.queuedPresentations != preview.stateAfter.queuedPresentations {
                telemetrySink.recordQueueChanged(
                    oldQueue: preview.stateBefore.queuedPresentations,
                    newQueue: preview.stateAfter.queuedPresentations
                )
                onQueueChanged?(preview.stateBefore.queuedPresentations, preview.stateAfter.queuedPresentations)
            }

            if let dismissedPresentation = preview.stateBefore.currentPresentation {
                telemetrySink.recordDismissed(dismissedPresentation, reason: .dismissAll)
                onDismissed?(dismissedPresentation, .dismissAll)
            }

        case .queued(let presentation):
            telemetrySink.recordQueued(presentation)
            telemetrySink.recordQueueChanged(
                oldQueue: preview.stateBefore.queuedPresentations,
                newQueue: preview.stateAfter.queuedPresentations
            )
            onQueueChanged?(preview.stateBefore.queuedPresentations, preview.stateAfter.queuedPresentations)

        case .cancelled, .noop:
            break
        }
    }

    private static func makeSnapshot(
        currentPresentation: ModalPresentation<M>?,
        queuedPresentations: [ModalPresentation<M>]
    ) -> ModalExecutionState<M> {
        let normalized = normalize(
            currentPresentation: currentPresentation,
            queuedPresentations: queuedPresentations
        )
        return ModalExecutionState(
            currentPresentation: normalized.current,
            queuedPresentations: normalized.queue
        )
    }

    private static func outcomeKind(
        for result: ModalExecutionResult<M>
    ) -> ModalStoreTelemetryEvent<M>.InterceptionOutcomeKind {
        switch result {
        case .executed: return .executed
        case .queued: return .queued
        case .cancelled: return .cancelled
        case .noop: return .noop
        }
    }

    private static func normalize(
        currentPresentation: ModalPresentation<M>?,
        queuedPresentations: [ModalPresentation<M>]
    ) -> (current: ModalPresentation<M>?, queue: [ModalPresentation<M>]) {
        guard currentPresentation == nil, let firstQueued = queuedPresentations.first else {
            return (currentPresentation, queuedPresentations)
        }

        return (firstQueued, Array(queuedPresentations.dropFirst()))
    }
}
