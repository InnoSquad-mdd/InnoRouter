// MARK: - OrnamentModifier.swift
// InnoRouterSwiftUI — cross-platform ornament view modifier that bridges
// InnoRouterCore's OrnamentAnchor to SwiftUI's ornament(...) modifier on
// visionOS, and degrades to a no-op elsewhere.
// Copyright © 2026 Inno Squad. All rights reserved.

import SwiftUI

import InnoRouterCore

public extension View {
    /// Attaches an ornament to this view on visionOS, using the
    /// supplied ``OrnamentAnchor`` for placement.
    ///
    /// - Parameters:
    ///   - anchor: where the ornament attaches and how its content is
    ///     aligned.
    ///   - content: ornament content builder.
    ///
    /// On every non-visionOS platform this modifier is a no-op, so
    /// call sites can stay cross-platform without `#if` branches.
    @ViewBuilder
    func innoRouterOrnament<OrnamentContent: View>(
        _ anchor: OrnamentAnchor,
        @ViewBuilder content: () -> OrnamentContent
    ) -> some View {
        // MARK: - Platform: visionOS is the only platform exposing
        // `ornament(attachmentAnchor:contentAlignment:ornament:)`. On
        // the other five platforms the modifier passes `self` through
        // unchanged.
        #if os(visionOS)
        self.ornament(
            attachmentAnchor: anchor.swiftUIAttachmentAnchor,
            contentAlignment: anchor.swiftUIAlignment,
            ornament: content
        )
        #else
        self
        #endif
    }
}

#if os(visionOS)
extension OrnamentAnchor {
    /// Translates the Core-level anchor into SwiftUI's
    /// `OrnamentAttachmentAnchor` positional cases.
    var swiftUIAttachmentAnchor: OrnamentAttachmentAnchor {
        switch anchor {
        case .bottom: return .scene(.bottom)
        case .top: return .scene(.top)
        case .leading: return .scene(.leading)
        case .trailing: return .scene(.trailing)
        case .bottomLeading: return .scene(.bottomLeading)
        case .bottomTrailing: return .scene(.bottomTrailing)
        case .topLeading: return .scene(.topLeading)
        case .topTrailing: return .scene(.topTrailing)
        }
    }

    /// Translates the Core-level alignment into SwiftUI's `Alignment3D`,
    /// which is the positional type the visionOS `ornament` modifier
    /// accepts for `contentAlignment`.
    var swiftUIAlignment: Alignment3D {
        switch alignment {
        case .center: return .center
        case .bottom: return .bottom
        case .top: return .top
        case .leading: return .leading
        case .trailing: return .trailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        }
    }
}
#endif
