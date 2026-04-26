// MARK: - FlowPlanValidationTests.swift
// InnoRouterTests - up-front validation for FlowPlan(validating:) and Codable decode
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation
import Testing

import InnoRouter
import InnoRouterCore

private enum ValidationRoute: Route, Codable {
    case home
    case detail
    case settings
    case profileSheet
    case helpSheet
}

@Suite("FlowPlan validation")
struct FlowPlanValidationTests {

    // MARK: - init(validating:)

    @Test("validating init accepts an empty sequence")
    func validatingInit_acceptsEmpty() throws {
        let plan = try FlowPlan<ValidationRoute>(validating: [])
        #expect(plan.steps.isEmpty)
    }

    @Test("validating init accepts a push-only sequence")
    func validatingInit_acceptsPushOnly() throws {
        let plan = try FlowPlan<ValidationRoute>(validating: [
            .push(.home),
            .push(.detail),
            .push(.settings),
        ])
        #expect(plan.steps.count == 3)
    }

    @Test("validating init accepts a tail-only modal sequence")
    func validatingInit_acceptsTailOnlyModal() throws {
        let plan = try FlowPlan<ValidationRoute>(validating: [
            .push(.home),
            .push(.detail),
            .sheet(.profileSheet),
        ])
        #expect(plan.steps.last?.isModal == true)
    }

    @Test("validating init rejects more than one modal")
    func validatingInit_rejectsMultipleModals() {
        #expect(throws: FlowPlanValidationError.tooManyModals) {
            try FlowPlan<ValidationRoute>(validating: [
                .push(.home),
                .sheet(.profileSheet),
                .sheet(.helpSheet),
            ])
        }
    }

    @Test("validating init rejects a non-tail modal")
    func validatingInit_rejectsModalNotAtTail() {
        #expect(throws: FlowPlanValidationError.modalNotAtTail) {
            try FlowPlan<ValidationRoute>(validating: [
                .sheet(.profileSheet),
                .push(.detail),
            ])
        }
    }

    // MARK: - validate(_:)

    @Test("validate succeeds on a valid sequence")
    func validate_succeedsOnValidSequence() throws {
        try FlowPlan<ValidationRoute>.validate([
            .push(.home),
            .cover(.helpSheet),
        ])
    }

    @Test("validate throws modalNotAtTail on a non-tail modal")
    func validate_throwsModalNotAtTail() {
        #expect(throws: FlowPlanValidationError.modalNotAtTail) {
            try FlowPlan<ValidationRoute>.validate([
                .sheet(.profileSheet),
                .push(.home),
            ])
        }
    }

    // MARK: - Codable roundtrip

    @Test("Codable roundtrip preserves a valid plan")
    func codable_roundtripsValidPlan() throws {
        let plan = try FlowPlan<ValidationRoute>(validating: [
            .push(.home),
            .push(.detail),
            .cover(.helpSheet),
        ])

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(FlowPlan<ValidationRoute>.self, from: data)

        #expect(decoded == plan)
    }

    @Test("Codable decode rejects a multi-modal payload")
    func codable_rejectsMultiModalPayload() throws {
        // Synthesised encoding for an *invalid* plan, produced by
        // bypassing the validating init.
        let invalidPlan = FlowPlan<ValidationRoute>(steps: [
            .sheet(.profileSheet),
            .sheet(.helpSheet),
        ])
        let data = try JSONEncoder().encode(invalidPlan)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(FlowPlan<ValidationRoute>.self, from: data)
        }
    }

    @Test("Codable decode rejects a modal-not-at-tail payload")
    func codable_rejectsModalNotAtTailPayload() throws {
        let invalidPlan = FlowPlan<ValidationRoute>(steps: [
            .sheet(.profileSheet),
            .push(.detail),
        ])
        let data = try JSONEncoder().encode(invalidPlan)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(FlowPlan<ValidationRoute>.self, from: data)
        }
    }
}
