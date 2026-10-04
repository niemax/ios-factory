import Testing
@testable import __APP__

@MainActor
struct CoordinatorTests {
    @Test func pushPopAndPopToRoot() {
        let coordinator = Coordinator<HomeRoute>()
        coordinator.push(.settings)
        coordinator.push(.settings)
        #expect(coordinator.path.count == 2)
        coordinator.pop()
        #expect(coordinator.path.count == 1)
        coordinator.popToRoot()
        #expect(coordinator.path.isEmpty)
        coordinator.pop()
        #expect(coordinator.path.isEmpty)
    }
}
