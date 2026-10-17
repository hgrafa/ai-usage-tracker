import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updater: AppUpdater
    @State private var launchAtLogin = false
    @State private var suppressLaunchChange = false
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Sections")
            Text("Drag to set the order in the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            List {
                ForEach(model.providerOrder) { provider in
                    Toggle(provider.displayName, isOn: Binding(
                        get: { model.isSectionEnabled(provider) },
                        set: { model.setSectionEnabled(provider, enabled: $0) }
                    ))
                    .toggleStyle(.checkbox)
                }
                .onMove(perform: model.moveProviders)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .environment(\.defaultMinListRowHeight, 22)
            .frame(height: CGFloat(model.providerOrder.count) * 26)
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Toggle("Show provider status", isOn: $model.showsProviderStatus)
                    .toggleStyle(.checkbox)
                Text("Flags a provider as Degraded, Disrupted, or Down when its status page reports a problem. Nothing shows while it's working normally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 20)
            }
            Divider()
            notificationControls
            Divider()
            launchAtLoginControls
            Divider()
            updateControls
            Divider()
            Link(destination: URL(string: "https://buymeacoffee.com/hgrafa")!) {
                Text("☕ Buy me a coffee")
                    .foregroundStyle(.yellow)
            }
            .font(.caption)
        }
        .font(.subheadline)
        .padding(.vertical, 12)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            model.refreshNotificationPermission()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var notificationControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Notify when a limit reaches")
            HStack(spacing: 12) {
                ForEach(AlertThresholds.presets, id: \.self) { threshold in
                    Toggle("\(threshold)%", isOn: Binding(
                        get: { model.isAlertThresholdEnabled(threshold) },
                        set: { model.setAlertThreshold(threshold, enabled: $0) }
                    ))
                    .toggleStyle(.checkbox)
                }
            }
            if model.notificationPermission == .denied && !model.alertThresholds.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications are turned off for AI Usage.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Button("Open System Settings") {
                        LimitNotifier.openSystemSettings()
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var launchAtLoginControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    guard !suppressLaunchChange else {
                        suppressLaunchChange = false
                        return
                    }
                    do {
                        try LaunchAtLogin.setEnabled(newValue)
                        launchError = nil
                        let enabled = LaunchAtLogin.isEnabled
                        if enabled != newValue {
                            suppressLaunchChange = true
                            launchAtLogin = enabled
                        }
                    } catch {
                        suppressLaunchChange = true
                        launchAtLogin = LaunchAtLogin.isEnabled
                        launchError = "Launch at login could not be changed."
                    }
                }
            if let launchError {
                Text(launchError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var updateControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Automatically check for updates", isOn: $updater.automaticallyChecks)
                .toggleStyle(.checkbox)
            HStack {
                Button("Check for Updates") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
                .controlSize(.small)
                Spacer()
                Text("Version \(AppUpdate.currentVersion())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
