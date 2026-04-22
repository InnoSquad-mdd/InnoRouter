import Foundation
import Testing

import InnoRouterCore
@testable import InnoRouterSwiftUI

private enum SceneTestRoute: String, Route {
    case main
    case theatre
    case theatreTwo
    case volume
    case secondary
}

private func makeSceneRegistry() -> SceneRegistry<SceneTestRoute> {
    SceneRegistry(
        .window(.main, id: "main-window"),
        .volumetric(.volume, id: "volume-window", size: VolumetricSize(x: 1, y: 1, z: 1)),
        .immersive(.theatre, id: "theatre-space", style: .mixed)
    )
}

private func mainWindowPresentation() -> ScenePresentation<SceneTestRoute> {
    .window(.main)
}

private func volumePresentation() -> ScenePresentation<SceneTestRoute> {
    .volumetric(.volume, size: VolumetricSize(x: 1, y: 1, z: 1))
}

private func theatrePresentation(
    route: SceneTestRoute = .theatre,
    style: ImmersiveStyle = .mixed
) -> ScenePresentation<SceneTestRoute> {
    .immersive(route, style: style)
}

@Suite("SceneDispatcherRegistry Tests", .tags(.unit))
struct SceneDispatcherRegistryTests {
    @Test("primary host outranks fallback anchors and fallback order is stable")
    func primaryHostOutranksFallbackAnchors() {
        var registry = SceneDispatcherRegistry()
        let fallbackOne = UUID()
        let fallbackTwo = UUID()
        let primary = UUID()

        registry.registerFallbackAnchor(fallbackOne)
        registry.registerFallbackAnchor(fallbackTwo)
        #expect(registry.electedDispatcherToken == fallbackOne)
        #expect(registry.canClaim(fallbackOne))

        let didRegisterPrimary = registry.registerPrimaryHost(primary)
        #expect(didRegisterPrimary)
        #expect(registry.electedDispatcherToken == primary)
        #expect(registry.canClaim(primary))

        registry.unregisterPrimaryHost(primary)
        #expect(registry.electedDispatcherToken == fallbackOne)

        registry.unregisterFallbackAnchor(fallbackOne)
        #expect(registry.electedDispatcherToken == fallbackTwo)
    }

    @Test("second primary host registration is rejected")
    func secondPrimaryHostRegistrationFails() {
        var registry = SceneDispatcherRegistry()
        let primaryOne = UUID()
        let primaryTwo = UUID()

        let firstRegistration = registry.registerPrimaryHost(primaryOne)
        let secondRegistration = registry.registerPrimaryHost(primaryTwo)

        #expect(firstRegistration)
        #expect(secondRegistration == false)
        #expect(registry.electedDispatcherToken == primaryOne)
    }
}

@Suite("SceneStoreState Tests", .tags(.unit))
struct SceneStoreStateTests {
    @Test("dismissImmersive rejects when nothing is active")
    func dismissImmersiveRejectsWithoutActiveScene() {
        var state = SceneStoreState<SceneTestRoute>()

        let events = state.requestDismissImmersive()

        #expect(events == [.rejected(.dismissImmersive, reason: .nothingActive)])
        #expect(state.currentScene == nil)
        #expect(state.pendingIntent == nil)
    }

    @Test("dismissImmersive supersedes a matching pending immersive open")
    func dismissImmersiveSupersedesPendingOpen() {
        var state = SceneStoreState<SceneTestRoute>()
        let immersive = theatrePresentation()

        #expect(state.requestOpen(immersive).isEmpty)

        let events = state.requestDismissImmersive()

        #expect(events == [.rejected(.open(immersive), reason: .supersededByNewerIntent)])
        #expect(state.currentScene == nil)
        #expect(state.pendingIntent == nil)
    }

    @Test("pending immersive open keeps a real dismiss of the committed immersive scene")
    func pendingImmersiveOpenPreservesDismissOfCommittedImmersive() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let committedImmersive = theatrePresentation(route: .theatreTwo)
        let pendingImmersive = theatrePresentation()

