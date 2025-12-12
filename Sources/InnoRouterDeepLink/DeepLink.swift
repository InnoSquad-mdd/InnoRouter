import Foundation

import InnoRouterCore

public struct DeepLinkParser: Sendable {
    public struct ParsedURL: Sendable, Equatable {
        public let scheme: String?
        public let host: String?
        public let path: [String]
        public let queryItems: [String: String]
        public let fragment: String?

        public init(url: URL) {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            self.scheme = components?.scheme
            self.host = components?.host
            self.path = url.pathComponents.filter { $0 != "/" }
            self.queryItems = Dictionary(
                uniqueKeysWithValues: (components?.queryItems ?? [])
                    .compactMap { item in
                        item.value.map { (item.name, $0) }
                    }
            )
            self.fragment = components?.fragment
        }

        public var pathString: String {
            "/" + path.joined(separator: "/")
        }
    }

    public static func parse(_ urlString: String) -> ParsedURL? {
        guard let url = URL(string: urlString) else { return nil }
        return ParsedURL(url: url)
    }

    public static func parse(_ url: URL) -> ParsedURL {
        ParsedURL(url: url)
    }
}

public struct DeepLinkPattern: Sendable {
    public struct MatchResult: Sendable {
        public let params: [String: String]
        public let matched: Bool

        public init(params: [String: String] = [:], matched: Bool = true) {
            self.params = params
            self.matched = matched
        }

        public static let noMatch = MatchResult(matched: false)
    }

    private let patternParts: [PatternPart]

    private enum PatternPart: Sendable {
        case literal(String)
        case parameter(String)
        case wildcard
    }

    public init(_ pattern: String) {
        self.patternParts = pattern
            .split(separator: "/")
            .map { part -> PatternPart in
                let str = String(part)
                if str.hasPrefix(":") {
                    return .parameter(String(str.dropFirst()))
                } else if str == "*" {
                    return .wildcard
                } else {
                    return .literal(str)
                }
            }
    }

    public func match(_ path: String) -> MatchResult? {
        let pathParts = path.split(separator: "/").map(String.init)

        let hasWildcard = patternParts.contains { part in
            if case .wildcard = part { return true }
            return false
        }
        if !hasWildcard && patternParts.count != pathParts.count {
            return nil
        }

        var params: [String: String] = [:]

        for (index, patternPart) in patternParts.enumerated() {
            switch patternPart {
            case .literal(let expected):
                guard index < pathParts.count, pathParts[index] == expected else { return nil }

            case .parameter(let name):
                guard index < pathParts.count else { return nil }
                params[name] = pathParts[index]

            case .wildcard:
                return MatchResult(params: params)
            }
        }

        return MatchResult(params: params)
    }

    public func match(_ parsed: DeepLinkParser.ParsedURL) -> MatchResult? {
        guard let result = match(parsed.pathString) else { return nil }

        var params = result.params
        for (key, value) in parsed.queryItems {
            params[key] = value
        }

        return MatchResult(params: params)
    }
}

public struct DeepLinkMatcher<R: Route>: Sendable {
    private let mappings: [DeepLinkMapping<R>]

    public init(@DeepLinkMappingBuilder<R> mappings: () -> [DeepLinkMapping<R>]) {
        self.mappings = mappings()
    }

    public func match(_ url: URL) -> R? {
        let parsed = DeepLinkParser.parse(url)
        for mapping in mappings {
            if let route = mapping.match(parsed) {
                return route
            }
        }
        return nil
    }

    public func match(_ urlString: String) -> R? {
        guard let url = URL(string: urlString) else { return nil }
        return match(url)
    }
}

public struct DeepLinkMapping<R: Route>: Sendable {
    private let pattern: DeepLinkPattern
    private let handler: @Sendable ([String: String]) -> R?

    public init(
        _ pattern: String,
        handler: @escaping @Sendable ([String: String]) -> R?
    ) {
        self.pattern = DeepLinkPattern(pattern)
        self.handler = handler
    }

    func match(_ parsed: DeepLinkParser.ParsedURL) -> R? {
        guard let result = pattern.match(parsed) else { return nil }
        return handler(result.params)
    }
}

@resultBuilder
public struct DeepLinkMappingBuilder<R: Route> {
    public static func buildExpression(_ expression: DeepLinkMapping<R>) -> DeepLinkMapping<R> {
        expression
    }

    public static func buildBlock(_ components: DeepLinkMapping<R>...) -> [DeepLinkMapping<R>] {
        components
    }

    public static func buildArray(_ components: [[DeepLinkMapping<R>]]) -> [DeepLinkMapping<R>] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [DeepLinkMapping<R>]?) -> [DeepLinkMapping<R>] {
        component ?? []
    }

    public static func buildEither(first component: [DeepLinkMapping<R>]) -> [DeepLinkMapping<R>] {
        component
    }

    public static func buildEither(second component: [DeepLinkMapping<R>]) -> [DeepLinkMapping<R>] {
        component
    }
}
