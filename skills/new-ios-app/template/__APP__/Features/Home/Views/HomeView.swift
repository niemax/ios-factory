import SwiftUI

struct HomeView: View {
    @Environment(Coordinator<HomeRoute>.self) private var coordinator

    var body: some View {
        ContentUnavailableView("__DISPLAY_NAME__", systemImage: "sparkles")
            .navigationTitle("Home")
            .toolbar {
                Button("Settings", systemImage: "gearshape") {
                    coordinator.push(.settings)
                }
            }
    }
}
