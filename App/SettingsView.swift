import ServiceManagement
import SwiftUI
import WidgetKit

struct SettingsView: View {
    @AppStorage(AppSettings.refreshKey, store: AppSettings.defaults)
    private var refreshMinutes = AppSettings.defaultRefreshMinutes
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Open at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            Picker("Widget refresh", selection: $refreshMinutes) {
                ForEach(AppSettings.refreshOptions, id: \.self) { minutes in
                    Text(minutes == 60 ? "Every hour" : "Every \(minutes) min").tag(minutes)
                }
            }
            .onChange(of: refreshMinutes) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            Text("The menu bar always updates every 15 seconds.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize()
    }
}
