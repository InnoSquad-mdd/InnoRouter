import Foundation
import SwiftUI

import InnoRouterCore

@MainActor
final class NavigationEnvironmentStorage {
    private var intentDispatchers: [ObjectIdentifier: Any] = [:]

    init() {}

    subscript<R: Route>(routeType: R.Type) -> AnyNavigationIntentDispatcher<R>? {
        get {
            return intentDispatchers[ObjectIdentifier(routeType)] as? AnyNavigationIntentDispatcher<R>
        }
        set {
            let key = ObjectIdentifier(routeType)
            let existing = intentDispatchers[key] as? AnyNavigationIntentDispatcher<R>
            reportDuplicateDispatcherIfNeeded(
                existing: existing,
                replacement: newValue,
                keyDescription: "AnyNavigationIntentDispatcher<\(String(describing: routeType))>"
            )
            intentDispatchers[key] = newValue
        }
    }
}

extension EnvironmentValues {
    @Entry var navigationEnvironmentStorage: NavigationEnvironmentStorage?
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

/// Type-erased dispatcher used to publish ``NavigationIntent`` values through
/// the SwiftUI environment.
///
/// The dispatcher is `@MainActor`-isolated. ``NavigationIntent`` itself is
/// `Sendable` because `Route` conforms to `Sendable`; the closure stored here
/// is annotated `@Sendable` so the dispatcher can be safely captured from
/// detached tasks before the eventual hop back to the main actor.
@MainActor
public final class AnyNavigationIntentDispatcher<R: Route>: NavigationIntentDispatching {
    public typealias RouteType = R

    private let sendIntent: @MainActor @Sendable (NavigationIntent<R>) -> Void

    public init(send: @escaping @MainActor @Sendable (NavigationIntent<R>) -> Void) {
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
    @Environment(\.innoRouterEnvironmentMissingPolicy) private var environmentMissingPolicy
    private let routeType: R.Type

    public init(_ routeType: R.Type) {
        self.routeType = routeType
    }

    public var wrappedValue: AnyNavigationIntentDispatcher<R> {
        if let dispatcher = navigationEnvironmentStorage?[R.self] {
            return dispatcher
        }
        if navigationEnvironmentStorage == nil {
            handleMissingEnvironment(policy: environmentMissingPolicy) {
                "NavigationEnvironmentStorage is missing for \(String(describing: routeType)). " +
                "Attach this view inside NavigationHost or CoordinatorHost."
            }
        } else {
            handleMissingEnvironment(policy: environmentMissingPolicy) {
                "AnyNavigationIntentDispatcher is missing for \(String(describing: routeType)). " +
                "Ensure the matching NavigationHost or CoordinatorHost is in the environment hierarchy."
            }
        }
        return AnyNavigationIntentDispatcher<R> { _ in /* no-op placeholder */ }
    }
}
