import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            LabeledContent("Version", value: AppConfig.version)
        }
        .navigationTitle("Settings")
    }
}
