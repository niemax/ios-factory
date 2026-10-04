import SwiftUI

@main
struct AppEntry: App {
    init() {
        FirebaseService.start()
        Analytics.start()
    }

    var body: some Scene {
        WindowGroup {
            HomeStack()
        }
    }
}
