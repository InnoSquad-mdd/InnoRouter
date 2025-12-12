import Observation
import SwiftUI

public protocol Tab: Hashable, CaseIterable, Identifiable, Sendable {
    var icon: String { get }
    var title: String { get }
}

public extension Tab {
    var id: Self { self }
}

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
                    .badge(coordinator.tabBadges[tab] ?? 0)
            }
        }
    }
}

