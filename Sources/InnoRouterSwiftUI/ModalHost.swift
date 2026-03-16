import SwiftUI

import InnoRouterCore

public struct ModalHost<M: Route, Destination: View, Content: View>: View {
    @Bindable private var store: ModalStore<M>
    @State private var modalEnvironmentStorage = ModalEnvironmentStorage()
    private let destination: (M) -> Destination
    private let content: () -> Content

    public init(
        store: ModalStore<M>,
        @ViewBuilder destination: @escaping (M) -> Destination,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.store = store
        self.destination = destination
        self.content = content
    }

    public var body: some View {
        let modalStore = store

        Group {
#if os(iOS) || os(tvOS)
            content()
                .sheet(item: modalStore.binding(for: .sheet)) { presentation in
                    destination(presentation.route)
                }
                .fullScreenCover(item: modalStore.binding(for: .fullScreenCover)) { presentation in
                    destination(presentation.route)
                }
#else
            content()
                .sheet(item: modalStore.binding(for: [.sheet, .fullScreenCover])) { presentation in
                    destination(presentation.route)
                }
#endif
        }
            .modalIntentDispatcher(
                AnyModalIntentDispatcher { intent in
                    modalStore.send(intent)
                }
            )
            .environment(\.modalEnvironmentStorage, modalEnvironmentStorage)
    }
}
