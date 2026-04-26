import Foundation
import SwiftUI

import InnoRouterCore

@MainActor
final class ModalEnvironmentStorage {
    private var intentDispatchers: [ObjectIdentifier: Any] = [:]

    init() {}

    subscript<M: Route>(routeType: M.Type) -> AnyModalIntentDispatcher<M>? {
        get {
            let registration = intentDispatchers[ObjectIdentifier(routeType)]
                as? DispatcherRegistration<AnyModalIntentDispatcher<M>>
            return registration?.dispatcher
        }
        set {
            setIntentDispatcher(
                newValue,
                ownerID: newValue.map(ObjectIdentifier.init),
                routeType: routeType
            )
        }
    }

    func setIntentDispatcher<M: Route>(
        _ dispatcher: AnyModalIntentDispatcher<M>?,
        ownerID: ObjectIdentifier?,
        routeType: M.Type
    ) {
        let key = ObjectIdentifier(routeType)
        let existing = intentDispatchers[key]
            as? DispatcherRegistration<AnyModalIntentDispatcher<M>>
        let replacement = dispatcher.map {
            DispatcherRegistration(
                dispatcher: $0,
                ownerID: ownerID ?? ObjectIdentifier($0)
            )
        }
        reportDuplicateDispatcherIfNeeded(
            existing: existing,
            replacement: replacement,
            keyDescription: "AnyModalIntentDispatcher<\(String(describing: routeType))>"
        )
        if let replacement {
            intentDispatchers[key] = replacement
        } else {
            intentDispatchers.removeValue(forKey: key)
        }
    }
}

extension EnvironmentValues {
    @Entry var modalEnvironmentStorage: ModalEnvironmentStorage?
}

extension View {
    @MainActor
    func modalIntentDispatcher<M: Route>(
        _ dispatcher: AnyModalIntentDispatcher<M>,
        owner: AnyObject
    ) -> some View {
        transformEnvironment(\.modalEnvironmentStorage) { storage in
            guard let storage else {
                assertionFailure(
                    "ModalEnvironmentStorage is missing. Attach this view inside ModalHost."
                )
                return
            }
            storage.setIntentDispatcher(
                dispatcher,
                ownerID: ObjectIdentifier(owner),
                routeType: M.self
            )
        }
    }
}

@MainActor
public protocol ModalIntentDispatching: AnyObject {
    associatedtype RouteType: Route
    func send(_ intent: ModalIntent<RouteType>)
}

/// Type-erased dispatcher used to publish ``ModalIntent`` values through the
/// SwiftUI environment.
///
/// The dispatcher is `@MainActor`-isolated. ``ModalIntent`` itself is
/// `Sendable` because `Route` conforms to `Sendable`; the closure stored here
/// is annotated `@Sendable` so the dispatcher can be safely captured from
/// detached tasks before the eventual hop back to the main actor.
@MainActor
public final class AnyModalIntentDispatcher<M: Route>: ModalIntentDispatching {
    public typealias RouteType = M

    private let sendIntent: @MainActor @Sendable (ModalIntent<M>) -> Void

    public init(send: @escaping @MainActor @Sendable (ModalIntent<M>) -> Void) {
        self.sendIntent = send
    }

    public func send(_ intent: ModalIntent<M>) {
        sendIntent(intent)
    }
}

@MainActor
@propertyWrapper
public struct EnvironmentModalIntent<M: Route>: DynamicProperty {
    @Environment(\.modalEnvironmentStorage) private var modalEnvironmentStorage
    @Environment(\.innoRouterEnvironmentMissingPolicy) private var environmentMissingPolicy
    private let routeType: M.Type

    public init(_ routeType: M.Type) {
        self.routeType = routeType
    }

    public var wrappedValue: AnyModalIntentDispatcher<M> {
        if let dispatcher = modalEnvironmentStorage?[M.self] {
            return dispatcher
        }
        if modalEnvironmentStorage == nil {
            handleMissingEnvironment(policy: environmentMissingPolicy) {
                "ModalEnvironmentStorage is missing for \(String(describing: routeType)). " +
                "Attach this view inside ModalHost."
            }
        } else {
            handleMissingEnvironment(policy: environmentMissingPolicy) {
                "AnyModalIntentDispatcher is missing for \(String(describing: routeType)). " +
                "Ensure the matching ModalHost is in the environment hierarchy."
            }
        }
        return AnyModalIntentDispatcher<M> { _ in /* no-op placeholder */ }
    }
}
