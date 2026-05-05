import SwiftUI

import InnoRouterCore

typealias FlowIntentHandler<R: Route> = @MainActor @Sendable (FlowIntent<R>) -> Void

@MainActor
final class FlowEnvironmentStorage {
    private var intentDispatchers: [ObjectIdentifier: Any] = [:]

    init() {}

    subscript<R: Route>(routeType: R.Type) -> FlowIntentHandler<R>? {
        get {
            let registration = intentDispatchers[ObjectIdentifier(routeType)]
                as? DispatcherRegistration<FlowIntentHandler<R>>
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

    func setIntentDispatcher<R: Route>(
        _ dispatcher: FlowIntentHandler<R>?,
        ownerID: ObjectIdentifier?,
        routeType: R.Type
    ) {
        let key = ObjectIdentifier(routeType)
        let existing = intentDispatchers[key]
            as? DispatcherRegistration<FlowIntentHandler<R>>
        let replacement = dispatcher.map {
            DispatcherRegistration(
                dispatcher: $0,
                ownerID: ownerID ?? ObjectIdentifier(self)
            )
        }
        reportDuplicateDispatcherIfNeeded(
            existing: existing,
            replacement: replacement,
            keyDescription: "FlowIntent handler for \(String(describing: routeType))"
        )
        if let replacement {
            intentDispatchers[key] = replacement
        } else {
            intentDispatchers.removeValue(forKey: key)
        }
    }
}

extension EnvironmentValues {
    @Entry var flowEnvironmentStorage: FlowEnvironmentStorage?
}

extension View {
    @MainActor
    func flowIntentDispatcher<R: Route>(
        _ dispatcher: @escaping FlowIntentHandler<R>,
        owner: AnyObject
    ) -> some View {
        transformEnvironment(\.flowEnvironmentStorage) { storage in
            guard let storage else {
                assertionFailure(
                    "FlowEnvironmentStorage is missing. Attach this view inside FlowHost."
                )
                return
            }
            storage.setIntentDispatcher(
                dispatcher,
                ownerID: ObjectIdentifier(owner),
                routeType: R.self
            )
        }
    }
}

@MainActor
@propertyWrapper
public struct EnvironmentFlowIntent<R: Route>: DynamicProperty {
    @Environment(\.flowEnvironmentStorage) private var flowEnvironmentStorage
    @Environment(\.innoRouterEnvironmentMissingPolicy) private var environmentMissingPolicy
    private let routeType: R.Type

    public init(_ routeType: R.Type) {
        self.routeType = routeType
    }

    public var wrappedValue: @MainActor @Sendable (FlowIntent<R>) -> Void {
        if let dispatcher = flowEnvironmentStorage?[R.self] {
            return dispatcher
        }
        if flowEnvironmentStorage == nil {
            handleMissingEnvironment(policy: environmentMissingPolicy) {
                "FlowEnvironmentStorage is missing for \(String(describing: routeType)). " +
                "Attach this view inside FlowHost."
            }
        } else {
            handleMissingEnvironment(policy: environmentMissingPolicy) {
                "FlowIntent handler is missing for \(String(describing: routeType)). " +
                "Ensure the matching FlowHost is in the environment hierarchy."
            }
        }
        return { _ in /* no-op placeholder */ }
    }
}
