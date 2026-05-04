import SwiftUI

import InnoRouter
import InnoRouterMacros

@Routable
enum HomeRoute {
    case list
    case detail(id: String)
    case settings
}

struct StandaloneExampleView: View {
    @State private var store = NavigationStore<HomeRoute>()

    var body: some View {
        NavigationHost(store: store) { route in
            switch route {
            case .list:
                HomeListView()
            case .detail(let id):
                Text("Detail \(id)")
            case .settings:
                Text("Settings")
            }
        } root: {
            HomeListView()
        }
    }
}

struct HomeListView: View {
    @EnvironmentNavigationIntent(HomeRoute.self) private var navigationIntent

    var body: some View {
        List {
            Button("Go Detail") {
                navigationIntent(.go(.detail(id: "123")))
            }
            Button("Go Settings") {
                navigationIntent(.go(.settings))
            }
        }
        .navigationTitle("Home")
    }
}
