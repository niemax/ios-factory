import SwiftUI

struct HomeStack: View {
    @State private var coordinator = Coordinator<HomeRoute>()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView()
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .environment(coordinator)
    }
}
