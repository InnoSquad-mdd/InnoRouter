import Foundation

import InnoRouterDeepLink
import InnoRouterSwiftUI

@MainActor
public protocol DeepLinkCoordinating: Coordinator {
    var deepLinkPipeline: DeepLinkPipeline<RouteType> { get }
    var pendingDeepLink: PendingNav<RouteType>? { get set }
}

public extension DeepLinkCoordinating {
    func handle(_ intent: NavIntent<RouteType>) {
        switch intent {
        case .go(let route):
            _ = store.execute(.push(route))

        case .back:
            _ = store.execute(.pop)

        case .resetTo(let routes):
            _ = store.execute(.replace(routes))

        case .deepLink(let url):
            handleDeepLink(url)
        }
    }

    func handleDeepLink(_ url: URL) {
        switch deepLinkPipeline.decide(for: url) {
        case .rejected, .unhandled:
            break

        case .pending(let pending):
            pendingDeepLink = pending

        case .plan(let plan):
            pendingDeepLink = nil
            for command in plan.commands {
                _ = store.execute(command)
            }
        }
    }

    @discardableResult
    func handlePendingDeepLinkIfPossible() -> Bool {
        guard let pendingDeepLink else { return false }
        guard let isAuthenticated = deepLinkPipeline.isAuthenticated, isAuthenticated() else { return false }

        let plan = deepLinkPipeline.plan(pendingDeepLink.route)
        self.pendingDeepLink = nil
        for command in plan.commands {
            _ = store.execute(command)
        }
        return true
    }
}

