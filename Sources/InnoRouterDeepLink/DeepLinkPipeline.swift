import Foundation

import InnoRouterCore

public protocol DeepLinkable: Route {
    static func route(from url: URL) -> Self?
    var deepLinkPath: String { get }
}

public extension DeepLinkable {
    var deepLinkPath: String { "/" }
}

public struct PendingDeepLink<R: Route>: Sendable, Equatable {
    public let url: URL
    public let route: R
    public let plan: NavigationPlan<R>

    public init(url: URL, route: R, plan: NavigationPlan<R>) {
        self.url = url
        self.route = route
        self.plan = plan
    }
}

public struct NavigationPlan<R: Route>: Sendable, Equatable {
    public var commands: [NavigationCommand<R>]

    public init(commands: [NavigationCommand<R>]) {
        self.commands = commands
    }
}

public enum DeepLinkAuthenticationPolicy<R: Route>: Sendable {
    case notRequired
    case required(
        shouldRequireAuthentication: @Sendable (R) -> Bool,
        isAuthenticated: @Sendable () -> Bool
    )
}

public enum DeepLinkRejectionReason: Sendable, Equatable {
    case schemeNotAllowed(actualScheme: String?)
    case hostNotAllowed(actualHost: String?)
}

public enum DeepLinkDecision<R: Route>: Sendable, Equatable {
    case rejected(reason: DeepLinkRejectionReason)
    case unhandled(url: URL)
    case pending(PendingDeepLink<R>)
    case plan(NavigationPlan<R>)
}

public struct DeepLinkPipeline<R: Route>: Sendable {
    public typealias Resolver = @Sendable (URL) -> R?
    public typealias Planner = @Sendable (R) -> NavigationPlan<R>

    public var allowedSchemes: Set<String>?
    public var allowedHosts: Set<String>?
    public var resolve: Resolver
    public var authenticationPolicy: DeepLinkAuthenticationPolicy<R>
    public var plan: Planner

    public init(
        allowedSchemes: Set<String>? = nil,
        allowedHosts: Set<String>? = nil,
        resolve: @escaping Resolver,
        authenticationPolicy: DeepLinkAuthenticationPolicy<R> = .notRequired,
        plan: @escaping Planner = { route in NavigationPlan(commands: [.push(route)]) }
    ) {
        self.allowedSchemes = allowedSchemes?.lowercasedSet
        self.allowedHosts = allowedHosts?.lowercasedSet
        self.resolve = resolve
        self.authenticationPolicy = authenticationPolicy
        self.plan = plan
    }

    public func decide(for url: URL) -> DeepLinkDecision<R> {
        if let allowedSchemes {
            guard let scheme = url.scheme?.lowercased() else {
                return .rejected(reason: .schemeNotAllowed(actualScheme: url.scheme))
            }
            guard allowedSchemes.contains(scheme) else {
                return .rejected(reason: .schemeNotAllowed(actualScheme: url.scheme))
            }
        }

        if let allowedHosts {
            guard let host = url.host?.lowercased() else {
                return .rejected(reason: .hostNotAllowed(actualHost: url.host))
            }
            guard allowedHosts.contains(host) else {
                return .rejected(reason: .hostNotAllowed(actualHost: url.host))
            }
        }

        guard let route = resolve(url) else {
            return .unhandled(url: url)
        }

        let navigationPlan = plan(route)
        switch authenticationPolicy {
        case .notRequired:
            break

        case .required(let shouldRequireAuthentication, let isAuthenticated):
            if shouldRequireAuthentication(route), !isAuthenticated() {
                return .pending(PendingDeepLink(url: url, route: route, plan: navigationPlan))
            }
        }

        return .plan(navigationPlan)
    }
}

private extension Set where Element == String {
    var lowercasedSet: Set<String> {
        Set(map { $0.lowercased() })
    }
}
