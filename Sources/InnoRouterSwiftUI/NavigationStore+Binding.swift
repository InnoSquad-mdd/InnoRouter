// MARK: - NavigationStore+Binding.swift
// InnoRouterSwiftUI - SwiftUI Binding accessors layered over
// NavigationStore: pathBinding, pathBinding(policy:), and the
// CasePath-keyed binding(case:) helper.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// Extracted from NavigationStore.swift in the 4.1.0 cleanup so the
// store core does not have to host the SwiftUI Binding glue.
// Bindings remain stateless — every set routes through the
// existing command pipeline, so middleware and telemetry observe
// them identically to direct execute(...) calls.

import SwiftUI

import InnoRouterCore

extension NavigationStore {

    /// A binding wired to the store's current path.
    ///
    /// Reads return ``state``'s `.path` snapshot. Writes route
    /// through the internal reconcile path, which folds prefix
    /// shrinks and prefix expands into the matching command(s)
    /// and delegates non-prefix mismatches to the store's
    /// configured ``NavigationPathMismatchPolicy``.
    public var pathBinding: Binding<[R]> {
        Binding(
            get: { self.state.path },
            set: { newPath in
                self.reconcileNavigationPath(with: newPath)
            }
        )
    }

    /// A path binding that overrides the store-wide
    /// ``NavigationPathMismatchPolicy`` for any non-prefix
    /// reconciliations driven through this binding only.
    ///
    /// Use this when one specific binding site needs a different
    /// mismatch behavior than the store's default — for example,
    /// `.ignore` on a binding that is known to receive transient
    /// non-prefix writes during a sheet dismissal, while every
    /// other binding stays on the configured `.replace` /
    /// `.assertAndReplace` policy.
    ///
    /// The override applies *only* to reconciliations triggered by
    /// writes through the returned binding. Writes that flow
    /// through ``execute(_:)``, ``executeBatch(_:stopOnFailure:)``,
    /// or any other entry point continue to use
    /// ``NavigationStoreConfiguration/pathMismatchPolicy``.
    public func pathBinding(
        policy: NavigationPathMismatchPolicy<R>
    ) -> Binding<[R]> {
        Binding(
            get: { self.state.path },
            set: { newPath in
                self.reconcileNavigationPath(
                    with: newPath,
                    policyOverride: policy
                )
            }
        )
    }

    /// A binding that reflects the top-of-stack route when it matches the given case.
    ///
    /// Writing a non-nil value pushes the embedded route through the regular command
    /// pipeline when the active destination is a different case. When the top
    /// route already matches the case, the binding replaces that top route in
    /// place instead of pushing a duplicate screen. Writing `nil` pops the top
    /// route only when it currently matches the case — other stack states are
    /// left untouched.
    public func binding<Value>(case casePath: CasePath<R, Value>) -> Binding<Value?> {
        Binding(
            get: { [weak self] in
                self?.state.path.last.flatMap(casePath.extract)
            },
            set: { [weak self] newValue in
                guard let self else { return }
                if let value = newValue {
                    let route = casePath.embed(value)
                    if let currentRoute = self.state.path.last,
                       casePath.extract(currentRoute) != nil {
                        guard currentRoute != route else { return }
                        let replacementPath = Array(self.state.path.dropLast()) + [route]
                        _ = self.execute(.replace(replacementPath))
                    } else {
                        _ = self.execute(.push(route))
                    }
                } else if self.state.path.last.flatMap(casePath.extract) != nil {
                    _ = self.execute(.pop)
                }
            }
        )
    }
}
