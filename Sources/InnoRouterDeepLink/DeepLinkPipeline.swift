import Foundation

import InnoRouterCore

public protocol DeepLinkable: Route {
    static func route(from url: URL) -> Self?
    var deepLinkPath: String { get }
}

public extension DeepLinkable {
    var deepLinkPath: String { "/" }
}

public struct PendingNav<R: Route>: Sendable, Equatable {
    public let url: URL
    public let route: R

    public init(url: URL, route: R) {
        self.url = url
        self.route = route
    }
}

public struct NavPlan<R: Route>: Sendable, Equatable {
    public var commands: [NavCommand<R>]

    public init(commands: [NavCommand<R>]) {
        self.commands = commands
    }
}

public enum DeepLinkDecision<R: Route>: Sendable, Equatable {
    case rejected
    case unhandled
    case pending(PendingNav<R>)
    case plan(NavPlan<R>)
}

public struct DeepLinkPipeline<R: Route>: Sendable {
    public typealias Resolver = @Sendable (URL) -> R?
    public typealias Planner = @Sendable (R) -> NavPlan<R>

    public var allowedSchemes: Set<String>?
    public var allowedHosts: Set<String>?
    public var resolve: Resolver
    public var requiresAuthentication: (@Sendable (R) -> Bool)?
    public var isAuthenticated: (@Sendable () -> Bool)?
    public var plan: Planner

    public init(
        allowedSchemes: Set<String>? = nil,
        allowedHosts: Set<String>? = nil,
        resolve: @escaping Resolver,
        requiresAuthentication: (@Sendable (R) -> Bool)? = nil,
        isAuthenticated: (@Sendable () -> Bool)? = nil,
        plan: @escaping Planner = { route in NavPlan(commands: [.push(route)]) }
    ) {
        self.allowedSchemes = allowedSchemes
        self.allowedHosts = allowedHosts
        self.resolve = resolve
        self.requiresAuthentication = requiresAuthentication
        self.isAuthenticated = isAuthenticated
        self.plan = plan
    }

    public func decide(for url: URL) -> DeepLinkDecision<R> {
        if let allowedSchemes {
            guard let scheme = url.scheme else { return .rejected }
            if !allowedSchemes.contains(scheme.lowercased()) {
                return .rejected
            }
        }

        if let allowedHosts {
            guard let host = url.host else { return .rejected }
            if !allowedHosts.contains(host.lowercased()) {
                return .rejected
            }
        }

        guard let route = resolve(url) else {
            return .unhandled
        }

        if let requiresAuthentication,
           let isAuthenticated,
           requiresAuthentication(route) && !isAuthenticated() {
            return .pending(PendingNav(url: url, route: route))
        }

        return .plan(plan(route))
    }
}
