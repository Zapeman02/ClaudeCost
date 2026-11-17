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
    @AppStorage(AppSettings.menuBarItemKey, store: AppSettings.defaults)
    private var menuBarItem = MenuBarItem.month
    @AppStorage(AppSettings.menuBarLayoutKey, store: AppSettings.defaults)
    private var menuBarLayout = MenuBarLayout.inline

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(summary: monitor.summary)
        } label: {
            let text = menuBarItem.text(for: monitor.summary)
            if let progress = menuBarItem.progress(for: monitor.summary), menuBarLayout == .stacked {
                Image(nsImage: MenuBarProgress.stackedImage(text, progress))
            } else {
                HStack(spacing: 4) {
                    Text(text)
                    if let progress = menuBarItem.progress(for: monitor.summary) {
                        Image(nsImage: MenuBarProgress.image(progress))
                    }
                }
            }
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

enum MenuBarProgress {
    // Template image, so macOS tints it to match the menu bar like the text.
    private static let barWidth: CGFloat = 32

    static func image(_ progress: Double) -> NSImage {
        template(NSSize(width: barWidth, height: 7)) { rect in
            drawBar(progress, in: rect)
        }
    }

    // Tiny title above the bar, drawn as one image since a menu bar label can't stack views.
    static func stackedImage(_ title: String, _ progress: Double) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: NSColor.black,
        ]
        let titleSize = (title as NSString).size(withAttributes: attributes)
        let barHeight: CGFloat = 4
        let size = NSSize(width: max(barWidth, ceil(titleSize.width)), height: ceil(titleSize.height) + 1 + barHeight)
        return template(size) { rect in
            (title as NSString).draw(at: NSPoint(x: (rect.width - titleSize.width) / 2, y: barHeight + 1), withAttributes: attributes)
            drawBar(progress, in: NSRect(x: (rect.width - barWidth) / 2, y: 0, width: barWidth, height: barHeight))
        }
    }

    private static func drawBar(_ progress: Double, in rect: NSRect) {
        let radius = rect.height / 2
        NSColor.black.withAlphaComponent(0.3).setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        let filled = NSRect(x: rect.minX, y: rect.minY, width: max(rect.height, rect.width * progress), height: rect.height)
        NSColor.black.setFill()
        NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
    }

    private static func template(_ size: NSSize, draw: @escaping (NSRect) -> Void) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(rect)
            return true
        }
        image.isTemplate = true
        return image
    }
}
