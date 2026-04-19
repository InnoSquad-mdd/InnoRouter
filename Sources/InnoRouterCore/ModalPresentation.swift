import Foundation

/// Supported modal presentation styles.
public enum ModalPresentationStyle: Sendable, Hashable {
    /// Presented as a sheet.
    case sheet
    /// Presented as a full-screen cover.
    ///
    /// Platforms that do not support `fullScreenCover` natively fall back to
    /// sheet semantics at the SwiftUI layer.
    case fullScreenCover
}

/// An identifiable modal presentation pairing a route with a presentation style.
///
/// `ModalPresentation` is the value type carried through the modal command
/// pipeline and surfaced in lifecycle callbacks. It lives in `InnoRouterCore`
/// so that modal-aware command abstractions (`ModalCommand`) remain at the
/// same layer as their navigation siblings (`NavigationCommand`).
public struct ModalPresentation<M: Route>: Identifiable, Sendable, Hashable {
    /// Stable identifier unique per presentation instance.
    public let id: UUID
    /// Route rendered by the presentation.
    public let route: M
    /// Style the host will render the presentation with.
    public let style: ModalPresentationStyle

    /// Creates a modal presentation.
    public init(
        id: UUID = UUID(),
        route: M,
        style: ModalPresentationStyle
    ) {
        self.id = id
        self.route = route
        self.style = style
    }
}

/// Reason surfaced when the active modal presentation is dismissed.
public enum ModalDismissalReason: Sendable, Equatable {
    /// Dismissed by an explicit `dismiss` intent.
    case dismiss
    /// Dismissed because the entire modal stack was cleared.
    case dismissAll
    /// Dismissed by the system, such as swipe-to-dismiss.
    case systemDismiss
}
