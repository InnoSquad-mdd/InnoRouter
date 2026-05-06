// MARK: - ModalStore+Binding.swift
// InnoRouterSwiftUI - case-typed SwiftUI binding helper for
// ModalStore.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// Extracted from ModalStore.swift in the 4.1.0 cleanup so the
// store core does not have to host the SwiftUI Binding glue.
// The binding remains stateless — every set routes through the
// existing command pipeline so middleware and telemetry observe
// it identically to direct execute(...) calls.

import SwiftUI

import InnoRouterCore

extension ModalStore {

    /// A binding that reflects the current presentation when it matches the
    /// given case and presentation style.
    ///
    /// Writing a non-nil value presents the embedded route through the regular command
    /// pipeline with the supplied style, so middleware and telemetry observe the
    /// presentation. When the active presentation already matches the same case
    /// and style, the binding replaces it in place rather than queueing a
    /// duplicate presentation. Writing `nil` dismisses the current presentation
    /// only when both the case and style match.
    public func binding<Value>(
        case casePath: CasePath<M, Value>,
        style: ModalPresentationStyle = .sheet
    ) -> Binding<Value?> {
        Binding(
            get: { [weak self] in
                guard let presentation = self?.currentPresentation,
                      presentation.style == style else { return nil }
                return casePath.extract(presentation.route)
            },
            set: { [weak self] newValue in
                guard let self else { return }
                if let value = newValue {
                    let route = casePath.embed(value)
                    if let currentPresentation = self.currentPresentation,
                       currentPresentation.style == style,
                       casePath.extract(currentPresentation.route) != nil {
                        let replacement = ModalPresentation(
                            id: currentPresentation.id,
                            route: route,
                            style: style
                        )
                        guard replacement != currentPresentation else { return }
                        _ = self.execute(.replaceCurrent(replacement))
                    } else {
                        self.present(route, style: style)
                    }
                } else if let currentPresentation = self.currentPresentation,
                          currentPresentation.style == style,
                          casePath.extract(currentPresentation.route) != nil {
                    self.dismissCurrent(reason: .systemDismiss)
                }
            }
        )
    }
}
