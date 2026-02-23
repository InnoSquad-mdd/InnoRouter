import Foundation

import InnoRouterCore

public struct DeepLinkParameters: Sendable, Equatable {
    public let valuesByName: [String: [String]]

    public init(valuesByName: [String: [String]] = [:]) {
        self.valuesByName = valuesByName
    }

    public var firstValuesByName: [String: String] {
        valuesByName.compactMapValues { $0.first }
    }

    public func firstValue(forName name: String) -> String? {
        valuesByName[name]?.first
    }

    public func values(forName name: String) -> [String] {
        valuesByName[name] ?? []
    }
}

public struct DeepLinkParser: Sendable {
    public struct ParsedURL: Sendable, Equatable {
        public let scheme: String?
        public let host: String?
        public let path: [String]
        public let queryItems: [String: [String]]
        public let fragment: String?

        public init(url: URL) {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            self.scheme = components?.scheme
            self.host = components?.host
            self.path = url.pathComponents.filter { $0 != "/" }

            var parsedQueryItems: [String: [String]] = [:]
            for item in components?.queryItems ?? [] {
                guard let value = item.value else { continue }
                parsedQueryItems[item.name, default: []].append(value)
            }
            self.queryItems = parsedQueryItems

            self.fragment = components?.fragment
        }

        public var pathString: String {
            "/" + path.joined(separator: "/")
        }

        public var firstQueryItems: [String: String] {
            queryItems.compactMapValues { $0.first }
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
        public let parameters: [String: [String]]
        public let isMatched: Bool

        public init(parameters: [String: [String]] = [:], isMatched: Bool = true) {
            self.parameters = parameters
            self.isMatched = isMatched
        }

        public static let noMatch = MatchResult(isMatched: false)
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
                let stringPart = String(part)
                if stringPart.hasPrefix(":") {
                    return .parameter(String(stringPart.dropFirst()))
                } else if stringPart == "*" {
                    return .wildcard
                } else {
                    return .literal(stringPart)
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

        var parameters: [String: [String]] = [:]

        for (index, patternPart) in patternParts.enumerated() {
            switch patternPart {
            case .literal(let expected):
                guard index < pathParts.count, pathParts[index] == expected else { return nil }

            case .parameter(let name):
                guard index < pathParts.count else { return nil }
                parameters[name] = [pathParts[index]]

            case .wildcard:
                return MatchResult(parameters: parameters)
            }
        }

        return MatchResult(parameters: parameters)
    }

    public func match(_ parsed: DeepLinkParser.ParsedURL) -> MatchResult? {
        guard let result = match(parsed.pathString) else { return nil }
        let mergedParameters = Self.merge(result.parameters, with: parsed.queryItems)
        return MatchResult(parameters: mergedParameters)
    }

    private static func merge(
        _ first: [String: [String]],
        with second: [String: [String]]
    ) -> [String: [String]] {
        var merged = first
        for (key, values) in second {
            merged[key, default: []].append(contentsOf: values)
        }
        return merged
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
    private let handler: @Sendable (DeepLinkParameters) -> R?

    public init(
        _ pattern: String,
        handler: @escaping @Sendable (DeepLinkParameters) -> R?
    ) {
        self.pattern = DeepLinkPattern(pattern)
        self.handler = handler
    }

    func match(_ parsed: DeepLinkParser.ParsedURL) -> R? {
        guard let result = pattern.match(parsed) else { return nil }
        return handler(DeepLinkParameters(valuesByName: result.parameters))
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
