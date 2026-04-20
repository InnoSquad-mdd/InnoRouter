import InnoRouterCore
import SwiftUI

public enum NavigationIntent<R: Route>: Sendable, Equatable {
    case go(R)
    case goMany([R])
    case back
    case backBy(Int)
    case backTo(R)
    case backToRoot
    case resetTo([R])
    case replaceStack([R])
    case backOrPush(R)
    case pushUniqueRoot(R)
}

@MainActor
public protocol Coordinator: AnyObject, Observable {
    associatedtype RouteType: Route
    associatedtype Destination: View

    var store: NavigationStore<RouteType> { get }

    func handle(_ intent: NavigationIntent<RouteType>)
    @ViewBuilder
    func destination(for route: RouteType) -> Destination
}

public extension Coordinator {
    func handle(_ intent: NavigationIntent<RouteType>) {
        store.send(intent)
    }

    func send(_ intent: NavigationIntent<RouteType>) {
        handle(intent)
    }
}

extension Coordinator {
    var navigationIntentDispatcher: AnyNavigationIntentDispatcher<RouteType> {
        AnyNavigationIntentDispatcher { [weak self] intent in
            self?.handle(intent)
        }
    }
}

private struct CoordinatorStackHostContent<C: Coordinator, Root: View>: View {
    @Bindable private var coordinator: C
    private let root: () -> Root

    init(
        coordinator: C,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.coordinator = coordinator
        self.root = root
    }

    var body: some View {
        NavigationStack(path: coordinator.store.pathBinding) {
            root()
                .navigationDestination(for: C.RouteType.self) { route in
                    coordinator.destination(for: route)
                }
        }
    }
}

/// Hosts a stack-based coordinator surface and injects its navigation dispatcher into the environment.
public struct CoordinatorHost<C: Coordinator, Root: View>: View {
    @Bindable private var coordinator: C
    @State private var navigationEnvironmentStorage = NavigationEnvironmentStorage()
    private let root: () -> Root

    /// Creates a coordinator host with the supplied coordinator and root builder.
    public init(
        coordinator: C,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.coordinator = coordinator
        self.root = root
    }

    public var body: some View {
        CoordinatorStackHostContent(coordinator: coordinator, root: root)
        .navigationIntentDispatcher(coordinator.navigationIntentDispatcher)
        .environment(\.navigationEnvironmentStorage, navigationEnvironmentStorage)
    }
}

/// Hosts a split-view coordinator surface whose detail column is driven by the coordinator's store.
public struct CoordinatorSplitHost<C: Coordinator, Sidebar: View, Root: View>: View {
    @Bindable private var coordinator: C
    @State private var navigationEnvironmentStorage = NavigationEnvironmentStorage()
    private let sidebar: () -> Sidebar
    private let root: () -> Root

    /// Creates a split coordinator host with separate sidebar and root builders.
    public init(
        coordinator: C,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.coordinator = coordinator
        self.sidebar = sidebar
        self.root = root
    }

    public var body: some View {
        NavigationSplitView {
            sidebar()
        } detail: {
            CoordinatorStackHostContent(coordinator: coordinator, root: root)
        }
        .navigationIntentDispatcher(coordinator.navigationIntentDispatcher)
        .environment(\.navigationEnvironmentStorage, navigationEnvironmentStorage)
    }
}
