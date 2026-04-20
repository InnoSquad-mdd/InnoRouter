import Observation
import SwiftUI

import InnoRouterCore

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

    public var middlewareHandles: [ModalMiddlewareHandle] {
        middlewareRegistry.handles
    }

    public var middlewareMetadata: [ModalMiddlewareMetadata] {
        middlewareRegistry.metadata
    }

    struct ModalStateSnapshot: Equatable {
        let currentPresentation: ModalPresentation<M>?
        let queuedPresentations: [ModalPresentation<M>]
    }

    struct FlowCommandPreview {
        let requestedCommand: ModalCommand<M>
        let effectiveCommand: ModalCommand<M>
        let result: ModalExecutionResult<M>
        let participantCount: Int
        let stateBefore: ModalStateSnapshot
        let stateAfter: ModalStateSnapshot
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
        let publicRecorder = Self.makePublicTelemetryRecorder(
            onMiddlewareMutation: configuration.onMiddlewareMutation
        )
        let telemetrySink = ModalStoreTelemetrySink<M>(
            logger: configuration.logger,
            recorder: publicRecorder
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
        let publicRecorder = Self.makePublicTelemetryRecorder(
            onMiddlewareMutation: configuration.onMiddlewareMutation
        )
        let combinedRecorder = Self.combineRecorders(telemetryRecorder, publicRecorder)
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
    }

    public func present(_ route: M, style: ModalPresentationStyle) {
        let presentation = ModalPresentation(route: route, style: style)
        _ = execute(.present(presentation))
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

    var flowStateSnapshot: ModalStateSnapshot {
        Self.makeSnapshot(
            currentPresentation: currentPresentation,
            queuedPresentations: queuedPresentations
        )
    }

    func previewFlowCommand(_ command: ModalCommand<M>) -> FlowCommandPreview {
        previewFlowCommand(command, from: flowStateSnapshot)
    }

    func previewFlowCommand(
        _ command: ModalCommand<M>,
        from stateBefore: ModalStateSnapshot
    ) -> FlowCommandPreview {
        let outcome = middlewareRegistry.intercept(
            command,
            currentPresentation: stateBefore.currentPresentation,
            queuedPresentations: stateBefore.queuedPresentations
        )

        switch outcome.interception {
        case .cancel(let reason):
            return FlowCommandPreview(
                requestedCommand: command,
                effectiveCommand: outcome.command,
                result: .cancelled(reason),
                participantCount: outcome.participantCount,
                stateBefore: stateBefore,
                stateAfter: stateBefore
            )
        case .proceed(let effectiveCommand):
            let previewOutcome = previewApplyCommand(effectiveCommand, to: stateBefore)
            return FlowCommandPreview(
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
    func commitFlowPreview(_ preview: FlowCommandPreview) -> ModalExecutionResult<M> {
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
    }

    func commitFlowPreviews(_ previews: [FlowCommandPreview]) {
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
        to snapshot: ModalStateSnapshot
    ) -> (result: ModalExecutionResult<M>, stateAfter: ModalStateSnapshot) {
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
        on snapshot: ModalStateSnapshot
    ) -> (result: ModalExecutionResult<M>, stateAfter: ModalStateSnapshot) {
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
        on snapshot: ModalStateSnapshot
    ) -> (result: ModalExecutionResult<M>, stateAfter: ModalStateSnapshot) {
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
        on snapshot: ModalStateSnapshot
    ) -> (result: ModalExecutionResult<M>, stateAfter: ModalStateSnapshot) {
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
        on snapshot: ModalStateSnapshot
    ) -> (result: ModalExecutionResult<M>, stateAfter: ModalStateSnapshot) {
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

    private func emitCommittedEvents(for preview: FlowCommandPreview) {
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
    ) -> ModalStateSnapshot {
        let normalized = normalize(
            currentPresentation: currentPresentation,
            queuedPresentations: queuedPresentations
        )
        return ModalStateSnapshot(
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
