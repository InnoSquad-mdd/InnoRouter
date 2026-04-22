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

/// View modifier that dispatches a ``SceneStore``'s pending intents into
/// SwiftUI's spatial scene environment actions.
///
/// Attach exactly one scene host per ``SceneStore``. Additional scene
/// roots should use ``SceneAnchor`` for lifecycle reconciliation and
/// fallback dispatch ownership when the host scene disappears.
///
/// Use the convenience wrapper ``SwiftUI/View/innoRouterSceneHost(_:scenes:)``
/// instead of instantiating the modifier directly.
public struct SceneHost<R: Route>: ViewModifier {
    @Bindable private var store: SceneStore<R>
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var dispatcherToken = UUID()
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
                store.registerDispatcherHost(dispatcherToken)
                Task { @MainActor in
                    await dispatchPendingRequests()
                }
            }
            .onDisappear {
                store.unregisterDispatcherHost(dispatcherToken)
            }
            .onChange(of: store.dispatchSignal) { _, _ in
                Task { @MainActor in
                    await dispatchPendingRequests()
                }
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
