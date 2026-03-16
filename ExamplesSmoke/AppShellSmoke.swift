import SwiftUI

import InnoRouter

enum HomeShellRoute: Route {
    case dashboard
    case checkoutFlow
}

enum SettingsShellRoute: Route {
    case list
    case detail
}

enum AppShellModalRoute: Route {
    case profile
    case onboarding
}

enum AppShellTab: String, InnoRouter.Tab {
    case home
    case settings

    var icon: String {
        switch self {
        case .home: "house"
        case .settings: "gearshape"
        }
    }

    var title: String {
        rawValue.capitalized
    }
}

enum CheckoutStep: Int, FlowStep, CaseIterable {
    case cart
    case shipping
    case review

    var index: Int { rawValue }
}

@Observable
@MainActor
final class CheckoutFlowCoordinator: FlowCoordinator {
    typealias Step = CheckoutStep
    typealias Result = String

    var currentStep: CheckoutStep = .cart
    var completedSteps: Set<CheckoutStep> = []
    var onComplete: ((String) -> Void)?

    func complete(with result: String) {
        onComplete?(result)
    }
}

@Observable
@MainActor
final class AppShellCoordinator: TabCoordinator {
    typealias TabType = AppShellTab
    typealias TabContent = AnyView

    var selectedTab: AppShellTab = .home
    var tabBadges: [AppShellTab: Int] = [.settings: 2]

    let homeStore = NavigationStore<HomeShellRoute>()
    let settingsStore = NavigationStore<SettingsShellRoute>()
    let modalStore = ModalStore<AppShellModalRoute>()
    let checkoutFlow = CheckoutFlowCoordinator()

    func content(for tab: AppShellTab) -> AnyView {
        switch tab {
        case .home:
            return AnyView(AppShellHomeScene(coordinator: self))
        case .settings:
            return AnyView(
                NavigationHost(store: settingsStore) { route in
                    switch route {
                    case .list:
                        SettingsRootView()
                    case .detail:
                        Text("Settings Detail")
                    }
                } root: {
                    SettingsRootView()
                }
            )
        }
    }
}

struct AppShellExampleView: View {
    @State private var coordinator = AppShellCoordinator()

    var body: some View {
        TabCoordinatorView(coordinator: coordinator)
    }
}

struct AppShellHomeScene: View {
    @Bindable var coordinator: AppShellCoordinator

    var body: some View {
        ModalHost(store: coordinator.modalStore) { route in
            switch route {
            case .profile:
                AppShellProfileModalView()
                    .presentationDetents([.medium])
            case .onboarding:
                AppShellOnboardingModalView()
            }
        } content: {
            NavigationHost(store: coordinator.homeStore) { route in
                switch route {
                case .dashboard:
                    HomeDashboardView()
                case .checkoutFlow:
                    FlowCoordinatorView(coordinator: coordinator.checkoutFlow) { step in
                        Text("Checkout step: \(step.index + 1)")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } root: {
                HomeDashboardView()
            }
        }
    }
}

struct HomeDashboardView: View {
    @EnvironmentNavigationIntent(HomeShellRoute.self) private var navigationIntent
    @EnvironmentModalIntent(AppShellModalRoute.self) private var modalIntent

    var body: some View {
        VStack(spacing: 12) {
            Button("Start Checkout Flow") {
                navigationIntent.send(.go(.checkoutFlow))
            }
            Button("Show Profile Sheet") {
                modalIntent.send(.present(.profile, style: .sheet))
            }
            Button("Show Onboarding Full Screen") {
                modalIntent.send(.present(.onboarding, style: .fullScreenCover))
            }
        }
        .navigationTitle("Home")
    }
}

struct SettingsRootView: View {
    @EnvironmentNavigationIntent(SettingsShellRoute.self) private var navigationIntent

    var body: some View {
        VStack(spacing: 12) {
            Button("Open Settings Detail") {
                navigationIntent.send(.go(.detail))
            }
        }
        .navigationTitle("Settings")
    }
}

struct AppShellProfileModalView: View {
    @EnvironmentModalIntent(AppShellModalRoute.self) private var modalIntent

    var body: some View {
        VStack(spacing: 12) {
            Text("Profile Modal")
            Button("Dismiss") {
                modalIntent.send(.dismiss)
            }
        }
        .padding()
    }
}

struct AppShellOnboardingModalView: View {
    @EnvironmentModalIntent(AppShellModalRoute.self) private var modalIntent

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Onboarding Full Screen")
                Button("Dismiss") {
                    modalIntent.send(.dismiss)
                }
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }
}