        state.attach(committedImmersive)
        #expect(state.requestOpen(pendingImmersive).isEmpty)

        let events = state.requestDismissImmersive()

        #expect(events == [.rejected(.open(pendingImmersive), reason: .supersededByNewerIntent)])
        #expect(state.pendingIntent == .dismissImmersive)
        #expect(state.snapshot.activeImmersive == committedImmersive)
        #expect(state.currentScene == committedImmersive)

        let requestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(requestID) == .dismissImmersive)
        #expect(
            state.completeDismissal(
                of: committedImmersive,
                requestID: requestID
            ) == .broadcast(.dismissed(committedImmersive))
        )
        #expect(state.snapshot.activeImmersive == nil)
        #expect(state.currentScene == nil)
    }

    @Test("dismissWindow supersedes a matching pending window open")
    func dismissWindowSupersedesPendingOpen() {
        var state = SceneStoreState<SceneTestRoute>()
        let mainWindow = mainWindowPresentation()

        #expect(state.requestOpen(mainWindow).isEmpty)

        let events = state.requestDismissWindow(.main)

        #expect(events == [.rejected(.open(mainWindow), reason: .supersededByNewerIntent)])
        #expect(state.currentScene == nil)
        #expect(state.pendingIntent == nil)
    }

    @Test("invalid dismiss emits superseded and rejection events")
    func invalidDismissAfterPendingOpenEmitsBothEvents() {
        var state = SceneStoreState<SceneTestRoute>()
        let immersive = theatrePresentation()

        #expect(state.requestOpen(immersive).isEmpty)

        let events = state.requestDismissWindow(.main)

        #expect(
            events == [
                .rejected(.open(immersive), reason: .supersededByNewerIntent),
                .rejected(.dismissWindow(.main), reason: .nothingActive)
            ]
        )
        #expect(state.currentScene == nil)
        #expect(state.pendingIntent == nil)
    }

    @Test("attached root window is dismissible through inventory membership")
    func attachedRootWindowCanBeDismissed() {
        var state = SceneStoreState<SceneTestRoute>()
        state.attach(mainWindowPresentation())

        let events = state.requestDismissWindow(.main)

        #expect(events.isEmpty)
        #expect(state.currentScene == mainWindowPresentation())
        #expect(state.pendingIntent == .dismissWindow(.main))
    }

    @Test("duplicate active window open does not swallow a real dismissal")
    func duplicateActiveWindowOpenStillQueuesDismissal() {
        var state = SceneStoreState<SceneTestRoute>()
        let mainWindow = mainWindowPresentation()

        state.attach(mainWindow)
        #expect(state.requestOpen(mainWindow).isEmpty)

        let events = state.requestDismissWindow(.main)

        #expect(events == [.rejected(.open(mainWindow), reason: .supersededByNewerIntent)])
        #expect(state.pendingIntent == .dismissWindow(.main))
    }

    @Test("immersive round-trip preserves attached root window inventory")
    func immersiveRoundTripPreservesAttachedWindow() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let mainWindow = mainWindowPresentation()
        let immersive = theatrePresentation()

        state.attach(mainWindow)
        #expect(state.requestOpen(immersive).isEmpty)
        let openRequestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(openRequestID) == .open(immersive))
        #expect(
            state.completeOpen(
                immersive,
                accepted: true,
                requestID: openRequestID
            ) == .broadcast(.presented(immersive))
        )

        let dismissEvents = state.requestDismissImmersive()
        #expect(dismissEvents.isEmpty)
        #expect(state.pendingIntent == .dismissImmersive)
        let dismissRequestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(dismissRequestID) == .dismissImmersive)
        #expect(
            state.completeDismissal(
                of: immersive,
                requestID: dismissRequestID
            ) == .broadcast(.dismissed(immersive))
        )

        #expect(state.currentScene == mainWindow)
        #expect(state.snapshot.windowPresentation(for: .main) == mainWindow)
        #expect(state.snapshot.activeImmersive == nil)
    }

    @Test("wrong-route dismiss rejects against tracked inventory")
    func dismissWindowRejectsWrongRoute() {
        var state = SceneStoreState<SceneTestRoute>()
        let mainWindow = mainWindowPresentation()

        state.attach(mainWindow)

        let events = state.requestDismissWindow(.secondary)

        #expect(events == [.rejected(.dismissWindow(.secondary), reason: .activeSceneMismatch)])
        #expect(state.currentScene == mainWindow)
        #expect(state.pendingIntent == nil)
    }

    @Test("completeDismissal removes only the targeted window")
    func completeDismissalRemovesOnlyTargetWindow() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let mainWindow = mainWindowPresentation()
        let volume = volumePresentation()

        state.attach(mainWindow)
        state.attach(volume)
        #expect(state.requestDismissWindow(.main).isEmpty)
        let requestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(requestID) == .dismissWindow(.main))

        let completion = state.completeDismissal(of: mainWindow, requestID: requestID)

        #expect(completion == .broadcast(.dismissed(mainWindow)))
        #expect(state.currentScene == volume)
        #expect(state.snapshot.windowPresentation(for: .main) == nil)
        #expect(state.snapshot.windowPresentation(for: .volume) == volume)
    }

    @Test("silent detach is a no-op after explicit dismissal")
    func detachAfterExplicitDismissalIsIdempotent() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let mainWindow = mainWindowPresentation()
        let volume = volumePresentation()

        state.attach(mainWindow)
        state.attach(volume)
        #expect(state.requestDismissWindow(.main).isEmpty)
        let requestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(requestID) == .dismissWindow(.main))
        _ = state.completeDismissal(of: mainWindow, requestID: requestID)

        state.detach(mainWindow)

        #expect(state.currentScene == volume)
        #expect(state.snapshot.windowPresentation(for: .main) == nil)
        #expect(state.snapshot.windowPresentation(for: .volume) == volume)
    }

    @Test("claimed immersive open is deferred behind cleanup after supersede")
    func supersededClaimedImmersiveOpenDefersLatestRequestUntilCleanup() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let firstImmersive = theatrePresentation()
        let secondImmersive = theatrePresentation(route: .theatreTwo)

        #expect(state.requestOpen(firstImmersive).isEmpty)
        let firstRequestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(firstRequestID) == .open(firstImmersive))
        #expect(state.pendingIntent == nil)

        let events = state.requestOpen(secondImmersive)

        #expect(events == [.rejected(.open(firstImmersive), reason: .supersededByNewerIntent)])
        #expect(state.pendingIntent == nil)

        let completion = state.completeOpen(
            firstImmersive,
            accepted: true,
            requestID: firstRequestID
        )

        #expect(completion == .cleanupSupersededImmersiveOpen)
        #expect(state.pendingIntent == nil)

        _ = state.finishSupersededImmersiveOpenCleanup(requestID: firstRequestID)

        #expect(state.pendingIntent == .open(secondImmersive))
    }

    @Test("claimed immersive open preserves a follow-up dismiss until cleanup completes")
    func claimedImmersiveOpenPreservesFollowUpDismiss() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let immersive = theatrePresentation()

        #expect(state.requestOpen(immersive).isEmpty)
        let requestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(requestID) == .open(immersive))

        let events = state.requestDismissImmersive()

        #expect(events == [.rejected(.open(immersive), reason: .supersededByNewerIntent)])
        #expect(state.pendingIntent == nil)
        #expect(state.currentClaimedRequestID == requestID)

        let completion = state.completeOpen(
            immersive,
            accepted: true,
            requestID: requestID
        )

        #expect(completion == .cleanupSupersededImmersiveOpen)
        #expect(
            state.finishSupersededImmersiveOpenCleanup(requestID: requestID) ==
                .broadcast(.dismissed(immersive))
        )
        #expect(state.pendingIntent == nil)
        #expect(state.currentClaimedRequestID == nil)
        #expect(state.currentPendingRequestID == nil)
        #expect(state.snapshot.activeImmersive == nil)
        #expect(state.currentScene == nil)
    }

    @Test("claimed immersive open failure promotes a follow-up dismiss for final resolution")
    func claimedImmersiveOpenFailurePromotesFollowUpDismiss() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let immersive = theatrePresentation()

        #expect(state.requestOpen(immersive).isEmpty)
        let requestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(requestID) == .open(immersive))

        let events = state.requestDismissImmersive()

        #expect(events == [.rejected(.open(immersive), reason: .supersededByNewerIntent)])
        #expect(
            state.completeOpen(
                immersive,
                accepted: false,
                requestID: requestID
            ) == SceneClaimCompletion<SceneTestRoute>.none
        )
        #expect(state.pendingIntent == .dismissImmersive)
        #expect(state.currentPendingRequestID != nil)
        #expect(state.currentClaimedRequestID == nil)
    }

    @Test("immersive cleanup clears committed immersive state before broadcasting dismissal")
    func supersededImmersiveCleanupClearsCommittedImmersiveState() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let originallyAttachedImmersive = theatrePresentation(route: .theatreTwo)
        let staleImmersive = theatrePresentation()

        state.attach(originallyAttachedImmersive)
        #expect(state.requestOpen(staleImmersive).isEmpty)
        let requestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(requestID) == .open(staleImmersive))

        let events = state.requestDismissImmersive()

        #expect(events == [.rejected(.open(staleImmersive), reason: .supersededByNewerIntent)])
        #expect(
            state.completeOpen(
                staleImmersive,
                accepted: true,
                requestID: requestID
            ) == .cleanupSupersededImmersiveOpen
        )
        #expect(
            state.finishSupersededImmersiveOpenCleanup(requestID: requestID) ==
                .broadcast(.dismissed(staleImmersive))
        )
        #expect(state.snapshot.activeImmersive == nil)
        #expect(state.currentScene == nil)
        #expect(state.pendingIntent == nil)

        let followUpEvents = state.requestDismissImmersive()

        #expect(followUpEvents == [.rejected(.dismissImmersive, reason: .nothingActive)])
    }

    @Test("duplicate active immersive open superseded by dismiss queues the real dismissal")
    func duplicateActiveImmersiveOpenStillQueuesDismissal() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let immersive = theatrePresentation()

        state.attach(immersive)
        #expect(state.requestOpen(immersive).isEmpty)
        let requestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(requestID) == .open(immersive))

        let events = state.requestDismissImmersive()

        #expect(events == [.rejected(.open(immersive), reason: .supersededByNewerIntent)])
        #expect(state.pendingIntent == nil)

        let completion = state.completeOpen(
            immersive,
            accepted: true,
            requestID: requestID
        )

        #expect(completion == SceneClaimCompletion<SceneTestRoute>.none)
        #expect(state.pendingIntent == .dismissImmersive)
        #expect(state.snapshot.activeImmersive == immersive)
    }

    @Test("stale immersive dismissal completion is ignored after supersede")
    func staleImmersiveDismissalCompletionIsIgnored() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let immersive = theatrePresentation()
        let mainWindow = mainWindowPresentation()

        state.attach(immersive)
        #expect(state.requestDismissImmersive().isEmpty)
        let staleRequestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(staleRequestID) == .dismissImmersive)

        let events = state.requestOpen(mainWindow)

        #expect(events == [.rejected(.dismissImmersive, reason: .supersededByNewerIntent)])
        #expect(
            state.completeDismissal(
                of: immersive,
                requestID: staleRequestID
            ) == SceneClaimCompletion<SceneTestRoute>.none
        )
        #expect(state.snapshot.activeImmersive == nil)
        #expect(state.currentScene == nil)
        #expect(state.pendingIntent == .open(mainWindow))

        let resolution = SceneIntentResolver(scenes: makeSceneRegistry()).resolve(
            .dismissImmersive,
            state: state.snapshot
        )

        #expect(resolution == .reject(.dismissImmersive, reason: .nothingActive))
    }

    @Test("currentScene remains a recency summary of active inventory")
    func currentSceneTracksRecencySummary() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let mainWindow = mainWindowPresentation()
        let volume = volumePresentation()
        let immersive = theatrePresentation()

        state.attach(mainWindow)
        #expect(state.currentScene == mainWindow)

        state.attach(volume)
        #expect(state.currentScene == volume)

        #expect(state.requestOpen(immersive).isEmpty)
        let openRequestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(openRequestID) == .open(immersive))
        #expect(
            state.completeOpen(
                immersive,
                accepted: true,
                requestID: openRequestID
            ) == .broadcast(.presented(immersive))
        )
        #expect(state.currentScene == immersive)

        #expect(state.requestDismissImmersive().isEmpty)
        let dismissRequestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(dismissRequestID) == .dismissImmersive)
        _ = state.completeDismissal(of: immersive, requestID: dismissRequestID)
        #expect(state.currentScene == volume)
    }

    @Test("completeRejection clears claimed request and preserves committed inventory")
    func completeRejectionPreservesCommittedInventory() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let mainWindow = mainWindowPresentation()

        state.attach(mainWindow)
        #expect(state.requestDismissWindow(.main).isEmpty)
        let requestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(requestID) == .dismissWindow(.main))

        let completion = state.completeRejection(
            for: .dismissWindow(.main),
            reason: .activeSceneMismatch,
            requestID: requestID
        )

        #expect(completion == .broadcast(.rejected(.dismissWindow(.main), reason: .activeSceneMismatch)))
        #expect(state.currentScene == mainWindow)
        #expect(state.pendingIntent == nil)
        #expect(state.snapshot.windowPresentation(for: .main) == mainWindow)
    }

    @Test("completeOpen failure preserves committed inventory")
    func completeOpenFailurePreservesCurrentInventory() throws {
        var state = SceneStoreState<SceneTestRoute>()
        let mainWindow = mainWindowPresentation()
        let immersive = theatrePresentation()

        state.attach(mainWindow)
        #expect(state.requestOpen(immersive).isEmpty)
        let requestID = try #require(state.currentPendingRequestID)
        #expect(state.claimPendingRequest(requestID) == .open(immersive))

        let completion = state.completeOpen(
            immersive,
            accepted: false,
            requestID: requestID
        )

        #expect(completion == .broadcast(.rejected(.open(immersive), reason: .environmentReturnedFailure)))
        #expect(state.currentScene == mainWindow)
        #expect(state.pendingIntent == nil)
        #expect(state.snapshot.windowPresentation(for: .main) == mainWindow)
        #expect(state.snapshot.activeImmersive == nil)
    }
}

