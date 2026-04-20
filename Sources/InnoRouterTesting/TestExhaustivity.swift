// MARK: - TestExhaustivity.swift
// InnoRouterTesting - strictness mode for host-less test stores
// Copyright © 2026 Inno Squad. All rights reserved.

/// Controls how strictly a test store insists that every observed event be
/// asserted before the store is deallocated.
///
/// InnoRouter's test stores follow TCA's `TestStore` exhaustivity model:
/// events collected from the underlying authority (e.g. `onChange`,
/// `onPresented`, `onPathChanged`) accumulate in an internal queue. Each
/// `receive(...)` call dequeues the next event and asserts a predicate. In
/// `.strict` mode any leftover events — or any events that arrive after an
/// `expectNoMoreEvents` / `finish` call — are reported as Swift Testing
/// issues at the store's deinitialization.
public enum TestExhaustivity: Sendable, Equatable {
    /// Every observed event must be drained through `receive(...)` before the
    /// test store deallocates. Leftover events fail the test. This is the
    /// default and matches TCA's `exhaustive` semantics.
    case strict

    /// The test store still delivers events through `receive(...)`, but
    /// leftover events at deallocation are silently discarded. Useful for
    /// incremental migrations of large legacy suites.
    case off
}
