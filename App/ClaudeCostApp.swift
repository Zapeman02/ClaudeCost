import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Only on first launch, so turning it off in Settings sticks.
        if !AppSettings.defaults.bool(forKey: AppSettings.loginItemConfiguredKey) {
            try? SMAppService.mainApp.register()
            AppSettings.defaults.set(true, forKey: AppSettings.loginItemConfiguredKey)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if urls.contains(SessionLauncher.url) {
            SessionLauncher.openNewSession()
        }
    }
}

@main
struct ClaudeCostApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @StateObject private var monitor = UsageMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(summary: monitor.summary)
        } label: {
            Text(Format.dollars(monitor.summary?.month.cost ?? 0))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

struct MenuPanel: View {
    let summary: UsageSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if let summary {
                    DashboardView(summary: summary, size: .large)
                } else {
                    EmptyDashboardView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .frame(height: 300)
            HStack {
                Button("New session", systemImage: "terminal") {
                    SessionLauncher.openNewSession()
                }
                Spacer()
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 380)
        .background(Theme.surface)
    }
}
