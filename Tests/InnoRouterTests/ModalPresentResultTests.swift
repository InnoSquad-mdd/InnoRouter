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

    @Test("Middleware-rewritten present reports the effective presentation id")
    func rewrittenPresentReportsEffectiveID() {
        let rewrittenID = UUID()
        let middleware = AnyModalMiddleware<PresentRoute>(
            willExecute: { command, _, _ in
                if case .present(let presentation) = command {
                    return .proceed(
                        .present(
                            ModalPresentation(
                                id: rewrittenID,
                                route: presentation.route,
                                style: .fullScreenCover
                            )
                        )
                    )
                }
                return .proceed(command)
            }
        )
        let store = ModalStore<PresentRoute>(
            configuration: .init(middlewares: [.init(middleware: middleware)])
        )

        let result = store.present(.alpha, style: .sheet)

        #expect(result.presentationID == rewrittenID)
        #expect(store.currentPresentation?.id == rewrittenID)
        #expect(store.currentPresentation?.style == .fullScreenCover)
    }

    @Test("Middleware-rewritten present-to-replaceCurrent reports the replacement id")
    func rewrittenPresentToReplaceCurrentReportsEffectiveID() {
        let replacementID = UUID()
        let middleware = AnyModalMiddleware<PresentRoute>(
            willExecute: { command, _, _ in
                if case .present(let presentation) = command,
                   presentation.route == .bravo {
                    return .proceed(
                        .replaceCurrent(
                            ModalPresentation(
                                id: replacementID,
                                route: presentation.route,
                                style: .fullScreenCover
                            )
                        )
                    )
                }
                return .proceed(command)
            }
        )
        let store = ModalStore<PresentRoute>(
            configuration: .init(middlewares: [.init(middleware: middleware)])
        )
        _ = store.present(.alpha, style: .sheet)

        let result = store.present(.bravo, style: .sheet)

        #expect(result.presentationID == replacementID)
        #expect(store.currentPresentation?.id == replacementID)
        #expect(store.currentPresentation?.route == .bravo)
        #expect(store.currentPresentation?.style == .fullScreenCover)
    }

    @Test("Middleware-rewritten present-to-dismissCurrent reports no presentation but can mutate state")
    func rewrittenPresentToDismissCurrentReportsRewriteWithoutPresentation() {
        let middleware = AnyModalMiddleware<PresentRoute>(
            willExecute: { command, _, _ in
                if case .present(let presentation) = command,
                   presentation.route == .bravo {
                    return .proceed(.dismissCurrent(reason: .dismiss))
                }
                return .proceed(command)
            }
        )
        let store = ModalStore<PresentRoute>(
            configuration: .init(middlewares: [.init(middleware: middleware)])
        )
        _ = store.present(.alpha, style: .sheet)
        _ = store.present(.alpha, style: .sheet)

        let result = store.present(.bravo, style: .sheet)

        #expect(result == .rewrittenWithoutPresentation(command: .dismissCurrent(reason: .dismiss)))
        #expect(result.presentationID == nil)
        #expect(result.isShownImmediately == false)
        #expect(result.isQueuedBehind == false)
        #expect(store.currentPresentation?.route == .alpha)
        #expect(store.queuedPresentations.isEmpty)
    }

    @Test("Middleware-rewritten present-to-dismissAll reports no presentation and clears modal state")
    func rewrittenPresentToDismissAllReportsRewriteWithoutPresentation() {
        let middleware = AnyModalMiddleware<PresentRoute>(
            willExecute: { command, _, _ in
                if case .present(let presentation) = command,
                   presentation.route == .bravo {
                    return .proceed(.dismissAll)
                }
                return .proceed(command)
            }
        )
        let store = ModalStore<PresentRoute>(
            configuration: .init(middlewares: [.init(middleware: middleware)])
        )
        _ = store.present(.alpha, style: .sheet)
        _ = store.present(.alpha, style: .sheet)

        let result = store.present(.bravo, style: .sheet)

        #expect(result == .rewrittenWithoutPresentation(command: .dismissAll))
        #expect(result.presentationID == nil)
        #expect(result.isShownImmediately == false)
        #expect(result.isQueuedBehind == false)
        #expect(store.currentPresentation == nil)
        #expect(store.queuedPresentations.isEmpty)
    }

    @Test("Middleware-rewritten present-to-noop reports noop only when the store no-ops")
    func rewrittenPresentToNoopReportsNoop() {
        let middleware = AnyModalMiddleware<PresentRoute>(
            willExecute: { command, _, _ in
                if case .present(let presentation) = command {
                    return .proceed(.replaceCurrent(presentation))
                }
                return .proceed(command)
            }
        )
        let store = ModalStore<PresentRoute>(
            configuration: .init(middlewares: [.init(middleware: middleware)])
        )

        let result = store.present(.alpha, style: .sheet)

        #expect(result == .noop)
        #expect(result.presentationID == nil)
        #expect(result.isShownImmediately == false)
        #expect(result.isQueuedBehind == false)
        #expect(store.currentPresentation == nil)
        #expect(store.queuedPresentations.isEmpty)
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
