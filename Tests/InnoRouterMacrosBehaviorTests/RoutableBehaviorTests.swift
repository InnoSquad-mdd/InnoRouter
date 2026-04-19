// MARK: - RoutableBehaviorTests.swift
// InnoRouterMacrosBehaviorTests - @Routable runtime semantics
// Copyright © 2025 Inno Squad. All rights reserved.

import Testing
import InnoRouterCore
import InnoRouterMacros

// MARK: - Fixtures

@Routable
enum ShapeRoute {
    case square
    case rectangle(width: Int, height: Int)
    case colored(Int)
    case triangle(base: Double, height: Double, color: String)
}

// MARK: - @Suite

@Suite("RoutableBehaviorTests")
struct RoutableBehaviorTests {

    // MARK: - embed/extract roundtrips

    @Test("parameterless case embeds and extracts Void")
    func embedExtract_roundtrip_parameterless() {
        let embedded = ShapeRoute.Cases.square.embed(())
        #expect(embedded == .square)

        let extracted = ShapeRoute.Cases.square.extract(embedded)
        #expect(extracted != nil)

        let mismatched = ShapeRoute.Cases.square.extract(.rectangle(width: 1, height: 2))
        #expect(mismatched == nil)
    }

    @Test("single unlabeled associated value roundtrips")
    func embedExtract_roundtrip_singleUnlabeled() {
        let path = ShapeRoute.Cases.colored
        let embedded = path.embed(7)
        #expect(embedded == .colored(7))

        let extracted = path.extract(embedded)
        #expect(extracted == 7)

        let mismatched = path.extract(.square)
        #expect(mismatched == nil)
    }

    @Test("multi labeled associated value preserves tuple order")
    func embedExtract_roundtrip_multiLabeled() {
        let path = ShapeRoute.Cases.rectangle
        let embedded = path.embed((4, 5))
        #expect(embedded == .rectangle(width: 4, height: 5))

        let extracted = path.extract(embedded)
        #expect(extracted?.0 == 4)
        #expect(extracted?.1 == 5)
    }

    @Test("triple labeled associated value preserves tuple positions")
    func embedExtract_roundtrip_tripleLabeled() {
        let path = ShapeRoute.Cases.triangle
        let embedded = path.embed((2.0, 3.0, "red"))
        #expect(embedded == .triangle(base: 2.0, height: 3.0, color: "red"))

        let extracted = path.extract(embedded)
        #expect(extracted?.0 == 2.0)
        #expect(extracted?.1 == 3.0)
        #expect(extracted?.2 == "red")
    }

    // MARK: - is(_:)

    @Test("is(_:) returns true for matching case")
    func isReturnsTrueForMatchingCase() {
        let route: ShapeRoute = .rectangle(width: 1, height: 2)
        #expect(route.is(ShapeRoute.Cases.rectangle))
    }

    @Test("is(_:) returns false for mismatched case")
    func isReturnsFalseForMismatchedCase() {
        let route: ShapeRoute = .square
        #expect(!route.is(ShapeRoute.Cases.rectangle))
        #expect(route.is(ShapeRoute.Cases.square))
    }

    // MARK: - subscript[case:]

    @Test("subscript[case:] returns nil for mismatched case")
    func subscriptCaseReturnsNilForMismatchedCase() {
        let route: ShapeRoute = .square
        #expect(route[case: ShapeRoute.Cases.rectangle] == nil)
        #expect(route[case: ShapeRoute.Cases.colored] == nil)
    }

    @Test("subscript[case:] returns associated value for matching case")
    func subscriptCaseReturnsValueForMatchingCase() {
        let route: ShapeRoute = .colored(42)
        let value = route[case: ShapeRoute.Cases.colored]
        #expect(value == 42)
    }

    // NOTE: Tuple-valued subscript form (`route[case: ShapeRoute.Cases.rectangle]`)
    // currently triggers a Swift 6.3 compiler crash in SIL lowering when the generic
    // subscript returns `(T, U)?` for a tuple `Value`. Tuple order preservation is
    // still verified above via `path.extract(_:)` direct calls, which exercise the
    // same generator output. Track Swift bug before re-enabling subscript tuple form.

    // MARK: - Route conformance

    @Test("@Routable conforms to Route and is Hashable")
    func routableConformsToRouteHashable() {
        func requireRouteSendable<R: Route>(_ value: R) {
            _ = value
        }

        let a: ShapeRoute = .square
        requireRouteSendable(a)

        let b: ShapeRoute = .square
        #expect(Set([a, b]).count == 1)

        let different: ShapeRoute = .rectangle(width: 4, height: 5)
        #expect(Set([a, different]).count == 2)

        // Route protocol conformance: should compile as Route-typed value.
        let asRoute: any Route = a
        _ = asRoute
    }
}
