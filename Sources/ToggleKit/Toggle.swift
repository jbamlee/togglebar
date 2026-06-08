import Foundation

/// A single registerable toggle, declared in `toggles.json`.
///
/// `check` is a shell command that prints `on` when the toggle is active;
/// `on` / `off` are the shell commands that change the state.
public struct ToggleItem: Codable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let check: String
    public let on: String
    public let off: String
    /// Run `on`/`off` with root. Tries passwordless sudo, then the macOS auth dialog.
    public var needsRoot: Bool?
    /// Section header in the menu bar panel (e.g. "Power", "Network").
    public var group: String?
    /// Emoji or text shown as the row icon.
    public var icon: String?
    /// Small grey line under the title.
    public var subtitle: String?
    /// Optional shell command whose output is shown live in the dashboard
    /// (e.g. an IP, a PID, a status string). Empty output → nothing shown.
    public var detail: String?
}

public struct ToggleConfig: Codable {
    public let toggles: [ToggleItem]
}
