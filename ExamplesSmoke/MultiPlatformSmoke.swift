import SwiftUI

import InnoRouter

enum MultiPlatformSmokeRoute: Route {
    case inbox
    case message(id: String)
    case preferences
}

@MainActor
func buildMultiPlatformSmokeHost() -> some View {
    let store = NavigationStore<MultiPlatformSmokeRoute>()
    #if !os(watchOS)
    return NavigationSplitHost(store: store) {
        Text("Sidebar")
    } destination: { route in
        switch route {
        case .inbox: Text("Inbox")
        case .message(let id): Text("Message \(id)")
        case .preferences: Text("Preferences")
        }
    } root: {
        Text("Select")
    }
    #else
    return NavigationHost(store: store) { route in
        switch route {
        case .inbox: Text("Inbox")
        case .message(let id): Text("Message \(id)")
        case .preferences: Text("Preferences")
        }
    } root: {
        Text("Inbox")
    }
    #endif
}
