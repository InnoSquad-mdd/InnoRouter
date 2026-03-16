import SwiftUI

import InnoRouterCore

private struct NavigationStackHostContent<R: Route, DestinationView: View, Root: View>: View {
    @Bindable private var store: NavigationStore<R>
    private let destination: (R) -> DestinationView
    private let root: () -> Root

    init(
        store: NavigationStore<R>,
        @ViewBuilder destination: @escaping (R) -> DestinationView,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.store = store
        self.destination = destination
        self.root = root
    }

    var body: some View {
        NavigationStack(path: store.pathBinding) {
            root()
                .navigationDestination(for: R.self) { route in
                    destination(route)
                }
        }
    }
}

/// Hosts a stack-based navigation surface backed by a `NavigationStore`.
public struct NavigationHost<R: Route, DestinationView: View, Root: View>: View {
    @Bindable private var store: NavigationStore<R>
    @State private var navigationEnvironmentStorage = NavigationEnvironmentStorage()
    private let destination: (R) -> DestinationView
    private let root: () -> Root

    /// Creates a navigation host with destination and root builders.
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
        NavigationStackHostContent(store: navigationStore, destination: destination, root: root)
        .navigationIntentDispatcher(
            AnyNavigationIntentDispatcher { intent in
                navigationStore.send(intent)
            }
        )
        .environment(\.navigationEnvironmentStorage, navigationEnvironmentStorage)
    }
}

/// Hosts a split-view navigation surface whose detail column is driven by a `NavigationStore`.
public struct NavigationSplitHost<R: Route, Sidebar: View, DestinationView: View, Root: View>: View {
    @Bindable private var store: NavigationStore<R>
    @State private var navigationEnvironmentStorage = NavigationEnvironmentStorage()
    private let sidebar: () -> Sidebar
    private let destination: (R) -> DestinationView
    private let root: () -> Root

    /// Creates a split navigation host with separate sidebar, destination, and root builders.
    public init(
        store: NavigationStore<R>,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder destination: @escaping (R) -> DestinationView,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.store = store
        self.sidebar = sidebar
        self.destination = destination
        self.root = root
    }

    public var body: some View {
        let navigationStore = store
        NavigationSplitView {
            sidebar()
        } detail: {
            NavigationStackHostContent(
                store: navigationStore,
                destination: destination,
                root: root
            )
        }
        .navigationIntentDispatcher(
            AnyNavigationIntentDispatcher { intent in
                navigationStore.send(intent)
            }
        )
        .environment(\.navigationEnvironmentStorage, navigationEnvironmentStorage)
    }
}
