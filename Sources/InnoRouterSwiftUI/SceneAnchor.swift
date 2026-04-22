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
    @State private var attachedPresentation: ScenePresentation<R>?
    private let scenes: SceneRegistry<R>
    private let attachedTo: R
    private let instanceID: UUID?

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
        self.init(
            store: store,
            scenes: scenes,
            attachedTo: attachedTo,
            instanceID: nil
        )
    }

    /// Creates a scene anchor for a specific window instance.
    ///
    /// Pass the value supplied by `WindowGroup(id:for:...)` so each
    /// window or volumetric root can reconcile the exact instance that
    /// SwiftUI opened.
    public init(
        store: SceneStore<R>,
        scenes: SceneRegistry<R>,
        attachedTo: R,
        instanceID: UUID
    ) {
        self.init(
            store: store,
            scenes: scenes,
            attachedTo: attachedTo,
            instanceID: Optional(instanceID)
        )
    }

    private init(
        store: SceneStore<R>,
        scenes: SceneRegistry<R>,
        attachedTo: R,
        instanceID: UUID?
    ) {
        guard let declaration = scenes.declaration(for: attachedTo) else {
            preconditionFailure(
                "SceneAnchor requires attachedTo to be declared in scenes. Missing route: \(String(describing: attachedTo))"
            )
        }
        if instanceID == nil {
            switch declaration.kind {
            case .window, .volumetric:
                preconditionFailure(
                    "SceneAnchor for window or volumetric scenes requires an instanceID. " +
                    "Declare the scene with WindowGroup(id:for:defaultValue:) and use " +
                    ".innoRouterSceneAnchor(_:scenes:attachedTo:instanceID:)."
                )
            case .immersive:
                break
            }
        }

        self.store = store
        self.scenes = scenes
        self.attachedTo = attachedTo
        self.instanceID = instanceID
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                attachedPresentation = store.attachDeclaredScene(
                    route: attachedTo,
                    scenes: scenes,
                    instanceID: instanceID
                )
                store.registerFallbackDispatcher(dispatcherToken)
                Task { @MainActor in
                    await dispatchPendingRequests()
                }
            }
            .onDisappear {
                if let attachedPresentation {
                    store.detachDeclaredScene(attachedPresentation)
                    self.attachedPresentation = nil
                }
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
            capability: .fallbackAnchor(attachedTo: attachedPresentation),
            openWindow: { id, value in openWindow(id: id, value: value) },
            openImmersiveSpace: { id in await openImmersiveSpace(id: id) },
            dismissImmersiveSpace: { await dismissImmersiveSpace() },
            dismissWindow: { id, value in dismissWindow(id: id, value: value) }
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
    /// only behind `#if os(visionOS)`. This overload is for immersive
    /// spaces; windows and volumetric scenes must use the `instanceID`
    /// overload.
    func innoRouterSceneAnchor<R: Route>(
        _ store: SceneStore<R>,
        scenes: SceneRegistry<R>,
        attachedTo: R
    ) -> some View {
        modifier(SceneAnchor(store: store, scenes: scenes, attachedTo: attachedTo))
    }

    /// Attaches a ``SceneAnchor`` to a specific window or volumetric
    /// instance using the `UUID` supplied by a value-based `WindowGroup`.
    func innoRouterSceneAnchor<R: Route>(
        _ store: SceneStore<R>,
        scenes: SceneRegistry<R>,
        attachedTo: R,
        instanceID: UUID
    ) -> some View {
        modifier(
            SceneAnchor(
                store: store,
                scenes: scenes,
                attachedTo: attachedTo,
                instanceID: instanceID
            )
        )
    }
}

#endif
