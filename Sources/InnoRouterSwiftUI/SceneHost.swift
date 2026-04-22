// MARK: - SceneHost.swift
// InnoRouterSwiftUI — visionOS-only host that bridges SceneStore to
// SwiftUI's spatial scene actions (openWindow / openImmersiveSpace /
// dismissImmersiveSpace / dismissWindow).
// Copyright © 2026 Inno Squad. All rights reserved.

// MARK: - Platform: This host reads visionOS-specific EnvironmentValues
// (`openImmersiveSpace`, `dismissImmersiveSpace`). It therefore exists
// only on visionOS.
#if os(visionOS)

import Foundation
import SwiftUI

import InnoRouterCore

/// Primary dispatcher for a ``SceneStore`` on visionOS.
///
/// `SceneHost` is the single source of authority for every
/// `openWindow` / `openImmersiveSpace` / `dismissImmersiveSpace` /
/// `dismissWindow` call InnoRouter issues. When attached to a scene
/// root, it reads those actions from SwiftUI's environment, claims
/// pending intents from the store, runs the async dispatch loop, and
/// commits results back through `completeClaimedOpen` /
/// `completeClaimedDismissal` / `completeClaimedRejection`.
///
/// Contract:
///
/// - **Attach exactly one `SceneHost` per ``SceneStore``.** Secondary
///   hosts receive a
///   ``SceneEvent/hostRegistrationRejected(reason:)`` event with
///   ``SceneRejectionReason/duplicateHostRegistration`` and stay
///   dormant. They do not crash the app, so SwiftUI scene
///   rehydration / hot-reload flows that momentarily overlap two
///   hosts are safe.
/// - **Do not pair it with a ``SceneAnchor`` on the same scene.** The
///   host already reconciles its own scene's lifecycle; adding an
///   anchor registers a redundant fallback dispatcher on a scene the
///   host owns.
/// - **Every non-host scene should attach a ``SceneAnchor`` instead**
///   so system-driven appear/disappear events keep
///   ``SceneStore/currentScene`` and the internal inventory in sync.
///
/// Use the convenience wrapper
/// ``SwiftUI/View/innoRouterSceneHost(_:scenes:)`` instead of
/// instantiating the modifier directly.
public struct SceneHost<R: Route>: ViewModifier {
    @Bindable private var store: SceneStore<R>
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var dispatcherToken = UUID()
    @State private var isDormant: Bool = false
    @State private var dispatchTask: Task<Void, Never>?
    private let scenes: SceneRegistry<R>

    /// Creates a scene host.
    ///
    /// - Parameters:
    ///   - store: the scene store driving this host.
    ///   - scenes: scene declarations shared with the app's
    ///     `WindowGroup` / `ImmersiveSpace` definitions.
    public init(store: SceneStore<R>, scenes: SceneRegistry<R>) {
        self.store = store
        self.scenes = scenes
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                // If another SceneHost is already primary the store
                // returns false and broadcasts
                // `.hostRegistrationRejected` — stay dormant instead of
                // crashing so SwiftUI scene rehydration / hot-reload
                // flows that briefly overlap two hosts don't take the
                // app down.
                let didRegister = store.registerDispatcherHost(dispatcherToken)
                isDormant = !didRegister
                guard didRegister else { return }
                spawnDispatchTask()
            }
            .onDisappear {
                // Cancel any in-flight dispatch first. The driver checks
                // Task.isCancelled after every async environment call
                // and abandons an outstanding claim with
                // `.hostTornDownDuringDispatch` instead of silently
                // committing an outcome the next dispatcher has no way
                // to reconcile.
                dispatchTask?.cancel()
                dispatchTask = nil

                // Only unregister if this host actually owned the
                // primary slot. A dormant host never registered and must
                // not disturb the live primary's registration.
                guard !isDormant else { return }
                store.unregisterDispatcherHost(dispatcherToken)
            }
            .onChange(of: store.dispatchSignal) { _, _ in
                guard !isDormant else { return }
                spawnDispatchTask()
            }
    }

    @MainActor
    private func spawnDispatchTask() {
        // Track only the most recent dispatch task. Older in-flight
        // tasks self-terminate because `claimPendingRequest` serialises
        // access — a losing task returns nil and exits its loop.
        dispatchTask = Task { @MainActor in
            await dispatchPendingRequests()
        }
    }

    @MainActor
    private func dispatchPendingRequests() async {
        await SceneDispatchDriver(
            store: store,
            scenes: scenes,
            dispatcherToken: dispatcherToken,
            capability: .primaryHost,
            openWindow: { id, value in openWindow(id: id, value: value) },
            openImmersiveSpace: { id in await openImmersiveSpace(id: id) },
            dismissImmersiveSpace: { await dismissImmersiveSpace() },
            dismissWindow: { id, value in dismissWindow(id: id, value: value) }
        ).run()
    }
}

public extension View {
    /// Attaches a ``SceneHost`` that bridges `store` to SwiftUI's
    /// spatial scene environment actions.
    ///
    /// Available on visionOS only. On other platforms this modifier is
    /// not declared; `SceneStore` and `SceneHost` exist only behind
    /// `#if os(visionOS)`.
    func innoRouterSceneHost<R: Route>(
        _ store: SceneStore<R>,
        scenes: SceneRegistry<R>
    ) -> some View {
        modifier(SceneHost(store: store, scenes: scenes))
    }
}

#endif
