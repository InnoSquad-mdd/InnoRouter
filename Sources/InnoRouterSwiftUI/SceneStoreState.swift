import Foundation

import InnoRouterCore

internal struct ScenePendingRequest<R: Route>: Equatable {
    internal let id: UUID
    internal let intent: SceneIntent<R>
}

internal struct SceneClaimedRequest<R: Route>: Equatable {
    internal enum Status: Equatable {
        case active
        case superseded
        case awaitingSupersededImmersiveOpenCleanup
    }

    internal let request: ScenePendingRequest<R>
    internal var status: Status
}

internal enum SceneClaimCompletion<R: Route>: Equatable {
    case broadcast(SceneEvent<R>)
    case cleanupSupersededImmersiveOpen
    case none
}

internal struct SceneDispatcherRegistry: Equatable {
    internal private(set) var primaryHost: UUID?
    internal private(set) var fallbackAnchors: [UUID] = []

    internal var electedDispatcherToken: UUID? {
        primaryHost ?? fallbackAnchors.first
    }

    internal mutating func registerPrimaryHost(_ token: UUID) -> Bool {
        if let primaryHost, primaryHost != token {
            return false
        }

        primaryHost = token
        return true
    }

    internal mutating func unregisterPrimaryHost(_ token: UUID) {
        if primaryHost == token {
            primaryHost = nil
        }
    }

    internal mutating func registerFallbackAnchor(_ token: UUID) {
        if fallbackAnchors.contains(token) == false {
            fallbackAnchors.append(token)
        }
    }

    internal mutating func unregisterFallbackAnchor(_ token: UUID) {
        fallbackAnchors.removeAll { $0 == token }
    }

    internal func canClaim(_ token: UUID) -> Bool {
        electedDispatcherToken == token
    }
}

internal struct SceneStoreSnapshot<R: Route>: Equatable {
    internal let currentScene: ScenePresentation<R>?
    internal let openWindowsByRoute: [R: ScenePresentation<R>]
    internal let activeImmersive: ScenePresentation<R>?

    internal var hasActiveScenes: Bool {
        !openWindowsByRoute.isEmpty || activeImmersive != nil
    }

    internal func windowPresentation(for route: R) -> ScenePresentation<R>? {
        openWindowsByRoute[route]
    }
}

internal struct SceneStoreState<R: Route>: Equatable {
    internal private(set) var currentScene: ScenePresentation<R>?
    internal private(set) var pendingRequest: ScenePendingRequest<R>?
    internal private(set) var claimedRequest: SceneClaimedRequest<R>?
    internal private(set) var deferredRequest: ScenePendingRequest<R>?

    private var openWindowsByRoute: [R: ScenePresentation<R>]
    private var activeImmersive: ScenePresentation<R>?
    private var activeScenesInRecencyOrder: [ScenePresentation<R>]

    internal init(
        currentScene: ScenePresentation<R>? = nil,
        pendingIntent: SceneIntent<R>? = nil
    ) {
        self.currentScene = nil
        self.pendingRequest = pendingIntent.map {
            ScenePendingRequest(id: UUID(), intent: $0)
        }
        self.claimedRequest = nil
        self.deferredRequest = nil
        self.openWindowsByRoute = [:]
        self.activeImmersive = nil
        self.activeScenesInRecencyOrder = []

        if let currentScene {
            activate(currentScene)
        }
    }

    internal var pendingIntent: SceneIntent<R>? {
        pendingRequest?.intent
    }

    internal var currentPendingRequestID: UUID? {
        pendingRequest?.id
    }

    internal var currentClaimedRequestID: UUID? {
        claimedRequest?.request.id
    }

    internal var snapshot: SceneStoreSnapshot<R> {
        SceneStoreSnapshot(
            currentScene: currentScene,
            openWindowsByRoute: openWindowsByRoute,
            activeImmersive: activeImmersive
        )
    }

