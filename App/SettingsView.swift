import ServiceManagement
import SwiftUI
import WidgetKit

struct SettingsView: View {
    @AppStorage(AppSettings.refreshKey, store: AppSettings.defaults)
    private var refreshMinutes = AppSettings.defaultRefreshMinutes
    @AppStorage(AppSettings.sessionFolderKey, store: AppSettings.defaults)
    private var sessionFolder = AppSettings.defaultSessionFolder
    @AppStorage(AppSettings.menuBarItemKey, store: AppSettings.defaults)
    private var menuBarItem = MenuBarItem.month
    @AppStorage(AppSettings.menuBarLayoutKey, store: AppSettings.defaults)
    private var menuBarLayout = MenuBarLayout.inline
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Open at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            Picker("Menu bar shows", selection: $menuBarItem) {
                ForEach(MenuBarItem.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            Picker("Limit layout", selection: $menuBarLayout) {
                ForEach(MenuBarLayout.allCases, id: \.self) { layout in
                    Text(layout.title).tag(layout)
                }
            }
            .pickerStyle(.segmented)
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
            LabeledContent("New session folder") {
                Button((sessionFolder as NSString).abbreviatingWithTildeInPath, action: chooseSessionFolder)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize()
    }

    private func chooseSessionFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: sessionFolder)
        if panel.runModal() == .OK, let url = panel.url {
            sessionFolder = url.path
        }
    }
}
