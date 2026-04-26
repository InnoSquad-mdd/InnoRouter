import OSLog

// MARK: - DuplicateDispatcherDetection.swift
// InnoRouterSwiftUI - shared fail-fast helper for the three
// `*EnvironmentStorage` types that key dispatchers by Route type.
//
// Each `NavigationHost` / `ModalHost` / `FlowHost` owns its own
// `*EnvironmentStorage` instance through `@State`, so SwiftUI scopes
// the dispatcher table to the host's view subtree. The
// `*EnvironmentStorage` setters are still called on every environment
// update. Some hosts allocate a fresh dispatcher wrapper during
// `body`, so dispatcher identity alone is not stable enough to
// distinguish a benign re-registration from the genuinely problematic
// case: a different owner writing to the same `(R.Type)` slot in the
// same storage instance.

@MainActor
let duplicateDispatcherLogger = Logger(
    subsystem: "io.innosquad.innorouter",
    category: "duplicate-dispatcher"
)

/// Dispatcher plus stable owner identity for a route-type slot.
///
/// The dispatcher may be freshly allocated by a host `body`; the
/// owner identity is the authority (`NavigationStore`, `ModalStore`,
/// `FlowStore`, or `Coordinator`) whose registration is allowed to
/// refresh across SwiftUI updates.
@MainActor
struct DispatcherRegistration<Dispatcher: AnyObject> {
    let dispatcher: Dispatcher
    let ownerID: ObjectIdentifier
}

/// Returns `true` when `replacement` would overwrite the same key
/// with a registration owned by a different routing authority.
/// Same-owner replacements, initial sets, and clears return `false`.
///
/// Split out from ``reportDuplicateDispatcherIfNeeded(existing:replacement:keyDescription:)``
/// so the pure detection rule can be unit-tested directly without
/// triggering the `assertionFailure` trap.
@MainActor
func detectDuplicateDispatcher<Dispatcher: AnyObject>(
    existing: DispatcherRegistration<Dispatcher>?,
    replacement: DispatcherRegistration<Dispatcher>?
) -> Bool {
    guard
        let existing,
        let replacement
    else {
        return false
    }
    return existing.ownerID != replacement.ownerID
}

/// Reports a duplicate-dispatcher registration when `replacement`
/// targets the same key but is owned by a different authority from
/// `existing`. Same-owner replacements are silently allowed even when
/// the dispatcher wrapper is a fresh instance from a SwiftUI render.
///
/// In Debug builds the helper traps with `assertionFailure` so the
/// host wiring bug surfaces immediately. In Release it logs an
/// error through ``duplicateDispatcherLogger`` and then lets the
/// caller proceed with the overwrite, preserving the prior
/// behaviour for production builds while still leaving an audit
/// trail in `Console.app` / `os_log` streams.
@MainActor
func reportDuplicateDispatcherIfNeeded<Dispatcher: AnyObject>(
    existing: DispatcherRegistration<Dispatcher>?,
    replacement: DispatcherRegistration<Dispatcher>?,
    keyDescription: @autoclosure () -> String
) {
    guard detectDuplicateDispatcher(existing: existing, replacement: replacement) else {
        return
    }
    let message =
        "Duplicate dispatcher registration detected for \(keyDescription()). " +
        "A second NavigationHost / ModalHost / FlowHost is overwriting " +
        "an earlier dispatcher in the same environment scope. Each host " +
        "owns its own *EnvironmentStorage; sibling hosts that need " +
        "distinct routes should use distinct Route types or scope them " +
        "with separate environment subtrees."
    duplicateDispatcherLogger.error("\(message, privacy: .public)")
    assertionFailure(message)
}
