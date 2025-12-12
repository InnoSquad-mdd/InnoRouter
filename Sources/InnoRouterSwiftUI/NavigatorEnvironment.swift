import SwiftUI

import InnoRouterCore

struct NavigatorKey: EnvironmentKey {
    static let defaultValue: NavigatorStorage = NavigatorStorage()
}

final class NavigatorStorage: @unchecked Sendable {
    private var navigators: [ObjectIdentifier: Any] = [:]
    private let lock = NSLock()

    init() {}

    subscript<R: Route>(routeType: R.Type) -> AnyNavigator<R>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return navigators[ObjectIdentifier(routeType)] as? AnyNavigator<R>
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            navigators[ObjectIdentifier(routeType)] = newValue
        }
    }
}

extension EnvironmentValues {
    var navigatorStorage: NavigatorStorage {
        get { self[NavigatorKey.self] }
        set { self[NavigatorKey.self] = newValue }
    }
}

public extension View {
    func navigator<R: Route>(_ navigator: AnyNavigator<R>) -> some View {
        transformEnvironment(\.navigatorStorage) { storage in
            storage[R.self] = navigator
        }
    }

    func navigator<R: Route>(_ store: NavStore<R>) -> some View {
        navigator(AnyNavigator(store))
    }
}

@propertyWrapper
public struct UseNavigator<R: Route>: DynamicProperty {
    @Environment(\.navigatorStorage) private var navigatorStorage

    public init(_ routeType: R.Type) {}

    public var wrappedValue: AnyNavigator<R>? {
        navigatorStorage[R.self]
    }
}