    internal mutating func requestOpen(_ presentation: ScenePresentation<R>) -> [SceneEvent<R>] {
        let intent = SceneIntent<R>.open(presentation)
        let preparation = prepareForNewIntent(intent)
        guard let queueTarget = preparation.queueTarget else {
            return preparation.events
        }

        queue(makePendingRequest(for: intent), in: queueTarget)
        return preparation.events
    }

    internal mutating func requestDismissImmersive() -> [SceneEvent<R>] {
        let intent = SceneIntent<R>.dismissImmersive
        let preparation = prepareForNewIntent(intent)
        var events = preparation.events
        guard let queueTarget = preparation.queueTarget else {
            return events
        }

        guard
            activeImmersive != nil ||
                allowsDeferredImmersiveDismissWithoutCommittedActiveScene(in: queueTarget)
        else {
            events.append(
                .rejected(
                    intent,
                    reason: snapshot.hasActiveScenes ? .activeSceneMismatch : .nothingActive
                )
            )
            return events
        }

        queue(makePendingRequest(for: intent), in: queueTarget)
        return events
    }

    internal mutating func requestDismissWindow(_ route: R) -> [SceneEvent<R>] {
        let intent = SceneIntent<R>.dismissWindow(route)
        let preparation = prepareForNewIntent(intent)
        var events = preparation.events
        guard let queueTarget = preparation.queueTarget else {
            return events
        }

        guard openWindowsByRoute[route] != nil else {
            events.append(
                .rejected(
                    intent,
                    reason: snapshot.hasActiveScenes ? .activeSceneMismatch : .nothingActive
                )
            )
            return events
        }

        queue(makePendingRequest(for: intent), in: queueTarget)
        return events
    }

    internal mutating func claimPendingRequest(_ requestID: UUID) -> SceneIntent<R>? {
        guard claimedRequest == nil else {
            return nil
        }
        guard let pendingRequest, pendingRequest.id == requestID else {
            return nil
        }

        self.pendingRequest = nil
        claimedRequest = SceneClaimedRequest(request: pendingRequest, status: .active)
        return pendingRequest.intent
    }

    internal mutating func attach(_ presentation: ScenePresentation<R>) {
        activate(presentation)
    }

    internal mutating func detach(_ presentation: ScenePresentation<R>) {
        deactivate(presentation)
    }

    internal mutating func completeOpen(
        _ presentation: ScenePresentation<R>,
        accepted: Bool,
        requestID: UUID?
    ) -> SceneClaimCompletion<R>? {
        guard let requestID else {
            return nil
        }
        guard let claimedRequest, claimedRequest.request.id == requestID else {
            return nil
        }
        guard claimedRequest.request.intent == .open(presentation) else {
            return nil
        }

        switch claimedRequest.status {
        case .active:
            self.claimedRequest = nil

            let event: SceneEvent<R>
            if accepted {
                activate(presentation)
                event = .presented(presentation)
            } else {
                event = .rejected(.open(presentation), reason: .environmentReturnedFailure)
            }

            promoteDeferredIfPossible()
            return .broadcast(event)

        case .superseded:
            if accepted, needsImmersiveCleanupAfterSupersededOpen(of: presentation) {
                self.claimedRequest?.status = .awaitingSupersededImmersiveOpenCleanup
                return .cleanupSupersededImmersiveOpen
            }

            self.claimedRequest = nil
            promoteDeferredIfPossible()
            return SceneClaimCompletion.none

        case .awaitingSupersededImmersiveOpenCleanup:
            return nil
        }
    }

    internal mutating func finishSupersededImmersiveOpenCleanup(
        requestID: UUID?
    ) -> SceneClaimCompletion<R>? {
        guard let requestID else {
            return nil
        }
        guard let claimedRequest, claimedRequest.request.id == requestID else {
            return nil
        }
        guard claimedRequest.status == .awaitingSupersededImmersiveOpenCleanup else {
            return nil
        }

        let cleanedUpPresentation = claimedRequest.request.intent.openedPresentation
        self.claimedRequest = nil
        clearCommittedImmersiveState()

        if let cleanedUpPresentation, deferredRequest?.intent == .dismissImmersive {
            deferredRequest = nil
            promoteDeferredIfPossible()
            return .broadcast(.dismissed(cleanedUpPresentation))
        }

        promoteDeferredIfPossible()
        return SceneClaimCompletion.none
    }

