import Foundation
import PostHog

@MainActor
enum Analytics {
    private static var isEnabled = false

    // Off in Debug and without a key, so local runs never pollute production data.
    static func start() {
        guard !AppConfig.isDebug, let key = AppConfig.posthogAPIKey else { return }
        let config = PostHogConfig(projectToken: key, host: AppConfig.posthogHost)
        config.captureScreenViews = false
        config.errorTrackingConfig.autoCapture = true
        PostHogSDK.shared.setup(config)
        isEnabled = true
    }

    static func capture(_ event: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event, properties: properties)
    }
}
