import SwiftUI

import InnoRouterCore
import InnoRouterSwiftUI

private enum ProbeRoute: Route {
    case root
}

private struct ProbeView: View {
    @EnvironmentNavigationIntent(ProbeRoute.self) private var navigationIntent

    var body: some View {
        // Intentionally triggers fail-fast when host injection is missing.
        _ = navigationIntent
        return EmptyView()
    }
}

@MainActor
@main
struct NavigationEnvironmentFailFastProbe {
    static func main() {
        _ = ProbeView().body
    }
}
