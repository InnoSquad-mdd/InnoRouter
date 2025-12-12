import SwiftUI

import InnoRouter
import InnoRouterMacros

@Routable
enum AppRoute {
    case home
    case auth
}

@Routable
enum HomeRoute {
    case dashboard
    case profile
}

@Observable
@MainActor
final class AppCoordinator: Coordinator {
    typealias RouteType = AppRoute
    typealias Destination = AnyView

    let store = NavStore<AppRoute>()
    var isAuthenticated = false

    func handle(_ intent: NavIntent<AppRoute>) {
        switch intent {
        case .go(let route):
            switch route {
            case .home:
                _ = store.execute(.replace([.home]))
            case .auth:
                _ = store.execute(.replace([.auth]))
            }
        default:
            break
        }
    }

    @ViewBuilder
    func destination(for route: AppRoute) -> AnyView {
        switch route {
        case .home:
            AnyView(Text("Home Root"))
        case .auth:
            AnyView(Text("Auth Root"))
        }
    }
}

struct CoordinatorExampleView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        CoordinatorHost(coordinator: coordinator) {
            VStack(spacing: 12) {
                Button("Go Auth") { coordinator.navigate(to: .auth) }
                Button("Go Home") { coordinator.navigate(to: .home) }
            }
            .padding()
        }
    }
}