    internal mutating func completeDismissal(
        of presentation: ScenePresentation<R>,
        requestID: UUID?
    ) -> SceneClaimCompletion<R>? {
        guard let requestID else {
            return nil
        }
        guard let claimedRequest, claimedRequest.request.id == requestID else {
            return nil
        }
        guard claimedRequest.request.intent == dismissalIntent(for: presentation) else {
            return nil
        }

        let status = claimedRequest.status
        self.claimedRequest = nil

        if status == .active {
            deactivate(presentation)
            promoteDeferredIfPossible()
            return .broadcast(.dismissed(presentation))
        }

        silentlyReconcileSupersededDismissalIfNeeded(of: presentation, status: status)
        promoteDeferredIfPossible()
        return SceneClaimCompletion.none
    }

    internal mutating func completeRejection(
        for intent: SceneIntent<R>,
        reason: SceneRejectionReason,
        requestID: UUID?
    ) -> SceneClaimCompletion<R>? {
        guard let requestID else {
            return nil
        }
        guard let claimedRequest, claimedRequest.request.id == requestID else {
            return nil
        }
        guard claimedRequest.request.intent == intent else {
            return nil
        }

        let status = claimedRequest.status
        self.claimedRequest = nil
        promoteDeferredIfPossible()

        if status == .active {
            return .broadcast(.rejected(intent, reason: reason))
        }

        return SceneClaimCompletion.none
    }

    private enum QueueTarget {
        case pending
        case deferred
    }

    private mutating func prepareForNewIntent(
        _ newIntent: SceneIntent<R>
    ) -> (events: [SceneEvent<R>], queueTarget: QueueTarget?) {
        if claimedRequest?.request.intent.isImmersiveOperation == true {
            return prepareForNewIntentWhileImmersiveRequestIsClaimed(newIntent)
        }

        guard let pendingRequest else {
            return ([], .pending)
        }
        guard pendingRequest.intent != newIntent else {
            return ([], nil)
        }

        self.pendingRequest = nil

        let supersededEvent = SceneEvent<R>.rejected(
            pendingRequest.intent,
            reason: .supersededByNewerIntent
        )

        if canDropFollowUpDismissAfterSupersedingPendingOpen(
            pendingIntent: pendingRequest.intent,
            with: newIntent
        ) {
            return ([supersededEvent], nil)
        }

        return ([supersededEvent], .pending)
    }

    private mutating func prepareForNewIntentWhileImmersiveRequestIsClaimed(
        _ newIntent: SceneIntent<R>
    ) -> (events: [SceneEvent<R>], queueTarget: QueueTarget?) {
        var events: [SceneEvent<R>] = []

        if let deferredRequest {
            if deferredRequest.intent == newIntent {
                return ([], nil)
            }

            self.deferredRequest = nil
            events.append(
                .rejected(
                    deferredRequest.intent,
                    reason: .supersededByNewerIntent
                )
            )

        }

        guard var claimedRequest else {
            return (events, .pending)
        }

        if claimedRequest.status == .active, claimedRequest.request.intent == newIntent {
            return (events, nil)
        }

        if claimedRequest.status == .active {
            claimedRequest.status = .superseded
            self.claimedRequest = claimedRequest
            events.append(
                .rejected(
                    claimedRequest.request.intent,
                    reason: .supersededByNewerIntent
                )
            )
        }

        return (events, .deferred)
    }

    private mutating func queue(
        _ request: ScenePendingRequest<R>,
        in target: QueueTarget
    ) {
        switch target {
        case .pending:
            pendingRequest = request
        case .deferred:
            deferredRequest = request
        }
    }

