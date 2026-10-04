import Foundation

enum AppConfig {
    static let version = infoValue("CFBundleShortVersionString") ?? "—"
    static let posthogAPIKey = infoValue("POSTHOG_API_KEY")
    static let posthogHost = infoValue("POSTHOG_HOST") ?? "https://eu.i.posthog.com"

    static var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else { return nil }
        return value
    }
}
