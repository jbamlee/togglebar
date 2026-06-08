import SwiftUI
import Combine
import ToggleKit

/// Option A dashboard: a resizable window (openable from Dock / Spotlight / ⌘Tab /
/// `togglebar dashboard`) that mirrors the menu bar panel but adds a live status
/// detail per toggle and a system header. Refreshes on a timer for a "stats" feel.
struct DashboardView: View {
    var onChange: () -> Void = {}

    @State private var toggles: [ToggleItem] = []
    @State private var states: [String: Bool] = [:]
    @State private var details: [String: String] = [:]
    @State private var systemStatus: String = ""

    private let ticker = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private var activeCount: Int { states.values.filter { $0 }.count }

    private struct ToggleGroup: Identifiable {
        var id: String { name }
        let name: String
        let items: [ToggleItem]
    }

    /// Toggles grouped by `group`, in first-seen order.
    private var groups: [ToggleGroup] {
        var order: [String] = []
        var buckets: [String: [ToggleItem]] = [:]
        for item in toggles {
            let key = item.group ?? "Other"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }
        return order.map { ToggleGroup(name: $0, items: buckets[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groups) { group in
                        Text(group.name.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 4)
                        ForEach(group.items) { row($0) }
                    }
                }
                .padding(.bottom, 10)
            }
            Divider()
            footer
        }
        .frame(minWidth: 360, minHeight: 420)
        .onAppear(perform: reload)
        .onReceive(ticker) { _ in reload() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ToggleBar").font(.system(size: 18, weight: .bold))
                Text(systemStatus.isEmpty ? " " : systemStatus)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Text("\(activeCount) / \(toggles.count) active")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func row(_ toggle: ToggleItem) -> some View {
        HStack(spacing: 12) {
            Text(toggle.icon ?? "•").font(.system(size: 20)).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(toggle.title).font(.system(size: 14, weight: .medium))
                if let detail = details[toggle.id], !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let subtitle = toggle.subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Toggle("", isOn: binding(for: toggle))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    private var footer: some View {
        HStack {
            Button {
                ToggleEngine.shell("open -t '\(ToggleEngine.configPath)'")
            } label: {
                Label("Edit config", systemImage: "pencil")
            }
            Spacer()
            Button(action: reload) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Optimistic switch binding: flip the UI immediately, apply off the main thread
    /// (the admin dialog can block), then reconcile with the real state.
    private func binding(for toggle: ToggleItem) -> Binding<Bool> {
        Binding(
            get: { states[toggle.id] ?? false },
            set: { newValue in
                states[toggle.id] = newValue
                onChange()
                DispatchQueue.global().async {
                    ToggleEngine.setState(toggle, on: newValue)
                    let actual = ToggleEngine.isOn(toggle)
                    let detail = ToggleEngine.detail(toggle) ?? ""
                    DispatchQueue.main.async {
                        states[toggle.id] = actual
                        details[toggle.id] = detail
                        onChange()
                    }
                }
            }
        )
    }

    private func reload() {
        let config = ToggleEngine.loadConfig()
        toggles = config.toggles
        DispatchQueue.global().async {
            var newStates: [String: Bool] = [:]
            var newDetails: [String: String] = [:]
            for item in config.toggles {
                newStates[item.id] = ToggleEngine.isOn(item)
                newDetails[item.id] = ToggleEngine.detail(item) ?? ""
            }
            let status = ToggleEngine.systemStatus()
            DispatchQueue.main.async {
                states = newStates
                details = newDetails
                systemStatus = status
            }
        }
    }
}
