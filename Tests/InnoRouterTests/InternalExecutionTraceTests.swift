// MARK: - InternalExecutionTraceTests.swift
// InnoRouterTests - internal execution trace correlation
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Synchronization
@_spi(InternalTrace) import InnoRouterCore
import InnoRouter
import InnoRouterDeepLink
@testable import InnoRouterSwiftUI
@testable import InnoRouterDeepLinkEffects

private struct TraceStart: Equatable {
    let context: InternalExecutionTraceContext
    let operation: String
    let metadata: [String: String]
}

private func traceStarts(
    from records: [InternalExecutionTraceRecord]
) -> [TraceStart] {
    records.compactMap { record in
        guard case .start(let context, let operation, let metadata) = record else {
            return nil
        }
        return TraceStart(context: context, operation: operation, metadata: metadata)
    }
}

private func traceStart(
    domain: InternalExecutionTraceDomain,
    operation: String,
    in records: [TraceStart]
) -> TraceStart? {
    records.first {
        $0.context.domain == domain && $0.operation == operation
    }
}

@Suite("Internal execution trace tests")
struct InternalExecutionTraceTests {

    @Test("FlowStore traces a root flow span and a correlated inner navigation span")
    @MainActor
    func flowStoreTraceCorrelation() {
        let records = Mutex<[InternalExecutionTraceRecord]>([])
        let store = FlowStore<PropertyRoute>()
        store.installTraceRecorder { record in
            records.withLock { $0.append(record) }
        }

        store.send(.push(.home))

        let starts = traceStarts(from: records.withLock { $0 })
        guard let flow = traceStart(domain: .flow, operation: "send", in: starts) else {
            Issue.record("Expected a flow send trace start, got \(starts)")
            return
        }
        guard let navigation = traceStart(
            domain: .navigation,
            operation: "commitFlowPreview",
            in: starts
        ) else {
            Issue.record("Expected a navigation commitFlowPreview trace start, got \(starts)")
            return
        }

        #expect(flow.context.rootID == navigation.context.rootID)
        #expect(navigation.context.parentSpanID == flow.context.spanID)
    }

    @Test("Deep-link handling correlates deep-link, flow, navigation, and modal spans under one root")
    @MainActor
    func deepLinkTraceCorrelation() {
        let records = Mutex<[InternalExecutionTraceRecord]>([])
        let store = FlowStore<PropertyRoute>()
        store.installTraceRecorder { record in
            records.withLock { $0.append(record) }
        }
        let handler = FlowDeepLinkEffectHandler(
            pipeline: makePropertyFlowPipeline(isAuthenticated: { true }),
            applier: store
        )
        handler.installTraceRecorder { record in
            records.withLock { $0.append(record) }
        }

        _ = handler.handle(PropertyURLCase.homeModalLegal.url)

        let starts = traceStarts(from: records.withLock { $0 })
        guard let deepLink = traceStart(domain: .deepLink, operation: "handle", in: starts) else {
            Issue.record("Expected a deep-link handle trace start, got \(starts)")
            return
        }
        guard let flow = traceStart(domain: .flow, operation: "applyPlan", in: starts) else {
            Issue.record("Expected a flow applyPlan trace start, got \(starts)")
            return
        }
        guard let navigation = traceStart(
            domain: .navigation,
            operation: "commitFlowPreview",
            in: starts
        ) else {
            Issue.record("Expected a navigation commitFlowPreview trace start, got \(starts)")
            return
        }
        guard let modal = traceStart(
            domain: .modal,
            operation: "commitFlowPreview",
            in: starts
        ) else {
            Issue.record("Expected a modal commitFlowPreview trace start, got \(starts)")
            return
        }

        #expect(deepLink.context.rootID == flow.context.rootID)
        #expect(flow.context.rootID == navigation.context.rootID)
        #expect(flow.context.rootID == modal.context.rootID)
        #expect(flow.context.parentSpanID == deepLink.context.spanID)
        #expect(navigation.context.parentSpanID == flow.context.spanID)
        #expect(modal.context.parentSpanID == flow.context.spanID)
    }
}
