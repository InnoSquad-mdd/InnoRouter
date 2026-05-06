// MARK: - ModalDismissalReasonMiddlewareTests.swift
// InnoRouterTests - new ModalDismissalReason.middlewareCancelled
// case carries a typed reason description for analytics.
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing

import InnoRouterCore

@Suite("ModalDismissalReason.middlewareCancelled")
struct ModalDismissalReasonMiddlewareTests {

    @Test("middlewareCancelled is distinct from systemDismiss")
    func middlewareCancelled_isDistinctFromSystemDismiss() {
        let cancelled: ModalDismissalReason =
            .middlewareCancelled(reasonDescription: "AB-test guard")
        #expect(cancelled != .systemDismiss)
        #expect(cancelled != .dismiss)
        #expect(cancelled != .dismissAll)
    }

    @Test("middlewareCancelled equality compares reason descriptions")
    func middlewareCancelled_equality() {
        let a: ModalDismissalReason =
            .middlewareCancelled(reasonDescription: "AB-test guard")
        let b: ModalDismissalReason =
            .middlewareCancelled(reasonDescription: "AB-test guard")
        let c: ModalDismissalReason =
            .middlewareCancelled(reasonDescription: "different")

        #expect(a == b)
        #expect(a != c)
    }
}
