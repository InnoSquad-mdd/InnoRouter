// MARK: - ModalPresentResultTests.swift
// InnoRouterTests - ModalStore.present(_:style:) typed return value
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouter
import InnoRouterSwiftUI

private enum PresentRoute: Route {
    case alpha
    case bravo
}

@Suite("ModalStore present(_:style:) ModalPresentResult")
@MainActor
struct ModalPresentResultTests {

    @Test("First present resolves to .shownImmediately with the active presentation id")
    func firstPresentShowsImmediately() {
        let store = ModalStore<PresentRoute>()

        let result = store.present(.alpha, style: .sheet)

        #expect(result.isShownImmediately)
        #expect(result.isQueuedBehind == false)

        guard let id = result.presentationID else {
            Issue.record("Expected a non-nil presentationID, got nil for \(result)")
            return
        }
        #expect(store.currentPresentation?.id == id)
        if case .shownImmediately(let returnedID) = result {
            #expect(returnedID == id)
        } else {
            Issue.record("Expected .shownImmediately, got \(result)")
        }
    }

    @Test("Second present while one is active resolves to .queuedBehind with the queued id")
    func secondPresentQueuesBehind() {
        let store = ModalStore<PresentRoute>()
        _ = store.present(.alpha, style: .sheet)

        let queuedResult = store.present(.bravo, style: .sheet)

        #expect(queuedResult.isQueuedBehind)
        #expect(queuedResult.isShownImmediately == false)

        guard let queuedID = queuedResult.presentationID else {
            Issue.record("Expected a queued presentationID, got nil for \(queuedResult)")
            return
        }
        #expect(store.queuedPresentations.first?.id == queuedID)
        // Active presentation is still the first one.
        #expect(store.currentPresentation?.route == .alpha)
    }

    @Test("Middleware-cancelled present surfaces .cancelled with the rejection reason")
    func cancelledPresentSurfacesReason() {
        let middleware = AnyModalMiddleware<PresentRoute>(
            willExecute: { command, _, _ in
                .cancel(.middleware(debugName: "gate", command: command))
            }
        )
        let store = ModalStore<PresentRoute>(
            configuration: .init(
                middlewares: [.init(middleware: middleware, debugName: "gate")]
            )
        )

        let result = store.present(.alpha, style: .sheet)

        if case .cancelled(let reason) = result {
            if case .middleware(let debugName, _) = reason {
                #expect(debugName == "gate")
            } else {
                Issue.record("Expected .middleware reason, got \(reason)")
            }
        } else {
            Issue.record("Expected .cancelled result, got \(result)")
        }
        #expect(result.presentationID == nil)
        #expect(store.currentPresentation == nil)
    }

    @Test("@discardableResult keeps existing call-sites compiling")
    func discardableResultKeepsCallSitesCompiling() {
        let store = ModalStore<PresentRoute>()
        // No `let result =`, no `_ =` — must still compile because
        // present is annotated `@discardableResult`.
        store.present(.alpha, style: .sheet)
        #expect(store.currentPresentation?.route == .alpha)
    }
}
