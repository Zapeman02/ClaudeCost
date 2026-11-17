import AppKit
import SwiftUI

enum Theme {
    static let surface = dynamic(light: 0xFCFCFB, dark: 0x1A1A19)
    static let textPrimary = dynamic(light: 0x0B0B0B, dark: 0xF0EFEC)
    static let textSecondary = dynamic(light: 0x52514E, dark: 0xC3C2B7)
    static let textMuted = dynamic(light: 0x898781, dark: 0x898781)
    static let gridline = dynamic(light: 0xE1E0D9, dark: 0x2C2C2A)

    static let session = dynamic(light: 0x2A78D6, dark: 0x3987E5)
    static let today = dynamic(light: 0xEB6834, dark: 0xD95926)
    static let month = dynamic(light: 0x1BAF7A, dark: 0x199E70)
    static let fiveHour = dynamic(light: 0xD6409F, dark: 0xE25CAE)
    static let week = dynamic(light: 0x7A5AF8, dark: 0x8B6CF9)

    private static func dynamic(light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum Format {
    static func dollars(_ value: Double) -> String {
        if value >= 10_000 { return String(format: "$%.1fk", value / 1000) }
        if value >= 1000 { return String(format: "$%.0f", value) }
        return String(format: "$%.2f", value)
    }

    static func reset(_ date: Date) -> String {
        "resets " + date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    static func tokens(_ value: Int) -> String {
        switch value {
        case 1_000_000_000...: return String(format: "%.1fB tokens", Double(value) / 1e9)
        case 1_000_000...: return String(format: "%.1fM tokens", Double(value) / 1e6)
        case 1000...: return String(format: "%.0fk tokens", Double(value) / 1e3)
        default: return "\(value) tokens"
        }
    }
}
