import Foundation

import InnoRouterDeepLink
import InnoRouterSwiftUI

@MainActor
public protocol DeepLinkCoordinating: Coordinator {
    var deepLinkPipeline: DeepLinkPipeline<RouteType> { get }
    var pendingDeepLink: PendingDeepLink<RouteType>? { get set }
}

public extension DeepLinkCoordinating {
    func handle(_ intent: NavigationIntent<RouteType>) {
        switch intent {
        case .deepLink(let url):
            handleDeepLink(url)

        default:
            store.send(intent)
        }
    }

    func handleDeepLink(_ url: URL) {
        switch deepLinkPipeline.decide(for: url) {
        case .rejected(_), .unhandled(_):
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
    func resumePendingDeepLinkIfPossible() -> Bool {
        guard let pendingDeepLink else { return false }
        switch deepLinkPipeline.authenticationPolicy {
        case .notRequired:
            break

        case .required(let shouldRequireAuthentication, let isAuthenticated):
            if shouldRequireAuthentication(pendingDeepLink.route), !isAuthenticated() {
                return false
            }
        }

        // Safe to clear first: we iterate on the local `pendingDeepLink` constant, not the stored property.
        self.pendingDeepLink = nil
        for command in pendingDeepLink.plan.commands {
            _ = store.execute(command)
        }
        return true
    }
}
