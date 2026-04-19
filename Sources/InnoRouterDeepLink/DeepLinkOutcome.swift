import Foundation

import InnoRouterCore

/// Typed outcome returned by Umbrella coordinator deep-link coordination APIs.
///
/// Previously the Umbrella extensions exposed coordination decisions through a
/// coarse `Void`/`Bool` return type, forcing callers to consult side effects
/// (stack state, `pendingDeepLink`) to reconstruct what actually happened. The
/// same pipeline — `DeepLinkPipeline.decide(for:)` — already emits a
/// fine-grained `DeepLinkDecision`, so the Umbrella surface now mirrors those
/// possibilities plus the resume-specific case (`noPendingDeepLink`).
///
/// The five common cases share payload types with
/// `DeepLinkEffectHandler.Result`, so callers that migrate between Effects and
/// Umbrella deal with the same `PendingDeepLink`, `NavigationPlan`,
/// `NavigationBatchResult`, and `DeepLinkRejectionReason` values.
public enum DeepLinkCoordinationOutcome<R: Route>: Sendable, Equatable {
    /// The plan ran. `batch` carries per-command results for observability.
    case executed(plan: NavigationPlan<R>, batch: NavigationBatchResult<R>)
    /// The URL mapped to an authenticated route; the plan is held on the
    /// coordinator as `pendingDeepLink` until authorization succeeds.
    case pending(PendingDeepLink<R>)
    /// The URL was rejected by the pipeline's scheme/host policy.
    case rejected(reason: DeepLinkRejectionReason)
    /// The URL did not resolve to a route.
    case unhandled(url: URL)
    /// Resume was requested but no pending deep link is currently stored.
    case noPendingDeepLink
}
