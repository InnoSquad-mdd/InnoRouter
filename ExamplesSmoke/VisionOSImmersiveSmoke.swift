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
    store.openImmersive(.theatre, style: .mixed)
    store.dismissImmersive()
    _ = store.events

    // Ornament modifier is cross-platform; reference it here to keep
    // the symbol exercised in the smoke target.
    _ = EmptyView().innoRouterOrnament(OrnamentAnchor(anchor: .bottom)) {
        Text("Ornament")
    }
}
#endif
