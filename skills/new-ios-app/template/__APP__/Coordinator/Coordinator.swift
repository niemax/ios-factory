import Observation
import SwiftUI

@MainActor
@Observable
final class Coordinator<Route: Hashable> {
    var path = NavigationPath()

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
