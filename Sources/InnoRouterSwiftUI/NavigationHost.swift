import SwiftUI

import InnoRouterCore

public struct NavigationHost<R: Route, DestinationView: View, Root: View>: View {
    @Bindable private var store: NavigationStore<R>
    @State private var navigationEnvironmentStorage = NavigationEnvironmentStorage()
    private let destination: (R) -> DestinationView
    private let root: () -> Root

    public init(
        store: NavigationStore<R>,
        @ViewBuilder destination: @escaping (R) -> DestinationView,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.store = store
        self.destination = destination
        self.root = root
    }

    public var body: some View {
        let navigationStore = store
        NavigationStack(path: store.pathBinding) {
            root()
                .navigationDestination(for: R.self) { route in
                    destination(route)
                }
        }
        .environment(\.navigationEnvironmentStorage, navigationEnvironmentStorage)
        .navigationIntentDispatcher(
            AnyNavigationIntentDispatcher { intent in
                navigationStore.send(intent)
            }
        )
    }
}
