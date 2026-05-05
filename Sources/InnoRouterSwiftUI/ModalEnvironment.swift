import Foundation
import SwiftUI

import InnoRouterCore

typealias ModalIntentHandler<M: Route> = @MainActor @Sendable (ModalIntent<M>) -> Void

@MainActor
final class ModalEnvironmentStorage {
    private var intentDispatchers: [ObjectIdentifier: Any] = [:]

    init() {}

    /// Manual dispatcher access for tests and low-level integration paths.
    subscript<M: Route>(routeType: M.Type) -> ModalIntentHandler<M>? {
        get {
            let registration = intentDispatchers[ObjectIdentifier(routeType)]
                as? DispatcherRegistration<ModalIntentHandler<M>>
            return registration?.dispatcher
        }
        set {
            setIntentDispatcher(
                newValue,
                ownerID: newValue.map { _ in ObjectIdentifier(self) },
                routeType: routeType
            )
        }
    }

    /// Registers a dispatcher with an explicit routing authority.
    ///
    /// Use this path when the same `ModalStore` owner can re-register with a
    /// fresh handler closure across SwiftUI updates. Passing a stable
    /// `ownerID` lets duplicate detection distinguish a benign refresh from a
    /// sibling host overwrite.
    func setIntentDispatcher<M: Route>(
        _ dispatcher: ModalIntentHandler<M>?,
        ownerID: ObjectIdentifier?,
        routeType: M.Type
    ) {
        let key = ObjectIdentifier(routeType)
        let existing = intentDispatchers[key]
            as? DispatcherRegistration<ModalIntentHandler<M>>
        let replacement = dispatcher.map {
            DispatcherRegistration(
                dispatcher: $0,
                ownerID: ownerID ?? ObjectIdentifier(self)
            )
        }
        reportDuplicateDispatcherIfNeeded(
            existing: existing,
            replacement: replacement,
            keyDescription: "ModalIntent handler for \(String(describing: routeType))"
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
        _ dispatcher: @escaping ModalIntentHandler<M>,
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
@propertyWrapper
public struct EnvironmentModalIntent<M: Route>: DynamicProperty {
    @Environment(\.modalEnvironmentStorage) private var modalEnvironmentStorage
    @Environment(\.innoRouterEnvironmentMissingPolicy) private var environmentMissingPolicy
    private let routeType: M.Type

    public init(_ routeType: M.Type) {
        self.routeType = routeType
    }

    public var wrappedValue: @MainActor @Sendable (ModalIntent<M>) -> Void {
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
                "ModalIntent handler is missing for \(String(describing: routeType)). " +
                "Ensure the matching ModalHost is in the environment hierarchy."
            }
        }
        return { _ in /* no-op placeholder */ }
    }
}
