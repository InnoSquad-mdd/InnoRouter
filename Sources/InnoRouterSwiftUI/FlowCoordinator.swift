import Observation
import SwiftUI

public protocol FlowStep: Hashable, CaseIterable, Sendable {
    var index: Int { get }
}

@MainActor
public protocol FlowCoordinator: AnyObject, Observable {
    associatedtype Step: FlowStep
    associatedtype Result

    var currentStep: Step { get set }
    var completedSteps: Set<Step> { get set }
    var onComplete: ((Result) -> Void)? { get set }

    func canProceed(from step: Step) -> Bool
    func complete(with result: Result)
}

public extension FlowCoordinator {
    var totalSteps: Int { Step.allCases.count }

    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep.index + 1) / Double(totalSteps)
    }

    var isAtStart: Bool { currentStep.index == 0 }
    var isAtEnd: Bool { currentStep.index == totalSteps - 1 }

    func next() {
        guard canProceed(from: currentStep) else { return }

        completedSteps.insert(currentStep)

        let allSteps = Array(Step.allCases)
        let currentIndex = currentStep.index
        if currentIndex < allSteps.count - 1,
           let nextStep = allSteps.first(where: { $0.index == currentIndex + 1 }) {
            currentStep = nextStep
        }
    }

    func previous() {
        let allSteps = Array(Step.allCases)
        let currentIndex = currentStep.index
        if currentIndex > 0,
           let prevStep = allSteps.first(where: { $0.index == currentIndex - 1 }) {
            currentStep = prevStep
        }
    }

    func jump(to step: Step) {
        if completedSteps.contains(step) || step.index <= currentStep.index + 1 {
            currentStep = step
        }
    }

    func reset() {
        completedSteps.removeAll()
        if let firstStep = Step.allCases.first {
            currentStep = firstStep
        }
    }

    func canProceed(from step: Step) -> Bool { true }
}

public struct FlowCoordinatorView<C: FlowCoordinator, Content: View>: View {
    @Bindable private var coordinator: C
    private let content: (C.Step) -> Content
    private let showProgress: Bool

    public init(
        coordinator: C,
        showProgress: Bool = true,
        @ViewBuilder content: @escaping (C.Step) -> Content
    ) {
        self.coordinator = coordinator
        self.showProgress = showProgress
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showProgress {
                ProgressView(value: coordinator.progress)
                    .padding(.horizontal)
                    .animation(.easeInOut, value: coordinator.progress)
            }

            content(coordinator.currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut, value: coordinator.currentStep.index)
        }
    }
}

