// MARK: - SceneStore.swift
// InnoRouterSwiftUI — visionOS-only store for spatial scene presentations.
// Copyright © 2026 Inno Squad. All rights reserved.

// MARK: - Platform: Spatial scene intents (open window / open immersive
// space / dismiss immersive space) are only available on visionOS via
// SwiftUI's EnvironmentValues. The store therefore exists only on
// visionOS; consumers on other platforms should compile scene logic
// behind their own `#if os(visionOS)` branch.
#if os(visionOS)

import Foundation
import Observation
import SwiftUI

import InnoRouterCore

/// Lifecycle event emitted by ``SceneStore``.
///
/// Subscribers reach these through ``SceneStore/events``. The event
/// taxonomy is intentionally minimal — InnoRouter only observes outcomes
/// the SwiftUI environment actually reports, and leaves deeper
/// instrumentation to app telemetry.
public enum SceneEvent<R: Route>: Sendable, Equatable {
    /// A scene was successfully presented.
    case presented(ScenePresentation<R>)

    /// A scene was dismissed.
    case dismissed(ScenePresentation<R>)

    /// An open request was rejected (typically because the SwiftUI
    /// environment reported a non-`.opened` result, e.g. the immersive
    /// space could not be opened).
    case rejected(ScenePresentation<R>, reason: SceneRejectionReason)
}

/// Reason a ``SceneStore`` open/dismiss intent was rejected.
public enum SceneRejectionReason: String, Sendable, Equatable, Codable {
    /// The SwiftUI environment returned a non-success result (for example
    /// `OpenImmersiveSpaceAction.Result.userCancelled` or `.error`).
    case environmentReturnedFailure

    /// The store was asked to dismiss when nothing was active.
    case nothingActive
}

/// Intent queued by ``SceneStore`` for a ``SceneHost`` to act on.
///
/// The store doesn't call SwiftUI's `openWindow` / `openImmersiveSpace`
/// actions directly — those are only accessible from a view's
/// environment. Instead the store publishes an intent here and a
/// ``SceneHost`` view observes it and dispatches.
public enum SceneIntent<R: Route>: Sendable, Equatable {
    /// Open the given spatial presentation.
    case open(ScenePresentation<R>)

    /// Dismiss the currently active immersive space.
    case dismissImmersive

    /// Dismiss the window identified by `route`.
    case dismissWindow(R)
}

/// Store that coordinates spatial scene presentations on visionOS.
///
/// ``SceneStore`` owns the app's current spatial scene (a window, a
/// volumetric window, or an immersive space) and publishes open/dismiss
/// intents that a ``SceneHost`` view translates into SwiftUI environment
/// actions (`openWindow`, `openImmersiveSpace`,
/// `dismissImmersiveSpace`, `dismissWindow`).
///
/// Usage sketch:
///
/// ```swift
/// @main
/// struct MyApp: App {
///     @State private var sceneStore = SceneStore<SpatialRoute>()
///
///     var body: some Scene {
///         WindowGroup(id: "main") {
///             MainView()
///                 .innoRouterSceneHost(sceneStore) { $0.rawValue }
///         }
///         ImmersiveSpace(id: SpatialRoute.theatre.rawValue) {
///             TheatreView()
///         }
///     }
/// }
/// ```
@MainActor
@Observable
public final class SceneStore<R: Route> {
    /// Currently active scene presentation, or `nil` if none.
    public private(set) var currentScene: ScenePresentation<R>?

    /// Next intent the host should act on. The host clears this field via
    /// ``completeOpen(_:accepted:)`` / ``completeDismissal(_:)`` after
    /// dispatching the corresponding SwiftUI environment action.
    public fileprivate(set) var pendingIntent: SceneIntent<R>?

    @ObservationIgnored
    private let broadcaster: EventBroadcaster<SceneEvent<R>>

    /// Creates an empty scene store.
    public init() {
        self.broadcaster = EventBroadcaster()
    }

    /// Async stream of every ``SceneEvent`` emitted by this store.
    public var events: AsyncStream<SceneEvent<R>> {
        broadcaster.stream()
    }

    /// Requests that the host open a regular window for `route`.
    public func openWindow(_ route: R) {
        pendingIntent = .open(.window(route))
    }

    /// Requests that the host open a volumetric window for `route`.
    public func openVolumetric(_ route: R, size: VolumetricSize? = nil) {
        pendingIntent = .open(.volumetric(route, size: size))
    }

    /// Requests that the host open an immersive space for `route`.
    public func openImmersive(_ route: R, style: ImmersiveStyle) {
        pendingIntent = .open(.immersive(route, style: style))
    }

    /// Requests that the host dismiss the active immersive space.
    public func dismissImmersive() {
        guard currentScene != nil else {
            broadcaster.broadcast(
                .rejected(.immersive(placeholderRoute, style: .mixed), reason: .nothingActive)
            )
            return
        }
        pendingIntent = .dismissImmersive
    }

    /// Requests that the host dismiss the window carrying `route`.
    public func dismissWindow(_ route: R) {
        pendingIntent = .dismissWindow(route)
    }

    /// Called by ``SceneHost`` after it has issued the matching SwiftUI
    /// environment action for an `.open(_:)` intent. `accepted` reports
    /// whether the action succeeded.
    public func completeOpen(_ presentation: ScenePresentation<R>, accepted: Bool) {
        pendingIntent = nil
        if accepted {
            currentScene = presentation
            broadcaster.broadcast(.presented(presentation))
        } else {
            broadcaster.broadcast(.rejected(presentation, reason: .environmentReturnedFailure))
        }
    }

    /// Called by ``SceneHost`` after it has issued a dismissal.
    public func completeDismissal(of presentation: ScenePresentation<R>) {
        pendingIntent = nil
        currentScene = nil
        broadcaster.broadcast(.dismissed(presentation))
    }

    /// Placeholder route used only to shape a rejection event when the
    /// store has nothing active to dismiss. Never emitted as a real
    /// presentation.
    private var placeholderRoute: R {
        // `SceneStore` cannot synthesise an arbitrary `R`, so we capture
        // the most recent one. If none is available this branch is
        // unreachable (the guard above catches it).
        if let scene = currentScene {
            switch scene {
            case .window(let r), .volumetric(let r, _), .immersive(let r, _):
                return r
            }
        }
        fatalError("SceneStore.dismissImmersive placeholder unreachable")
    }

    isolated deinit {
        // EventBroadcaster's own isolated deinit will finish continuations.
        _ = broadcaster
    }
}

#endif
