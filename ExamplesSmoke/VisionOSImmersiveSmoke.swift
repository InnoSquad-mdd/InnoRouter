#if os(visionOS)
import SwiftUI

import InnoRouter

enum VisionOSSmokeRoute: String, Route {
    case main
    case theatre
}

@MainActor
func visionOSImmersiveSmoke() {
    let store = SceneStore<VisionOSSmokeRoute>()
    let scenes: SceneRegistry<VisionOSSmokeRoute> = .init(
        .window(.main, id: VisionOSSmokeRoute.main.rawValue),
        .immersive(.theatre, id: VisionOSSmokeRoute.theatre.rawValue, style: .mixed)
    )
    let mainWindow = store.openWindow(.main)
    store.dismissWindow(mainWindow)
    store.openImmersive(.theatre, style: .mixed)
    store.dismissImmersive()
    _ = store.events
    _ = store.activeScenes
    _ = EmptyView()
        .innoRouterSceneAnchor(store, scenes: scenes, attachedTo: .main, instanceID: UUID())
        .innoRouterSceneHost(store, scenes: scenes)
    _ = EmptyView().innoRouterSceneAnchor(store, scenes: scenes, attachedTo: .theatre)

    // Ornament modifier is cross-platform; reference it here to keep
    // the symbol exercised in the smoke target.
    _ = EmptyView().innoRouterOrnament(OrnamentAnchor(anchor: .bottom)) {
        Text("Ornament")
    }
}
#endif
