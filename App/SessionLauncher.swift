import AppKit

enum SessionLauncher {
    static let url = URL(string: "claudecost://new-session")!

    private static let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")

    static func openNewSession() {
        let script = FileManager.default.temporaryDirectory.appendingPathComponent("claude-session.command")
        let folder = AppSettings.sessionFolder.replacingOccurrences(of: "'", with: "'\\''")
        let contents = """
        #!/bin/zsh -l
        cd '\(folder)' && exec claude

        """
        do {
            try contents.write(to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        } catch {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open([script], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }
}
