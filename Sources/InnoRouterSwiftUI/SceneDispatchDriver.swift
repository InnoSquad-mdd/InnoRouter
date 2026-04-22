// MARK: - SceneDispatchDriver.swift
// InnoRouterSwiftUI — shared visionOS-only dispatch loop for SceneHost
// and SceneAnchor.
// Copyright © 2026 Inno Squad. All rights reserved.

#if os(visionOS)

import Foundation
import SwiftUI

import InnoRouterCore

internal struct SceneDispatchDriver<R: Route> {
    internal let store: SceneStore<R>
    internal let scenes: SceneRegistry<R>
    internal let dispatcherToken: UUID
    internal let openWindow: (String, UUID) -> Void
    internal let openImmersiveSpace: (String) async -> OpenImmersiveSpaceAction.Result
    internal let dismissImmersiveSpace: () async -> Void
    internal let dismissWindow: (String, UUID) -> Void

    @MainActor
    internal func run() async {
        while
            let requestID = store.currentPendingRequestID,
            let intent = store.claimPendingRequest(
                requestID,
                dispatcherToken: dispatcherToken
            )
        {
            let resolution = SceneIntentResolver(scenes: scenes)
                .resolve(intent, state: store.snapshot)

            switch resolution {
            case .openWindow(let id, let value, let presentation):
                openWindow(id, value)
                _ = store.completeClaimedOpen(
                    presentation,
                    accepted: true,
                    requestID: requestID
                )

            case .openImmersive(let id, let presentation):
                let result = await openImmersiveSpace(id)
                let completion = store.completeClaimedOpen(
                    presentation,
                    accepted: result == .opened,
                    requestID: requestID
                )

                if completion == .cleanupSupersededImmersiveOpen {
                    await dismissImmersiveSpace()
                    _ = store.finishSupersededImmersiveOpenCleanup(requestID: requestID)
                }

            case .dismissWindow(let id, let value, let presentation):
                dismissWindow(id, value)
                _ = store.completeClaimedDismissal(of: presentation, requestID: requestID)

            case .dismissImmersive(let presentation):
                await dismissImmersiveSpace()
                _ = store.completeClaimedDismissal(of: presentation, requestID: requestID)

            case .reject(let rejectedIntent, let reason):
                _ = store.completeClaimedRejection(
                    for: rejectedIntent,
                    reason: reason,
                    requestID: requestID
                )
            }
        }
    }
}

#endif
