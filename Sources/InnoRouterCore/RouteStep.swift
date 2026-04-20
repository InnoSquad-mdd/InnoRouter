/// A single entry in a unified `FlowStore` path that can represent either a
/// navigation push or a modal presentation.
///
/// `RouteStep` gives callers a single serialisable value type that models the
/// end-to-end progression of a flow (login wizard, checkout flow, etc.) where
/// individual steps may be either pushed onto the navigation stack or
/// presented as modal sheets / full-screen covers. `FlowStore` keeps an array
/// of `RouteStep`s and fans out individual steps to its inner
/// `NavigationStore` and `ModalStore`.
public enum RouteStep<R: Route>: Sendable, Hashable {
    /// The route was pushed onto the navigation stack.
    case push(R)
    /// The route is being presented as a sheet modal.
    case sheet(R)
    /// The route is being presented as a full-screen cover modal.
    case cover(R)

    /// The concrete route carried by this step, regardless of presentation kind.
    public var route: R {
        switch self {
        case .push(let route), .sheet(let route), .cover(let route):
            return route
        }
    }

    /// Modal presentation style associated with this step, or `nil` for `.push`.
    public var modalStyle: ModalPresentationStyle? {
        switch self {
        case .push: return nil
        case .sheet: return .sheet
        case .cover: return .fullScreenCover
        }
    }

    /// True when this step represents a modal presentation.
    public var isModal: Bool {
        modalStyle != nil
    }
}
