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
            intentDispatchers[ObjectIdentifier(routeType)] = newValue
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

@MainActor
public final class AnyFlowIntentDispatcher<R: Route>: FlowIntentDispatching {
    public typealias RouteType = R

    private let sendIntent: @MainActor (FlowIntent<R>) -> Void

    public init(send: @escaping @MainActor (FlowIntent<R>) -> Void) {
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
    private let routeType: R.Type

    public init(_ routeType: R.Type) {
        self.routeType = routeType
    }

    public var wrappedValue: AnyFlowIntentDispatcher<R> {
        guard let flowEnvironmentStorage else {
            preconditionFailure(
                "FlowEnvironmentStorage is missing for \(String(describing: routeType)). " +
                "Attach this view inside FlowHost."
            )
        }
        guard let dispatcher = flowEnvironmentStorage[R.self] else {
            preconditionFailure(
                "AnyFlowIntentDispatcher is missing for \(String(describing: routeType)). " +
                "Ensure the matching FlowHost is in the environment hierarchy."
            )
        }
        return dispatcher
    }
}
