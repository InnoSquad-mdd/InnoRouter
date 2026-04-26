# `FlowCoordinator` vs `FlowStore`: Two Different Flows

Both types use the word "flow", but they answer different
questions. Reach for the right one — they are intentionally
*not* substitutable.

## The two questions

`FlowStore` answers: **"What is the current navigation+modal
state of this multi-screen feature?"** It owns a single array of
`RouteStep<R>` values, projected from an inner `NavigationStore`
plus `ModalStore`. Each step is either a push or a tail modal
(`.sheet` / `.cover`). The store delegates execution to the
inner authorities while keeping the projection consistent.

`FlowCoordinator` answers: **"Which step of an ordered checklist
is the user on, and is that checklist complete?"** It tracks an
ordered enum (`Step`), a `completedSteps: Set<Step>`, and emits
`onComplete(Result)` when the wizard finishes. Step transitions
(`next()`, `previous()`, `jump(to:)`) are pure local-state
mutations — `FlowCoordinator` does not push or sheet anything by
itself.

## When to use which

| Scenario | Type | Why |
|---|---|---|
| Onboarding sign-up, KYC review, multi-page wizard | `FlowCoordinator` | Step ordinal + completion semantics, no router authority |
| Checkout funnel that mixes push screens and a payment sheet | `FlowStore` | Single source of truth across nav + modal |
| Notification deep link that opens a push prefix and a modal | `FlowStore` | `FlowPlan` rehydration is the whole point of `FlowStore` |
| "Settings → Privacy → Account Deletion confirmation" flow | `FlowStore` | Modal at tail is naturally expressed as `.sheet(...)` step |
| Tab-bar progress indicator across a multi-tap form | `FlowCoordinator` | `progress: Double` and `currentStep` are step-coordinator concerns |

## Composing them

`FlowCoordinator` and `FlowStore` compose well — you can use a
`FlowCoordinator` to drive *which step* a wizard is on, and a
`FlowStore` to drive *how that step's screens* render:

```swift
@Observable @MainActor
final class SignUpCoordinator: FlowCoordinator {
    enum Step: Int, FlowStep {
        case email, password, kyc, profile
        var index: Int { rawValue }
    }
    var currentStep: Step = .email
    var completedSteps: Set<Step> = []
    var onComplete: ((Profile) -> Void)?
    let flow = FlowStore<KycRoute>()  // rendering authority for .kyc step
    func complete(with profile: Profile) {
        onComplete?(profile)
    }
}
```

Inside the view body, `currentStep` chooses *what* to render and
`flow` provides the navigation authority for the chosen step's
screens.

## Why the names are similar

The naming is admittedly a hazard for new adopters. The two
concepts arrived at different milestones — `FlowCoordinator`
predates `FlowStore` — and both speak to "multi-step user
journeys" at different levels of abstraction. A future major
release may rename `FlowCoordinator` to `StepCoordinator` or
`WizardCoordinator` to make the distinction unambiguous; the
shape of the type stays compatible with that rename.

## See also

- `FlowStore`
- `FlowCoordinator`
- `FlowStoreConfiguration`
