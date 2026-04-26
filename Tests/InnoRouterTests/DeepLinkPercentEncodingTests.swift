// MARK: - DeepLinkPercentEncodingTests.swift
// InnoRouterTests - percent-encoded path component normalisation
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation
import Testing
import InnoRouter

@Suite("DeepLink percent-encoding normalisation")
struct DeepLinkPercentEncodingTests {

    private enum DeepRoute: Route, Equatable {
        case detail(String)
        case home
    }

    @Test("Percent-encoded ASCII path component matches its decoded pattern")
    func testAsciiPercentEncodedPathMatches() throws {
        let matcher = DeepLinkMatcher<DeepRoute> {
            DeepLinkMapping("/hello world") { _ in .home }
        }

        let url = try #require(URL(string: "myapp://app/hello%20world"))
        let route = matcher.match(url)

        #expect(route == .home)
    }

    @Test("Percent-encoded UTF-8 (Korean) path component decodes correctly")
    func testKoreanPercentEncodedPathMatches() throws {
        let matcher = DeepLinkMatcher<DeepRoute> {
            DeepLinkMapping("/안녕") { _ in .home }
        }

        // %EC%95%88%EB%85%95 == "안녕" in UTF-8
        let url = try #require(URL(string: "myapp://app/%EC%95%88%EB%85%95"))
        let route = matcher.match(url)

        #expect(route == .home)
    }

    @Test("Percent-encoded parameter value is decoded into the handler")
    func testParameterPercentDecoding() throws {
        let matcher = DeepLinkMatcher<DeepRoute> {
            DeepLinkMapping("/detail/:id") { params in
                params.firstValue(forName: "id").map(DeepRoute.detail)
            }
        }

        let url = try #require(URL(string: "myapp://app/detail/hello%20world"))
        let route = matcher.match(url)

        #expect(route == .detail("hello world"))
    }

    @Test("Already-decoded path components remain unchanged")
    func testDecodedPathComponentRoundtrip() throws {
        let matcher = DeepLinkMatcher<DeepRoute> {
            DeepLinkMapping("/home") { _ in .home }
        }

        let url = try #require(URL(string: "myapp://app/home"))
        let route = matcher.match(url)

        #expect(route == .home)
    }
}
