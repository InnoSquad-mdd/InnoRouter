// MARK: - NavigationResultLayeringHelpersTests.swift
// InnoRouterTests - layering helpers on NavigationResult
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import InnoRouter

@Suite("NavigationResult layering helpers")
struct NavigationResultLayeringHelpersTests {

    private enum LayerRoute: Route {
        case home
        case detail
    }

    @Test("Engine failures are correctly classified")
    func testEngineFailureClassification() {
        #expect(NavigationResult<LayerRoute>.emptyStack.isEngineFailure)
        #expect(NavigationResult<LayerRoute>.invalidPopCount(0).isEngineFailure)
        #expect(NavigationResult<LayerRoute>.insufficientStackDepth(requested: 5, available: 1).isEngineFailure)
        #expect(NavigationResult<LayerRoute>.routeNotFound(.home).isEngineFailure)

        #expect(!NavigationResult<LayerRoute>.success.isEngineFailure)
        #expect(!NavigationResult<LayerRoute>.cancelled(.conditionFailed).isEngineFailure)
        #expect(!NavigationResult<LayerRoute>.cancelled(.custom("manual")).isEngineFailure)
    }

    @Test("Middleware cancellations are differentiated from other cancellations")
    func testMiddlewareCancellationClassification() {
        let middleware = NavigationResult<LayerRoute>.cancelled(
            .middleware(debugName: "auth", command: .push(.detail))
        )
        let condition = NavigationResult<LayerRoute>.cancelled(.conditionFailed)
        let custom = NavigationResult<LayerRoute>.cancelled(.custom("user-cancelled"))
        let stale = NavigationResult<LayerRoute>.cancelled(
            .staleAfterPrepare(command: .push(.detail))
        )

        #expect(middleware.isMiddlewareCancellation)
        #expect(!condition.isMiddlewareCancellation)
        #expect(!custom.isMiddlewareCancellation)
        #expect(!stale.isMiddlewareCancellation)

        #expect(middleware.middlewareCancellationReason == "auth")
        #expect(condition.middlewareCancellationReason == nil)
        #expect(custom.middlewareCancellationReason == nil)
        #expect(stale.middlewareCancellationReason == nil)
    }

    @Test("Anonymous middleware cancellation surfaces nil debug label")
    func testAnonymousMiddlewareLabel() {
        let result = NavigationResult<LayerRoute>.cancelled(
            .middleware(debugName: nil, command: .push(.home))
        )

        #expect(result.isMiddlewareCancellation)
        #expect(result.middlewareCancellationReason == nil)
    }

    @Test("Multiple-result aggregation traverses children for failure flags")
    func testMultipleResultAggregation() {
        let mixed = NavigationResult<LayerRoute>.multiple([
            .success,
            .emptyStack,
            .cancelled(.middleware(debugName: "guard", command: .pop))
        ])

        #expect(!mixed.isSuccess)
        #expect(mixed.isEngineFailure)
        #expect(mixed.isMiddlewareCancellation)
        #expect(mixed.middlewareCancellationReason == "guard")

        let allSuccess = NavigationResult<LayerRoute>.multiple([.success, .success])
        #expect(allSuccess.isSuccess)
        #expect(!allSuccess.isEngineFailure)
        #expect(!allSuccess.isMiddlewareCancellation)
    }

    @Test("Layering helpers form a partition for non-multiple cases")
    func testPartitionInvariant() {
        let results: [NavigationResult<LayerRoute>] = [
            .success,
            .emptyStack,
            .invalidPopCount(0),
            .insufficientStackDepth(requested: 3, available: 1),
            .routeNotFound(.home),
            .cancelled(.middleware(debugName: "m", command: .pop)),
            .cancelled(.conditionFailed),
            .cancelled(.custom("x")),
            .cancelled(.staleAfterPrepare(command: .pop))
        ]

        for result in results {
            // Exactly one classification (or .success which is none of the
            // failure flags, plus the non-middleware cancellation cases which
            // also belong to no failure flag).
            let classifications = [
                result.isSuccess,
                result.isEngineFailure,
                result.isMiddlewareCancellation
            ].filter { $0 }
            #expect(classifications.count <= 1, "\(result) classified into \(classifications.count) groups")
        }
    }
}
