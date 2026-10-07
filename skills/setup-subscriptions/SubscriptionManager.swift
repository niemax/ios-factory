import Foundation
import RevenueCat

/// The one place the app talks to RevenueCat. Owned by AppEntry as `@State` and injected with
/// `.environment()`; paid features read `isSubscribed`, never RevenueCat directly.
@MainActor
@Observable
final class SubscriptionManager {
    static let entitlementID = "__ENTITLEMENT__"

    private(set) var isSubscribed = false
    private(set) var packages: [Package] = []
    private var isConfigured = false

    // No key (e.g. a fresh clone) = subscriptions off rather than a crash.
    func configure() {
        guard !isConfigured,
              let apiKey = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String,
              !apiKey.isEmpty else { return }
        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true
        Task { await observeCustomerInfo() }
    }

    /// Call after the app's own sign-in so purchases follow the account across devices.
    func logIn(userID: String) async throws {
        guard isConfigured else { return }
        apply(try await Purchases.shared.logIn(userID).customerInfo)
    }

    func loadPackages() async throws {
        guard isConfigured else { return }
        packages = try await Purchases.shared.offerings().current?.availablePackages ?? []
    }

    /// Returns false when the user cancelled.
    func purchase(_ package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        apply(result.customerInfo)
        return !result.userCancelled
    }

    func restore() async throws {
        apply(try await Purchases.shared.restorePurchases())
    }

    private func observeCustomerInfo() async {
        for await customerInfo in Purchases.shared.customerInfoStream {
            apply(customerInfo)
        }
    }

    private func apply(_ customerInfo: CustomerInfo) {
        isSubscribed = customerInfo.entitlements[Self.entitlementID]?.isActive == true
    }
}
