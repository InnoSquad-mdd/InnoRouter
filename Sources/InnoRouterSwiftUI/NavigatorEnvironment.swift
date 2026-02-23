import Foundation
import SwiftUI

import InnoRouterCore

struct NavigationEnvironmentStorageKey: EnvironmentKey {
    static let defaultValue: NavigationEnvironmentStorage? = nil
}

@MainActor
final class NavigationEnvironmentStorage {
    private var intentDispatchers: [ObjectIdentifier: Any] = [:]

    init() {}

    subscript<R: Route>(routeType: R.Type) -> AnyNavigationIntentDispatcher<R>? {
        get {
            return intentDispatchers[ObjectIdentifier(routeType)] as? AnyNavigationIntentDispatcher<R>
        }
        set {
            intentDispatchers[ObjectIdentifier(routeType)] = newValue
        }
    }
}

extension EnvironmentValues {
    var navigationEnvironmentStorage: NavigationEnvironmentStorage? {
        get { self[NavigationEnvironmentStorageKey.self] }
        set { self[NavigationEnvironmentStorageKey.self] = newValue }
    }
}

extension View {
    @MainActor
    func navigationIntentDispatcher<R: Route>(_ dispatcher: AnyNavigationIntentDispatcher<R>) -> some View {
        transformEnvironment(\.navigationEnvironmentStorage) { storage in
            guard let storage else {
                assertionFailure(
                    "NavigationEnvironmentStorage is missing. Attach this view inside NavigationHost or CoordinatorHost."
                )
                return
            }
            storage[R.self] = dispatcher
        }
    }
}

@MainActor
public protocol NavigationIntentDispatching: AnyObject {
    associatedtype RouteType: Route
    func send(_ intent: NavigationIntent<RouteType>)
}

@MainActor
public final class AnyNavigationIntentDispatcher<R: Route>: NavigationIntentDispatching {
    public typealias RouteType = R

    private let sendIntent: @MainActor (NavigationIntent<R>) -> Void

    public init(send: @escaping @MainActor (NavigationIntent<R>) -> Void) {
        self.sendIntent = send
    }

    public func send(_ intent: NavigationIntent<R>) {
        sendIntent(intent)
    }
}

@MainActor
@propertyWrapper
public struct EnvironmentNavigationIntent<R: Route>: DynamicProperty {
    @Environment(\.navigationEnvironmentStorage) private var navigationEnvironmentStorage
    private let routeType: R.Type

    public init(_ routeType: R.Type) {
        self.routeType = routeType
    }

    public var wrappedValue: AnyNavigationIntentDispatcher<R> {
        guard let navigationEnvironmentStorage else {
            preconditionFailure(
                "NavigationEnvironmentStorage is missing for \(String(describing: routeType)). " +
                "Attach this view inside NavigationHost or CoordinatorHost."
            )
        }
        guard let dispatcher = navigationEnvironmentStorage[R.self] else {
            preconditionFailure(
                "AnyNavigationIntentDispatcher is missing for \(String(describing: routeType)). " +
                "Ensure the matching NavigationHost or CoordinatorHost is in the environment hierarchy."
            )
        }
        return dispatcher
    }
}
