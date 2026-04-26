import OSLog

// MARK: - DuplicateDispatcherDetection.swift
// InnoRouterSwiftUI - shared fail-fast helper for the three
// `*EnvironmentStorage` types that key dispatchers by Route type.
//
// Each `NavigationHost` / `ModalHost` / `FlowHost` owns its own
// `*EnvironmentStorage` instance through `@State`, so SwiftUI scopes
// the dispatcher table to the host's view subtree. The
// `*EnvironmentStorage` setters are still called on every environment
// update — usually with the same dispatcher reference, which is a
// no-op. This helper distinguishes that benign case from the genuinely
// problematic one: a *different* dispatcher being written to the same
// `(R.Type)` slot in the same storage instance, which means a second
// host is overwriting an earlier sibling registration.

@MainActor
let duplicateDispatcherLogger = Logger(
    subsystem: "io.innosquad.innorouter",
    category: "duplicate-dispatcher"
)

/// Returns `true` when `replacement` would overwrite a different
/// dispatcher instance at the same key. Same-instance replacements
/// (the common case during SwiftUI environment updates) and the
/// initial-set case both return `false`.
///
/// Split out from ``reportDuplicateDispatcherIfNeeded(existing:replacement:keyDescription:)``
/// so the pure detection rule can be unit-tested directly without
/// triggering the `assertionFailure` trap.
@MainActor
func detectDuplicateDispatcher<Dispatcher: AnyObject>(
    existing: Dispatcher?,
    replacement: Dispatcher?
) -> Bool {
    guard
        let existing,
        let replacement
    else {
        return false
    }
    return existing !== replacement
}

/// Reports a duplicate-dispatcher registration when `replacement`
/// targets the same key but is a *different* instance from
/// `existing`. Same-instance replacements (the common case during
/// SwiftUI environment updates) are silently allowed.
///
/// In Debug builds the helper traps with `assertionFailure` so the
/// host wiring bug surfaces immediately. In Release it logs an
/// error through ``duplicateDispatcherLogger`` and then lets the
/// caller proceed with the overwrite, preserving the prior
/// behaviour for production builds while still leaving an audit
/// trail in `Console.app` / `os_log` streams.
@MainActor
func reportDuplicateDispatcherIfNeeded<Dispatcher: AnyObject>(
    existing: Dispatcher?,
    replacement: Dispatcher?,
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
