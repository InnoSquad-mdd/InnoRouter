import Observation
import SwiftUI

/// Marker protocol for the discrete steps of a `FlowCoordinator`-driven
/// flow.
///
/// Adopters are typically value-typed enums whose case order tracks
/// step progression. The required `index` property exists so the
/// coordinator can advance / rewind in O(1) without depending on
/// `CaseIterable`'s declaration order.
public protocol FlowStep: Hashable, CaseIterable, Sendable {
    /// Zero-based ordinal of the step within the flow. Steps with
    /// adjacent indices are siblings in the progression order; gaps
    /// allow non-linear flows where some steps are skipped.
    var index: Int { get }
}

/// A presentation-layer protocol for ordered, multi-step flows
/// (onboarding, sign-up, KYC checklists, etc.).
///
/// `FlowCoordinator` complements `FlowStore` rather than replacing it:
/// `FlowStore` owns the typed navigation/modal stacks behind a flow,
/// while `FlowCoordinator` focuses on the *step* progression — what's
/// the next step, what's already complete, when does the flow finish.
///
/// ## Platform availability
///
/// This protocol and its `FlowCoordinatorView` companion are available
/// on every InnoRouter-supported platform. The view relies on plain
/// `VStack` + `ProgressView` (without `NavigationSplitView`), so it
/// does not require the watchOS fallback that ``NavigationSplitHost``
/// needs.
///
/// ## Conforming
///
/// Conformers are reference types that drive their own `currentStep`
/// state; the protocol is `@MainActor`-isolated because SwiftUI
/// rendering runs on the main actor.
///
/// ```swift
/// @Observable @MainActor
/// final class SignUpCoordinator: FlowCoordinator {
///     enum Step: Int, FlowStep { case email, password, profile
///         var index: Int { rawValue }
///     }
///     var currentStep: Step = .email
///     var completedSteps: Set<Step> = []
///     var onComplete: ((Profile) -> Void)?
///     func complete(with profile: Profile) { onComplete?(profile) }
/// }
/// ```
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

