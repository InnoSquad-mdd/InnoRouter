// MARK: - SceneHost.swift
// InnoRouterSwiftUI — visionOS-only host that bridges SceneStore to
// SwiftUI's spatial scene actions (openWindow / openImmersiveSpace /
// dismissImmersiveSpace / dismissWindow).
// Copyright © 2026 Inno Squad. All rights reserved.

// MARK: - Platform: This host reads visionOS-specific EnvironmentValues
// (`openImmersiveSpace`, `dismissImmersiveSpace`). It therefore exists
// only on visionOS.
#if os(visionOS)

import SwiftUI

import InnoRouterCore

/// View modifier that couples a ``SceneStore`` to SwiftUI's spatial
/// scene actions.
///
/// Attach it to any view that lives inside your app's
/// `WindowGroup` / `ImmersiveSpace` hierarchy. The modifier observes
/// the store's ``SceneStore/pendingIntent`` and dispatches to
/// `@Environment(\.openWindow)` / `@Environment(\.openImmersiveSpace)`
/// etc., then calls back into the store to commit the transition.
///
/// Use the convenience wrapper ``SwiftUI/View/innoRouterSceneHost(_:windowID:)``
/// instead of instantiating the modifier directly.
public struct SceneHost<R: Route>: ViewModifier {
    @Bindable private var store: SceneStore<R>
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    private let windowID: (R) -> String

    /// Creates a scene host.
    ///
    /// - Parameters:
    ///   - store: the scene store driving this host.
    ///   - windowID: maps a route to the `id` string used by the
    ///     corresponding `WindowGroup` or `ImmersiveSpace` scene
    ///     declaration in your `App`.
    public init(store: SceneStore<R>, windowID: @escaping (R) -> String) {
        self.store = store
        self.windowID = windowID
    }

    public func body(content: Content) -> some View {
        content
            .onChange(of: store.pendingIntent) { _, newIntent in
                guard let intent = newIntent else { return }
                Task { @MainActor in
                    await handle(intent)
                }
            }
    }

    @MainActor
    private func handle(_ intent: SceneIntent<R>) async {
        switch intent {
        case .open(let presentation):
            await open(presentation)
        case .dismissImmersive:
            if let active = store.currentScene {
                await dismissImmersiveSpace()
                store.completeDismissal(of: active)
            }
        case .dismissWindow(let route):
            dismissWindow(id: windowID(route))
            if let active = store.currentScene {
                store.completeDismissal(of: active)
            }
        }
    }

    @MainActor
    private func open(_ presentation: ScenePresentation<R>) async {
        switch presentation {
        case .window(let route), .volumetric(let route, _):
            openWindow(id: windowID(route))
            store.completeOpen(presentation, accepted: true)
        case .immersive(let route, _):
            let result = await openImmersiveSpace(id: windowID(route))
            store.completeOpen(presentation, accepted: result == .opened)
        }
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
        windowID: @escaping (R) -> String
    ) -> some View {
        modifier(SceneHost(store: store, windowID: windowID))
    }
}

#endif
