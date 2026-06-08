import Foundation

/// The logic single-source. Loads the config, reads toggle state, and applies changes
/// (including privilege escalation). Every frontend goes through here — nothing else
/// touches shell commands or sudo.
public enum ToggleEngine {

    // MARK: Config location (the data single-source)

    public static let configDir = ("~/.config/togglebar" as NSString).expandingTildeInPath
    public static var configPath: String { configDir + "/toggles.json" }

    // MARK: Shell

    /// Runs a command through a login shell; returns (exit status, trimmed stdout+stderr).
    @discardableResult
    public static func shell(_ command: String) -> (status: Int32, out: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let out = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, out.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: Config

    public static func loadConfig() -> ToggleConfig {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configPath) {
            try? fileManager.createDirectory(atPath: configDir, withIntermediateDirectories: true)
            try? defaultConfigJSON.write(toFile: configPath, atomically: true, encoding: .utf8)
        }
        guard let data = fileManager.contents(atPath: configPath),
              let config = try? JSONDecoder().decode(ToggleConfig.self, from: data) else {
            return ToggleConfig(toggles: [])
        }
        return config
    }

    public static func find(_ id: String) -> ToggleItem? {
        loadConfig().toggles.first { $0.id == id }
    }

    // MARK: State

    public static func isOn(_ toggle: ToggleItem) -> Bool {
        shell(toggle.check).out == "on"
    }

    /// Live detail string for the dashboard (nil if no `detail` command or empty output).
    public static func detail(_ toggle: ToggleItem) -> String? {
        guard let command = toggle.detail, !command.isEmpty else { return nil }
        let out = shell(command).out
        return out.isEmpty ? nil : out
    }

    /// A short system status line for the dashboard header (battery + power source).
    public static func systemStatus() -> String {
        let battery = shell("/usr/bin/pmset -g batt").out
        var parts: [String] = []
        if let range = battery.range(of: #"\d+%"#, options: .regularExpression) {
            parts.append("🔋 " + String(battery[range]))
        }
        if battery.contains("AC Power") {
            parts.append("AC 전원")
        } else if battery.contains("Battery Power") {
            parts.append("배터리")
        }
        return parts.joined(separator: " · ")
    }

    /// Applies the on/off command. For root toggles: passwordless sudo first
    /// (works if the scoped sudoers rule is installed), else the native auth dialog.
    public static func setState(_ toggle: ToggleItem, on: Bool) {
        let command = on ? toggle.on : toggle.off
        guard toggle.needsRoot == true else { shell(command); return }
        if shell("sudo -n \(command)").status == 0 { return }
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        shell("osascript -e 'do shell script \"\(escaped)\" with administrator privileges'")
    }

    public static func toggle(_ toggle: ToggleItem) {
        setState(toggle, on: !isOn(toggle))
    }

    // MARK: Seed config written on first run

    public static let defaultConfigJSON = #"""
    {
      "toggles": [
        {
          "id": "stay-awake",
          "title": "Stay Awake",
          "group": "Power",
          "icon": "⚡",
          "subtitle": "lid + battery",
          "check": "/usr/bin/pmset -g | grep -qE 'SleepDisabled[[:space:]]+1' && echo on || echo off",
          "detail": "/usr/bin/pmset -g | grep -qE 'SleepDisabled[[:space:]]+1' && echo 'sleep disabled · lid+battery' || echo 'normal sleep'",
          "on": "/usr/bin/pmset -a disablesleep 1",
          "off": "/usr/bin/pmset -a disablesleep 0",
          "needsRoot": true
        },
        {
          "id": "caffeinate",
          "title": "Caffeinate",
          "group": "Power",
          "icon": "☕",
          "subtitle": "lid open",
          "check": "/usr/bin/pgrep -x caffeinate >/dev/null && echo on || echo off",
          "detail": "/usr/bin/pgrep -x caffeinate >/dev/null && echo \"holding · pid $(/usr/bin/pgrep -x caffeinate | /usr/bin/head -1)\" || true",
          "on": "/usr/bin/nohup /usr/bin/caffeinate -dimsu >/dev/null 2>&1 &",
          "off": "/usr/bin/pkill -x caffeinate"
        },
        {
          "id": "tailscale",
          "title": "Tailscale",
          "group": "Network",
          "icon": "🌐",
          "subtitle": "VPN mesh",
          "check": "tailscale status >/dev/null 2>&1 && echo on || echo off",
          "detail": "tailscale ip -4 2>/dev/null | head -1",
          "on": "tailscale up",
          "off": "tailscale down"
        }
      ]
    }
    """#
}
