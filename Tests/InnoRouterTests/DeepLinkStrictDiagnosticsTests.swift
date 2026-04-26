// MARK: - DeepLinkStrictDiagnosticsTests.swift
// InnoRouterTests - .strict matcher diagnostics promotion
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation
import Testing
import InnoRouter

@Suite("DeepLinkMatcher .strict diagnostics mode")
struct DeepLinkStrictDiagnosticsTests {

    private enum StrictRoute: Route {
        case home
        case detail
    }

    @Test("Strict init throws on duplicate patterns")
    func testStrictThrowsOnDuplicatePattern() {
        do {
            _ = try DeepLinkMatcher<StrictRoute>(strict: ()) {
                DeepLinkMapping("/home") { _ in .home }
                DeepLinkMapping("/home") { _ in .home }
            }
            Issue.record("Expected DeepLinkMatcherStrictError")
        } catch let error as DeepLinkMatcherStrictError {
            #expect(error.diagnostics.count == 1)
            if case .duplicatePattern = error.diagnostics.first {
                // ok
            } else {
                Issue.record("Expected duplicatePattern, got \(String(describing: error.diagnostics.first))")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Strict init throws on wildcard shadowing")
    func testStrictThrowsOnWildcardShadowing() {
        do {
            _ = try DeepLinkMatcher<StrictRoute>(strict: ()) {
                DeepLinkMapping("/*") { _ in .home }
                DeepLinkMapping("/detail") { _ in .detail }
            }
            Issue.record("Expected DeepLinkMatcherStrictError")
        } catch let error as DeepLinkMatcherStrictError {
            #expect(error.diagnostics.contains(where: {
                if case .wildcardShadowing = $0 { return true }
                return false
            }))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Strict init succeeds when no diagnostics are produced")
    func testStrictSucceedsWithCleanMappings() throws {
        let matcher = try DeepLinkMatcher<StrictRoute>(strict: ()) {
            DeepLinkMapping("/home") { _ in .home }
            DeepLinkMapping("/detail") { _ in .detail }
        }
        #expect(matcher.diagnostics.isEmpty)
    }

    @Test("Strict mode aggregates every diagnostic into the thrown error")
    func testStrictAggregatesAllDiagnostics() {
        do {
            _ = try DeepLinkMatcher<StrictRoute>(strict: ()) {
                DeepLinkMapping("/home") { _ in .home }
                DeepLinkMapping("/home") { _ in .home }
                DeepLinkMapping("/*") { _ in .detail }
                DeepLinkMapping("/profile") { _ in .detail }
            }
            Issue.record("Expected DeepLinkMatcherStrictError")
        } catch let error as DeepLinkMatcherStrictError {
            #expect(error.diagnostics.count >= 2)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
