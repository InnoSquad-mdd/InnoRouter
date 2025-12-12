import Foundation
import SwiftUI

import InnoRouterCore

public enum NavIntent<R: Route>: Sendable, Equatable {
    case go(R)
    case back
    case resetTo([R])
    case deepLink(URL)
}

@MainActor
public protocol Coordinator: AnyObject, Observable {
    associatedtype RouteType: Route
    associatedtype Destination: View

    var store: NavStore<RouteType> { get }

    func handle(_ intent: NavIntent<RouteType>)
    @ViewBuilder
    func destination(for route: RouteType) -> Destination
}

public extension Coordinator {
    var navigator: AnyNavigator<RouteType> { AnyNavigator(store) }

    func handle(_ intent: NavIntent<RouteType>) {
        switch intent {
        case .go(let route):
            _ = store.execute(.push(route))

        case .back:
            _ = store.execute(.pop)

        case .resetTo(let routes):
            _ = store.execute(.replace(routes))

        case .deepLink:
            break
        }
    }

    func navigate(to route: RouteType) {
        handle(.go(route))
    }

    @discardableResult
    func execute(_ command: NavCommand<RouteType>) -> NavResult<RouteType> {
        store.execute(command)
    }

    func goBack() {
        _ = store.execute(.pop)
    }

    func goToRoot() {
        _ = store.execute(.popToRoot)
    }
}

@MainActor
public final class AnyCoordinator<R: Route>: Coordinator {
    public typealias RouteType = R
    public typealias Destination = AnyView

    private let _store: () -> NavStore<R>
    private let _handle: (NavIntent<R>) -> Void
    private let _destination: (R) -> AnyView

    public var store: NavStore<R> { _store() }

    public init<C: Coordinator>(_ coordinator: C) where C.RouteType == R {
        self._store = { coordinator.store }
        self._handle = { coordinator.handle($0) }
        self._destination = { AnyView(coordinator.destination(for: $0)) }
    }

    public func handle(_ intent: NavIntent<R>) {
        _handle(intent)
    }

    @ViewBuilder
    public func destination(for route: R) -> AnyView {
        _destination(route)
    }
}

public struct CoordinatorHost<C: Coordinator, Root: View>: View {
    @Bindable private var coordinator: C
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
        .navigator(coordinator.store)
    }
}