    private mutating func promoteDeferredIfPossible() {
        guard claimedRequest == nil else {
            return
        }
        guard pendingRequest == nil else {
            return
        }
        guard let deferredRequest else {
            return
        }

        self.deferredRequest = nil
        pendingRequest = deferredRequest
    }

    private func makePendingRequest(for intent: SceneIntent<R>) -> ScenePendingRequest<R> {
        ScenePendingRequest(id: UUID(), intent: intent)
    }

    private func needsImmersiveCleanupAfterSupersededOpen(
        of presentation: ScenePresentation<R>
    ) -> Bool {
        guard presentation.isImmersive else {
            return false
        }

        return activeImmersive != presentation
    }

    private func allowsDeferredImmersiveDismissWithoutCommittedActiveScene(
        in queueTarget: QueueTarget
    ) -> Bool {
        guard queueTarget == .deferred else {
            return false
        }
        guard let claimedPresentation = claimedRequest?.request.intent.openedPresentation else {
            return false
        }

        return claimedPresentation.isImmersive
    }

    private func canDropFollowUpDismissAfterSupersedingPendingOpen(
        pendingIntent: SceneIntent<R>,
        with newIntent: SceneIntent<R>
    ) -> Bool {
        guard let pendingPresentation = pendingIntent.openedPresentation else {
            return false
        }
        guard newIntent.dismissesSameScene(as: pendingPresentation) else {
            return false
        }

        switch newIntent {
        case .open:
            return false
        case .dismissImmersive:
            return activeImmersive == nil
        case .dismissWindow(let route):
            return openWindowsByRoute[route] == nil
        }
    }

    private mutating func silentlyReconcileSupersededDismissalIfNeeded(
        of presentation: ScenePresentation<R>,
        status: SceneClaimedRequest<R>.Status
    ) {
        guard status != .active else {
            return
        }
        guard presentation.isImmersive else {
            return
        }

        clearCommittedImmersiveState()
    }

    private mutating func activate(_ presentation: ScenePresentation<R>) {
        switch presentation {
        case .window, .volumetric:
            openWindowsByRoute[presentation.route] = presentation
        case .immersive:
            if let activeImmersive, activeImmersive.route != presentation.route {
                activeScenesInRecencyOrder.removeAll { $0.route == activeImmersive.route }
            }
            self.activeImmersive = presentation
        }

        touch(presentation)
        syncCurrentScene()
    }

    private mutating func clearCommittedImmersiveState() {
        activeImmersive = nil
        activeScenesInRecencyOrder.removeAll { $0.isImmersive }
        syncCurrentScene()
    }

    private mutating func deactivate(_ presentation: ScenePresentation<R>) {
        switch presentation {
        case .window, .volumetric:
            openWindowsByRoute.removeValue(forKey: presentation.route)
        case .immersive:
            if activeImmersive?.route == presentation.route {
                activeImmersive = nil
            }
        }

        activeScenesInRecencyOrder.removeAll { $0.route == presentation.route }
        syncCurrentScene()
    }

    private mutating func touch(_ presentation: ScenePresentation<R>) {
        activeScenesInRecencyOrder.removeAll { $0.route == presentation.route }
        activeScenesInRecencyOrder.append(presentation)
    }

    private mutating func syncCurrentScene() {
        let activeScenes = activeScenesInRecencyOrder.filter { isActive($0) }
        activeScenesInRecencyOrder = activeScenes
        currentScene = activeScenes.last
    }

    private func isActive(_ presentation: ScenePresentation<R>) -> Bool {
        switch presentation {
        case .window, .volumetric:
            return openWindowsByRoute[presentation.route] == presentation
        case .immersive:
            return activeImmersive == presentation
        }
    }

    private func dismissalIntent(
        for presentation: ScenePresentation<R>
    ) -> SceneIntent<R> {
        switch presentation {
        case .window(let route), .volumetric(let route, _):
            return .dismissWindow(route)
        case .immersive:
            return .dismissImmersive
        }
    }
}
