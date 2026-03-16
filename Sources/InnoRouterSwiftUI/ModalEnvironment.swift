import Foundation
import SwiftUI

import InnoRouterCore

@MainActor
final class ModalEnvironmentStorage {
    private var intentDispatchers: [ObjectIdentifier: Any] = [:]

    init() {}

    subscript<M: Route>(routeType: M.Type) -> AnyModalIntentDispatcher<M>? {
        get {
            intentDispatchers[ObjectIdentifier(routeType)] as? AnyModalIntentDispatcher<M>
        }
        set {
            intentDispatchers[ObjectIdentifier(routeType)] = newValue
        }
    }
}

extension EnvironmentValues {
    @Entry var modalEnvironmentStorage: ModalEnvironmentStorage?
}

extension View {
    @MainActor
    func modalIntentDispatcher<M: Route>(_ dispatcher: AnyModalIntentDispatcher<M>) -> some View {
        transformEnvironment(\.modalEnvironmentStorage) { storage in
            guard let storage else {
                assertionFailure(
                    "ModalEnvironmentStorage is missing. Attach this view inside ModalHost."
                )
                return
            }
            storage[M.self] = dispatcher
        }
    }
}

@MainActor
public protocol ModalIntentDispatching: AnyObject {
    associatedtype RouteType: Route
    func send(_ intent: ModalIntent<RouteType>)
}

@MainActor
public final class AnyModalIntentDispatcher<M: Route>: ModalIntentDispatching {
    public typealias RouteType = M

    private let sendIntent: @MainActor (ModalIntent<M>) -> Void

    public init(send: @escaping @MainActor (ModalIntent<M>) -> Void) {
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
    private let routeType: M.Type

    public init(_ routeType: M.Type) {
        self.routeType = routeType
    }

    public var wrappedValue: AnyModalIntentDispatcher<M> {
        guard let modalEnvironmentStorage else {
            preconditionFailure(
                "ModalEnvironmentStorage is missing for \(String(describing: routeType)). " +
                "Attach this view inside ModalHost."
            )
        }
        guard let dispatcher = modalEnvironmentStorage[M.self] else {
            preconditionFailure(
                "AnyModalIntentDispatcher is missing for \(String(describing: routeType)). " +
                "Ensure the matching ModalHost is in the environment hierarchy."
            )
        }
        return dispatcher
    }
}
