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

    public func dismissCurrent() {
        dismissCurrent(reason: .dismiss)
    }

    func dismissCurrent(reason: ModalDismissalReason) {
        _ = execute(.dismissCurrent(reason: reason))
    }

    public func dismissAll() {
        _ = execute(.dismissAll)
    }

    // MARK: - Command application (post-interception)

    private func applyCommand(_ command: ModalCommand<M>) -> ModalExecutionResult<M> {
        switch command {
        case .present(let presentation):
            return applyPresent(presentation)
        case .dismissCurrent(let reason):
            return applyDismissCurrent(reason: reason)
        case .dismissAll:
            return applyDismissAll()
        }
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
