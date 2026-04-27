// MARK: - FlowCoordinatorCoreTests.swift
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

// MARK: - FlowCoordinator Tests

@Suite("FlowCoordinator Tests")
struct FlowCoordinatorTests {
    
    enum TestStep: Int, FlowStep, CaseIterable {
        case step1 = 0
        case step2 = 1
        case step3 = 2
        
        var index: Int { rawValue }
    }
    
    @Observable
    @MainActor
    final class TestFlowCoordinator: FlowCoordinator {
        typealias Step = TestStep
        typealias Result = String
        
        var currentStep: TestStep = .step1
        var completedSteps: Set<TestStep> = []
        var onComplete: ((String) -> Void)?
        
        func canProceed(from step: TestStep) -> Bool {
            true
        }
        
        func complete(with result: String) {
            onComplete?(result)
        }
    }
    
    @Test("FlowCoordinator starts at first step")
    @MainActor
    func testInitialStep() {
        let coordinator = TestFlowCoordinator()
        
        #expect(coordinator.currentStep == .step1)
        #expect(coordinator.isAtStart)
        #expect(!coordinator.isAtEnd)
    }
    
    @Test("FlowCoordinator progresses through steps")
    @MainActor
    func testProgress() {
        let coordinator = TestFlowCoordinator()
        
        coordinator.next()
        #expect(coordinator.currentStep == .step2)
        #expect(coordinator.completedSteps.contains(.step1))
        
        coordinator.next()
        #expect(coordinator.currentStep == .step3)
        #expect(coordinator.isAtEnd)
    }
    
    @Test("FlowCoordinator can go back")
    @MainActor
    func testPrevious() {
        let coordinator = TestFlowCoordinator()
        coordinator.next()
        coordinator.next()
        
        coordinator.previous()
        #expect(coordinator.currentStep == .step2)
    }
    
    @Test("FlowCoordinator reset clears progress")
    @MainActor
    func testReset() {
        let coordinator = TestFlowCoordinator()
        coordinator.next()
        coordinator.next()
        
        coordinator.reset()
        
        #expect(coordinator.currentStep == .step1)
        #expect(coordinator.completedSteps.isEmpty)
    }
    
    @Test("FlowCoordinator progress calculation")
    @MainActor
    func testProgressCalculation() {
        let coordinator = TestFlowCoordinator()
        
        #expect(coordinator.progress == 1.0 / 3.0)
        
        coordinator.next()
        #expect(coordinator.progress == 2.0 / 3.0)
        
        coordinator.next()
        #expect(coordinator.progress == 1.0)
    }
}