@Suite("SceneIntentResolver Tests", .tags(.unit))
struct SceneIntentResolverTests {
    @Test("open rejects undeclared routes")
    func openRejectsUndeclaredRoute() {
        let resolver = SceneIntentResolver(scenes: makeSceneRegistry())
        let presentation: ScenePresentation<SceneTestRoute> = .window(.secondary)

        let resolution = resolver.resolve(
            .open(presentation),
            state: SceneStoreState<SceneTestRoute>().snapshot
        )

        #expect(resolution == .reject(.open(presentation), reason: .sceneNotDeclared))
    }

    @Test("open rejects kind mismatch against the registry")
    func openRejectsKindMismatch() {
        let resolver = SceneIntentResolver(scenes: makeSceneRegistry())
        let presentation: ScenePresentation<SceneTestRoute> = .window(.theatre)

        let resolution = resolver.resolve(
            .open(presentation),
            state: SceneStoreState<SceneTestRoute>().snapshot
        )

        #expect(resolution == .reject(.open(presentation), reason: .sceneDeclarationMismatch))
    }

    @Test("open rejects size and style mismatches against the registry")
    func openRejectsMetadataMismatch() {
        let resolver = SceneIntentResolver(scenes: makeSceneRegistry())
        let volumetricMismatch: ScenePresentation<SceneTestRoute> = .volumetric(
            .volume,
            size: VolumetricSize(x: 2, y: 2, z: 2)
        )
        let immersiveMismatch = theatrePresentation(style: .full)

        let volumetricResolution = resolver.resolve(
            .open(volumetricMismatch),
            state: SceneStoreState<SceneTestRoute>().snapshot
        )
        let immersiveResolution = resolver.resolve(
            .open(immersiveMismatch),
            state: SceneStoreState<SceneTestRoute>().snapshot
        )

        #expect(volumetricResolution == .reject(.open(volumetricMismatch), reason: .sceneDeclarationMismatch))
        #expect(immersiveResolution == .reject(.open(immersiveMismatch), reason: .sceneDeclarationMismatch))
    }

