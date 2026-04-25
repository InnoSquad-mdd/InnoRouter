import Observation
import SwiftUI

/// Marker protocol for the tabs surfaced by a `TabCoordinator`.
///
/// Adopters provide an icon and a title for each case; everything
/// else (selection, badges, switching) is handled by the coordinator
/// machinery. The default `id` implementation makes every tab its own
/// identity, so `TabView(selection:)` can use the conformer directly.
public protocol Tab: Hashable, CaseIterable, Identifiable, Sendable {
    /// SF Symbol (or asset) name rendered in the tab's `Label`.
    var icon: String { get }
    /// Human-readable label rendered alongside the icon.
    var title: String { get }
}

public extension Tab {
    var id: Self { self }
}

/// A presentation-layer protocol for tab-based navigation surfaces.
///
/// `TabCoordinator` owns the currently-selected tab and a per-tab
/// badge dictionary. It complements rather than replaces
/// `NavigationStore` / `ModalStore`: each tab usually owns its own
/// per-tab navigation stack, while the coordinator only tracks which
/// tab is in front and any unread-count overlays.
///
/// ## Platform availability
///
/// `TabCoordinatorView` renders through `TabView`, which is available
/// on every InnoRouter platform. The badge modifier degrades silently
/// on tvOS / watchOS (see the platform note inside the
/// `tabBadge(_:)` helper below) so adopters do not have to gate
/// badge state themselves.
///
/// ## Conforming
///
/// Conformers are reference types because they carry mutable
/// `selectedTab` / `tabBadges` state observed by SwiftUI. They are
/// `@MainActor`-isolated so SwiftUI binding writes stay on the main
/// thread.
///
/// ```swift
/// @Observable @MainActor
/// final class AppTabs: TabCoordinator {
///     enum TabType: String, Tab { case home, search, profile
///         var icon: String { rawValue + ".fill" }
///         var title: String { rawValue.capitalized }
///     }
///     var selectedTab: TabType = .home
///     var tabBadges: [TabType: Int] = [:]
///     @ViewBuilder
///     func content(for tab: TabType) -> some View { … }
/// }
/// ```
@MainActor
public protocol TabCoordinator: AnyObject, Observable {
    associatedtype TabType: Tab
    associatedtype TabContent: View

    var selectedTab: TabType { get set }
    var tabBadges: [TabType: Int] { get set }

    @ViewBuilder
    func content(for tab: TabType) -> TabContent
}

public extension TabCoordinator {
    func switchTab(to tab: TabType) {
        selectedTab = tab
    }

    func setBadge(_ count: Int, for tab: TabType) {
        tabBadges[tab] = count > 0 ? count : nil
    }

    func badge(for tab: TabType) -> Int? {
        tabBadges[tab]
    }

    func clearAllBadges() {
        tabBadges.removeAll()
    }
}

public struct TabCoordinatorView<C: TabCoordinator>: View {
    @Bindable private var coordinator: C

    public init(coordinator: C) {
        self.coordinator = coordinator
    }

    public var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            ForEach(Array(C.TabType.allCases), id: \.self) { tab in
                coordinator.content(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
                    .tabBadge(coordinator.tabBadges[tab])
            }
        }
    }
}

private extension View {
    // MARK: - Platform: TabView.badge(_:) is unavailable on tvOS and watchOS.
    // On those platforms we drop the badge silently so the TabCoordinator API
    // surface stays identical; on iOS / iPadOS / macOS / visionOS a non-nil,
    // positive count is rendered through SwiftUI's native badge modifier.
    @ViewBuilder
    func tabBadge(_ count: Int?) -> some View {
#if os(tvOS) || os(watchOS)
        self
#else
        if let count, count > 0 {
            self.badge(count)
        } else {
            self
        }
#endif
    }
}
