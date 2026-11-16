import Foundation

// Stored in the App Group so the widget can read the refresh interval too.
enum AppSettings {
    static let defaults = UserDefaults(suiteName: SummaryStore.appGroup) ?? .standard

    static let refreshKey = "widgetRefreshMinutes"
    static let loginItemConfiguredKey = "loginItemConfigured"
    static let refreshOptions = [1, 5, 15, 30, 60]
    static let defaultRefreshMinutes = 5

    static let sessionFolderKey = "sessionFolder"
    static let defaultSessionFolder = NSHomeDirectory() + "/Desktop/Projects"

    static var sessionFolder: String {
        defaults.string(forKey: sessionFolderKey) ?? defaultSessionFolder
    }

    static var widgetRefreshInterval: TimeInterval {
        let minutes = defaults.integer(forKey: refreshKey)
        return Double(minutes > 0 ? minutes : defaultRefreshMinutes) * 60
    }
}