    @Test("matching declarations resolve to concrete open dispatches")
    func openResolvesMatchingDeclarations() {
        let resolver = SceneIntentResolver(scenes: makeSceneRegistry())
        let windowPresentation = mainWindowPresentation()
        let volume = volumePresentation()
        let immersive = theatrePresentation()

        let windowResolution = resolver.resolve(
            .open(windowPresentation),
            state: SceneStoreState<SceneTestRoute>().snapshot
        )
        let volumeResolution = resolver.resolve(
            .open(volume),
            state: SceneStoreState<SceneTestRoute>().snapshot
        )
        let immersiveResolution = resolver.resolve(
            .open(immersive),
            state: SceneStoreState<SceneTestRoute>().snapshot
        )

        #expect(windowResolution == .openWindow(id: "main-window", presentation: windowPresentation))
        #expect(volumeResolution == .openWindow(id: "volume-window", presentation: volume))
        #expect(immersiveResolution == .openImmersive(id: "theatre-space", presentation: immersive))
    }

    @Test("dismissWindow resolves against inventory even when currentScene is immersive")
    func dismissWindowUsesInventoryMembership() {
        let resolver = SceneIntentResolver(scenes: makeSceneRegistry())
        var state = SceneStoreState<SceneTestRoute>()
        let mainWindow = mainWindowPresentation()
        let immersive = theatrePresentation()

        state.attach(mainWindow)
        state.attach(immersive)

        let resolution = resolver.resolve(.dismissWindow(.main), state: state.snapshot)

        #expect(resolution == .dismissWindow(id: "main-window", presentation: mainWindow))
    }

    @Test("dismissImmersive uses active immersive membership instead of currentScene alone")
    func dismissImmersiveUsesActiveImmersiveInventory() {
        let resolver = SceneIntentResolver(scenes: makeSceneRegistry())
        var state = SceneStoreState<SceneTestRoute>()

        state.attach(mainWindowPresentation())

        let resolution = resolver.resolve(.dismissImmersive, state: state.snapshot)

        #expect(resolution == .reject(.dismissImmersive, reason: .activeSceneMismatch))
    }

    @Test("dismissWindow rejects registry mismatches before dispatch")
    func dismissWindowRejectsRegistryMismatch() {
        let scenes = SceneRegistry<SceneTestRoute>(
            .immersive(.main, id: "main-space", style: .mixed)
        )
        let resolver = SceneIntentResolver(scenes: scenes)
        var state = SceneStoreState<SceneTestRoute>()
        let activeScene = mainWindowPresentation()

        state.attach(activeScene)

        let resolution = resolver.resolve(.dismissWindow(.main), state: state.snapshot)

        #expect(resolution == .reject(.dismissWindow(.main), reason: .sceneDeclarationMismatch))
    }
}
