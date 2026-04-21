// MARK: - FlowPlanApplicationTests.swift
// InnoRouterTests - FlowStore.apply(_ plan:)
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
@testable import InnoRouterSwiftUI

private enum FlowPlanRoute: Route {
    case start
    case second
    case sheetStep
    case coverStep
    case queuedStep
}

@Suite("FlowPlan Application Tests")
struct FlowPlanApplicationTests {

    @Test("apply seeds stack and modal tail from a valid plan")
    @MainActor
    func applyValidPlan() {
        let store = FlowStore<FlowPlanRoute>()
        let plan = FlowPlan<FlowPlanRoute>(steps: [
            .push(.start),
            .push(.second),
            .sheet(.sheetStep)
        ])

        let result = store.apply(plan)

        #expect(store.path == plan.steps)
        #expect(store.navigationStore.state.path == [.start, .second])
        #expect(store.modalStore.currentPresentation?.route == .sheetStep)
        #expect(result == .applied(path: plan.steps))
    }

    @Test("apply with invalid plan emits invalidResetPath rejection")
    @MainActor
    func applyInvalidPlanRejected() {
        let rejections = Mutex<[FlowRejectionReason]>([])
        let store = FlowStore<FlowPlanRoute>(
            configuration: .init(
                onIntentRejected: { _, reason in
                    rejections.withLock { $0.append(reason) }
                }
            )
        )
        let invalid = FlowPlan<FlowPlanRoute>(steps: [
            .sheet(.sheetStep),
            .push(.second)
        ])

        let result = store.apply(invalid)

        #expect(store.path.isEmpty)
        #expect(rejections.withLock { $0 } == [.invalidResetPath])
        #expect(result == .rejected(currentPath: []))
    }

    @Test("apply with empty plan clears stack and modal")
    @MainActor
    func applyEmptyPlanClears() {
        let store = FlowStore<FlowPlanRoute>()
        store.send(.push(.start))
        store.send(.presentSheet(.sheetStep))

        let result = store.apply(FlowPlan<FlowPlanRoute>())

        #expect(store.path.isEmpty)
        #expect(store.navigationStore.state.path.isEmpty)
        #expect(store.modalStore.currentPresentation == nil)
        #expect(result == .applied(path: []))
    }

    @Test("apply supports cover tail too")
    @MainActor
    func applyCoverTailPlan() {
        let store = FlowStore<FlowPlanRoute>()
        store.apply(FlowPlan<FlowPlanRoute>(steps: [.push(.start), .cover(.coverStep)]))

        #expect(store.modalStore.currentPresentation?.style == .fullScreenCover)
        #expect(store.modalStore.currentPresentation?.route == .coverStep)
    }

    @Test("apply clears queued presentations when target modal tail already matches current modal")
    @MainActor
    func applyClearsStaleQueuedPresentations() {
        let store = FlowStore<FlowPlanRoute>()
        store.send(.push(.start))
        store.send(.presentSheet(.sheetStep))
        store.send(.presentSheet(.queuedStep))

        store.apply(FlowPlan<FlowPlanRoute>(steps: [.push(.start), .sheet(.sheetStep)]))

        #expect(store.path == [.push(.start), .sheet(.sheetStep)])
        #expect(store.modalStore.currentPresentation?.route == .sheetStep)
        #expect(store.modalStore.queuedPresentations.isEmpty)
    }

    @Test("apply re-presents the matching modal tail with a fresh presentation")
    @MainActor
    func applyMatchingModalTailRepresentsLifecycle() {
        let presented = Mutex<[FlowPlanRoute]>([])
        let dismissed = Mutex<[ModalDismissalReason]>([])
        let store = FlowStore<FlowPlanRoute>(
            configuration: .init(
                modal: .init(
                    onPresented: { presentation in
                        presented.withLock { $0.append(presentation.route) }
                    },
                    onDismissed: { _, reason in
                        dismissed.withLock { $0.append(reason) }
                    }
                )
            )
        )
        store.send(.push(.start))
        store.send(.presentSheet(.sheetStep))

        let presentedMarker = presented.withLock { $0.count }
        let dismissedMarker = dismissed.withLock { $0.count }
        let beforeID = store.modalStore.currentPresentation?.id

        let result = store.apply(
            FlowPlan<FlowPlanRoute>(steps: [.push(.start), .sheet(.sheetStep)])
        )

        let newPresented = presented.withLock { Array($0.dropFirst(presentedMarker)) }
        let newDismissed = dismissed.withLock { Array($0.dropFirst(dismissedMarker)) }

        #expect(result == .applied(path: [.push(.start), .sheet(.sheetStep)]))
        #expect(beforeID != store.modalStore.currentPresentation?.id)
        #expect(newPresented == [.sheetStep])
        #expect(newDismissed == [.dismissAll])
    }
}
