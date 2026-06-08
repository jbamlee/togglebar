import SwiftUI
import ToggleKit

/// Option A: SwiftUI panel with real switches, grouped into sections,
/// a top summary, and a footer. Shown from the menu bar popover.
struct PanelView: View {
    var onChange: () -> Void = {}
    var onQuit: () -> Void = {}
    var onDashboard: () -> Void = {}

    @State private var toggles: [ToggleItem] = []
    @State private var states: [String: Bool] = [:]

    private var activeCount: Int { states.values.filter { $0 }.count }

    private struct PanelSection: Identifiable {
        var id: String { name }
        let name: String
        let items: [ToggleItem]
    }

    /// Toggles grouped by `group`, in first-seen order.
    private var sections: [PanelSection] {
        var order: [String] = []
        var buckets: [String: [ToggleItem]] = [:]
        for item in toggles {
            let group = item.group ?? "Other"
            if buckets[group] == nil { order.append(group) }
            buckets[group, default: []].append(item)
        }
        return order.map { PanelSection(name: $0, items: buckets[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ForEach(sections) { section in
                Text(section.name.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                ForEach(section.items) { row($0) }
            }
            Divider().padding(.top, 6)
            footer
        }
        .frame(width: 280)
        .onAppear(perform: reload)
    }

    private var header: some View {
        HStack {
            Text("ToggleBar").font(.system(size: 14, weight: .semibold))
            Spacer()
            Text("\(activeCount) / \(toggles.count) active")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func row(_ toggle: ToggleItem) -> some View {
        HStack(spacing: 10) {
            Text(toggle.icon ?? "•")
                .font(.system(size: 16))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(toggle.title).font(.system(size: 13.5))
                if let subtitle = toggle.subtitle {
                    Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Toggle("", isOn: binding(for: toggle))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(action: onDashboard) {
                Label("Dashboard", systemImage: "square.grid.2x2")
            }
            Spacer()
            Button {
                ToggleEngine.shell("open -t '\(ToggleEngine.configPath)'")
            } label: {
                Image(systemName: "pencil")
            }
            .help("Edit toggles.json")
            Button(action: onQuit) {
                Image(systemName: "power")
            }
            .help("Quit ToggleBar")
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func binding(for toggle: ToggleItem) -> Binding<Bool> {
        Binding(
            get: { states[toggle.id] ?? false },
            set: { newValue in
                states[toggle.id] = newValue
                onChange()
                DispatchQueue.global().async {
                    ToggleEngine.setState(toggle, on: newValue)
                    let actual = ToggleEngine.isOn(toggle)
                    DispatchQueue.main.async {
                        states[toggle.id] = actual
                        onChange()
                    }
                }
            }
        )
    }

    private func reload() {
        let config = ToggleEngine.loadConfig()
        toggles = config.toggles
        states = Dictionary(uniqueKeysWithValues: config.toggles.map { ($0.id, ToggleEngine.isOn($0)) })
    }
}
