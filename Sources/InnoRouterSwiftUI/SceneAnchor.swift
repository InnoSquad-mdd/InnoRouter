// MARK: - SceneAnchor.swift
// InnoRouterSwiftUI — visionOS-only scene lifecycle reconciliation
// modifier for SceneStore inventory tracking.
// Copyright © 2026 Inno Squad. All rights reserved.

#if os(visionOS)

import Foundation
import SwiftUI

import InnoRouterCore

/// View modifier that reconciles a scene root with a ``SceneStore``'s
/// internal inventory and serves as a fallback dispatcher when no
/// explicit ``SceneHost`` is currently live.
///
/// Apply one scene anchor to each `WindowGroup` / `ImmersiveSpace` root
/// that participates in the store's scene registry. Anchors never emit
/// public lifecycle events; they keep the store's internal scene
/// inventory aligned with system-driven appear/disappear transitions and
/// can temporarily own dispatch when the preferred host scene is gone.
public struct SceneAnchor<R: Route>: ViewModifier {
    @Bindable private var store: SceneStore<R>
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var dispatcherToken = UUID()
    private let scenes: SceneRegistry<R>
    private let attachedPresentation: ScenePresentation<R>

    /// Creates a scene anchor.
    ///
    /// - Parameters:
    ///   - store: the scene store whose inventory should track this
    ///     scene root.
    ///   - scenes: scene declarations shared with the app's
    ///     `WindowGroup` / `ImmersiveSpace` definitions.
    ///   - attachedTo: the route declared for the containing scene.
    public init(
        store: SceneStore<R>,
        scenes: SceneRegistry<R>,
        attachedTo: R
    ) {
        guard let declaration = scenes.declaration(for: attachedTo) else {
            preconditionFailure(
                "SceneAnchor requires attachedTo to be declared in scenes. Missing route: \(String(describing: attachedTo))"
            )
        }

        self.store = store
        self.scenes = scenes
        self.attachedPresentation = declaration.presentation
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                store.attachDeclaredScene(attachedPresentation)
                store.registerFallbackDispatcher(dispatcherToken)
                Task { @MainActor in
                    await dispatchPendingRequests()
                }
            }
            .onDisappear {
                store.detachDeclaredScene(attachedPresentation)
                store.unregisterFallbackDispatcher(dispatcherToken)
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
            openWindow: { id in openWindow(id: id) },
            openImmersiveSpace: { id in await openImmersiveSpace(id: id) },
            dismissImmersiveSpace: { await dismissImmersiveSpace() },
            dismissWindow: { id in dismissWindow(id: id) }
        ).run()
    }
}

public extension View {
    /// Attaches a ``SceneAnchor`` that reconciles a scene root with a
    /// ``SceneStore`` inventory and provides fallback dispatch when no
    /// explicit host is alive.
    ///
    /// Available on visionOS only. On other platforms this modifier is
    /// not declared; `SceneStore`, `SceneHost`, and `SceneAnchor` exist
    /// only behind `#if os(visionOS)`.
    func innoRouterSceneAnchor<R: Route>(
        _ store: SceneStore<R>,
        scenes: SceneRegistry<R>,
        attachedTo: R
    ) -> some View {
        modifier(SceneAnchor(store: store, scenes: scenes, attachedTo: attachedTo))
    }
}

#endif
