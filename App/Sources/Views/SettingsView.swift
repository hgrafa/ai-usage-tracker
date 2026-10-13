import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin = false
    @State private var suppressLaunchChange = false
    @State private var launchError: String?
    @State private var checkingUpdate = false
    @State private var updateOutcome: UpdateCheckOutcome?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Sections")
            ForEach(ProviderID.allCases) { provider in
                Toggle(provider.displayName, isOn: Binding(
                    get: { model.isSectionEnabled(provider) },
                    set: { model.setSectionEnabled(provider, enabled: $0) }
                ))
                .toggleStyle(.checkbox)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(checkingUpdate ? "Checking…" : "Check for Updates") {
                    checkForUpdates()
                }
                .disabled(checkingUpdate)
                .controlSize(.small)
                Spacer()
                Text("Version \(AppUpdate.currentVersion())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            updateDetail
        }
    }

    @ViewBuilder
    private var updateDetail: some View {
        switch updateOutcome {
        case .none:
            EmptyView()
        case .upToDate:
            Text("You're on the latest version.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .available(let release):
            VStack(alignment: .leading, spacing: 4) {
                Text("Version \(release.version) is available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Download Update") {
                    NSWorkspace.shared.open(release.downloadURL)
                }
                .controlSize(.small)
            }
        case .noRelease:
            Text("No release has been published yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed:
            Text("Couldn't check for updates.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func checkForUpdates() {
        checkingUpdate = true
        Task {
            let outcome = await UpdateChecker.check(current: AppUpdate.currentVersion())
            updateOutcome = outcome
            checkingUpdate = false
        }
    }
}
