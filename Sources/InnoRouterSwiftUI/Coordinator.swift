import Foundation
import SwiftUI

import InnoRouterCore

public enum NavigationIntent<R: Route>: Sendable, Equatable {
    case go(R)
    case goMany([R])
    case back
    case backBy(Int)
    case backTo(R)
    case backToRoot
    case resetTo([R])
    case deepLink(URL)
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

public extension NavigationStore {
    func send(_ intent: NavigationIntent<R>) {
        switch intent {
        case .go(let route):
            _ = execute(.push(route))

        case .goMany(let routes):
            guard !routes.isEmpty else { return }
            let commands = routes.map { NavigationCommand<R>.push($0) }
            _ = execute(.sequence(commands))

        case .back:
            _ = execute(.pop)

        case .backBy(let count):
            _ = execute(.popCount(count))

        case .backTo(let route):
            _ = execute(.popTo(route))

        case .backToRoot:
            _ = execute(.popToRoot)

        case .resetTo(let routes):
            _ = execute(.replace(routes))

        case .deepLink:
            break
        }
    }
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

public struct CoordinatorHost<C: Coordinator, Root: View>: View {
    @Bindable private var coordinator: C
    @State private var navigationEnvironmentStorage = NavigationEnvironmentStorage()
    private let root: () -> Root

    public init(
        coordinator: C,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.coordinator = coordinator
        self.root = root
    }

    public var body: some View {
        NavigationStack(path: coordinator.store.pathBinding) {
            root()
                .navigationDestination(for: C.RouteType.self) { route in
                    coordinator.destination(for: route)
                }
        }
        .environment(\.navigationEnvironmentStorage, navigationEnvironmentStorage)
        .navigationIntentDispatcher(coordinator.navigationIntentDispatcher)
    }
}
