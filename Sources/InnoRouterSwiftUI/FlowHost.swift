import SwiftUI

import InnoRouterCore

/// Hosts a unified flow surface combining push-based navigation and modal
/// presentation, backed by a `FlowStore`.
///
/// `FlowHost` composes the existing `NavigationHost` and `ModalHost` views
/// around the store's inner navigation / modal stores, and injects an
/// `AnyFlowIntentDispatcher` into the environment so descendants can dispatch
/// `FlowIntent` values via `@EnvironmentFlowIntent`.
public struct FlowHost<R: Route, Destination: View, Root: View>: View {
    @Bindable private var store: FlowStore<R>
    @State private var flowEnvironmentStorage = FlowEnvironmentStorage()
    private let destination: (R) -> Destination
    private let root: () -> Root

    /// Creates a flow host with destination and root builders.
    public init(
        store: FlowStore<R>,
        @ViewBuilder destination: @escaping (R) -> Destination,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.store = store
        self.destination = destination
        self.root = root
    }

    public var body: some View {
        let flowStore = store

        ModalHost(store: flowStore.modalStore, destination: destination) {
            NavigationHost(store: flowStore.navigationStore, destination: destination, root: root)
        }
        .flowIntentDispatcher(
            AnyFlowIntentDispatcher { intent in
                flowStore.send(intent)
            }
        )
        .environment(\.flowEnvironmentStorage, flowEnvironmentStorage)
    }
}
