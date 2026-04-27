// MARK: - RouteStackTests.swift
// InnoRouter Tests
// Copyright © 2025 Inno Squad. All rights reserved.

import Testing
import Foundation
import Observation
import OSLog
import Synchronization
import SwiftUI
import InnoRouter
import InnoRouterEffects
@testable import InnoRouterSwiftUI

// MARK: - RouteStack Tests

@Suite("RouteStack Tests")
struct RouteStackTests {
    @Test("RouteStack init creates an empty stack")
    func testEmptyInit() {
        let stack = RouteStack<TestRoute>()
        #expect(stack.path.isEmpty)
    }

    @Test("RouteStack validating init accepts permissive snapshots")
    func testValidatedInitPermissive() throws {
        let stack = try RouteStack<TestRoute>(validating: [.home, .detail(id: "123")])
        #expect(stack.path == [.home, .detail(id: "123")])
    }

    @Test("RouteStack validating init surfaces validator failures")
    func testValidatedInitFailure() {
        let validator = RouteStackValidator<TestRoute> { _ in
            throw TestValidationError.rejected
        }

        do {
            _ = try RouteStack<TestRoute>(validating: [.home], using: validator)
            Issue.record("Expected RouteStack validation to fail")
        } catch let error as TestValidationError {
            #expect(error == .rejected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("RouteStackValidator nonEmpty rejects empty stacks")
    func testNonEmptyValidator() {
        do {
            _ = try RouteStack<TestRoute>(validating: [], using: .nonEmpty)
            Issue.record("Expected nonEmpty validator to reject empty path")
        } catch let error as RouteStackValidationError<TestRoute> {
            #expect(error == .emptyStackNotAllowed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("RouteStackValidator uniqueRoutes rejects duplicates")
    func testUniqueRoutesValidator() {
        do {
            _ = try RouteStack<TestRoute>(validating: [.home, .settings, .home], using: .uniqueRoutes)
            Issue.record("Expected uniqueRoutes validator to reject duplicates")
        } catch let error as RouteStackValidationError<TestRoute> {
            #expect(error == .duplicateRoute(.home))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("RouteStackValidator rooted validates the first route")
    func testRootedValidator() {
        let valid = try? RouteStack<TestRoute>(validating: [.home, .settings], using: .rooted(at: .home))
        #expect(valid?.path == [.home, .settings])

        do {
            _ = try RouteStack<TestRoute>(validating: [.settings], using: .rooted(at: .home))
            Issue.record("Expected rooted validator to reject wrong root")
        } catch let error as RouteStackValidationError<TestRoute> {
            #expect(error == .invalidRoot(expected: .home, actual: .settings))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("RouteStackValidator combined applies validators in order")
    func testCombinedValidator() {
        let validator = RouteStackValidator<TestRoute>.nonEmpty
            .combined(with: .rooted(at: .home))
            .combined(with: .uniqueRoutes)

        let valid = try? RouteStack<TestRoute>(
            validating: [.home, .settings, .detail(id: "123")],
            using: validator
        )
        #expect(valid?.path == [.home, .settings, .detail(id: "123")])

        do {
            _ = try RouteStack<TestRoute>(
                validating: [.home, .settings, .home],
                using: validator
            )
            Issue.record("Expected combined validator to reject duplicates")
        } catch let error as RouteStackValidationError<TestRoute> {
            #expect(error == .duplicateRoute(.home))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
