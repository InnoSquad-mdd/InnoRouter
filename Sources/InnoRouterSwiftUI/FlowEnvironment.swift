import SwiftUI

import InnoRouterCore

@MainActor
final class FlowEnvironmentStorage {
    private var intentDispatchers: [ObjectIdentifier: Any] = [:]

    init() {}

    subscript<R: Route>(routeType: R.Type) -> AnyFlowIntentDispatcher<R>? {
        get {
            intentDispatchers[ObjectIdentifier(routeType)] as? AnyFlowIntentDispatcher<R>
        }
        set {
            let key = ObjectIdentifier(routeType)
            let existing = intentDispatchers[key] as? AnyFlowIntentDispatcher<R>
            reportDuplicateDispatcherIfNeeded(
                existing: existing,
                replacement: newValue,
                keyDescription: "AnyFlowIntentDispatcher<\(String(describing: routeType))>"
            )
            intentDispatchers[key] = newValue
        }
    }
}

extension EnvironmentValues {
    @Entry var flowEnvironmentStorage: FlowEnvironmentStorage?
}

extension View {
    @MainActor
    func flowIntentDispatcher<R: Route>(_ dispatcher: AnyFlowIntentDispatcher<R>) -> some View {
        transformEnvironment(\.flowEnvironmentStorage) { storage in
            guard let storage else {
                assertionFailure(
                    "FlowEnvironmentStorage is missing. Attach this view inside FlowHost."
                )
                return
            }
            storage[R.self] = dispatcher
        }
    }
}

@MainActor
public protocol FlowIntentDispatching: AnyObject {
    associatedtype RouteType: Route
    func send(_ intent: FlowIntent<RouteType>)
}

/// Type-erased dispatcher used to publish ``FlowIntent`` values through the
/// SwiftUI environment.
///
/// The dispatcher is `@MainActor`-isolated. ``FlowIntent`` itself is
/// `Sendable` because `Route` conforms to `Sendable`; the closure stored here
/// is annotated `@Sendable` so the dispatcher can be safely captured from
/// detached tasks before the eventual hop back to the main actor.
@MainActor
public final class AnyFlowIntentDispatcher<R: Route>: FlowIntentDispatching {
    public typealias RouteType = R

    private let sendIntent: @MainActor @Sendable (FlowIntent<R>) -> Void

    public init(send: @escaping @MainActor @Sendable (FlowIntent<R>) -> Void) {
        self.sendIntent = send
    }

    public func send(_ intent: FlowIntent<R>) {
        sendIntent(intent)
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

    public var wrappedValue: AnyFlowIntentDispatcher<R> {
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
                "AnyFlowIntentDispatcher is missing for \(String(describing: routeType)). " +
                "Ensure the matching FlowHost is in the environment hierarchy."
            }
        }
        return AnyFlowIntentDispatcher<R> { _ in /* no-op placeholder */ }
    }
}
