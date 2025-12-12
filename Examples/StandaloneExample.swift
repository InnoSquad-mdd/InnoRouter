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
    @State private var store = NavStore<HomeRoute>()

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

private struct HomeListView: View {
    @UseNavigator(HomeRoute.self) private var navigator

    var body: some View {
        List {
            Button("Go Detail") {
                navigator?.push(.detail(id: "123"))
            }
            Button("Go Settings") {
                navigator?.push(.settings)
            }
        }
        .navigationTitle("Home")
    }
}
