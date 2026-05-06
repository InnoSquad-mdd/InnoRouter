import Observation
import SwiftUI

import InnoRouterCore
import InnoRouterSwiftUI

private enum ProbeRoute: Route {
    case root
}

@Observable
@MainActor
private final class ProbeCoordinator: Coordinator {
    typealias RouteType = ProbeRoute
    typealias Destination = EmptyView

    let store = NavigationStore<ProbeRoute>()

    @ViewBuilder
    func destination(for route: ProbeRoute) -> EmptyView {
        EmptyView()
    }
}

@MainActor
private final class ProbeChild: ChildCoordinator {
    typealias Result = String

    var onFinish: (@MainActor @Sendable (String) -> Void)?
    var onCancel: (@MainActor @Sendable () -> Void)?
    var lifecycleSignals: LifecycleSignals = LifecycleSignals()
}

@MainActor
@main
struct ChildCoordinatorFailFastProbe {
    static func main() {
        let parent = ProbeCoordinator()
        let child = ProbeChild()

        _ = parent.push(child: child)
        _ = parent.push(child: child)
    }
}
