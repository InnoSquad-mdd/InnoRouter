import SwiftUI

import InnoRouter
import InnoRouterMacros

@Routable
enum ProductRoute {
    case list
    case detail(id: String)
    case login
}

struct DeepLinkExampleView: View {
    @State private var store = NavStore<ProductRoute>()
    @State private var isAuthenticated = false

    var pipeline: DeepLinkPipeline<ProductRoute> {
        let matcher = DeepLinkMatcher<ProductRoute> {
            DeepLinkMapping("/products") { _ in .list }
            DeepLinkMapping("/products/:id") { params in
                params["id"].map { .detail(id: $0) }
            }
        }

        return DeepLinkPipeline(
            allowedSchemes: ["myapp", "https"],
            allowedHosts: ["myapp.com"],
            resolve: { matcher.match($0) },
            requiresAuthentication: { route in
                if case .detail = route { return true }
                return false
            },
            isAuthenticated: { isAuthenticated },
            plan: { route in NavPlan(commands: [.push(route)]) }
        )
    }

    var body: some View {
        NavigationHost(store: store) { route in
            switch route {
            case .list:
                VStack {
                    Text("Products")
                    Button("Simulate deep link /products/123") {
                        handle(url: URL(string: "myapp://myapp.com/products/123")!)
                    }
                    Button(isAuthenticated ? "Logout" : "Login") {
                        isAuthenticated.toggle()
                    }
                }
            case .detail(let id):
                Text("Detail \(id)")
            case .login:
                Text("Login")
            }
        } root: {
            Text("Root")
                .onAppear { _ = store.execute(.replace([.list])) }
        }
    }

    private func handle(url: URL) {
        switch pipeline.decide(for: url) {
        case .plan(let plan):
            Task { @MainActor in
                for command in plan.commands {
                    _ = store.execute(command)
                }
            }
        case .pending:
            _ = store.execute(.push(.login))
        case .rejected, .unhandled:
            break
        }
    }
}
