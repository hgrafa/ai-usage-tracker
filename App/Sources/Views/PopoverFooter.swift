import AppKit
import SwiftUI

struct PopoverFooter: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin = false
    @State private var suppressLaunchChange = false
    @State private var launchError: String?
    @State private var settingsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                updatedLabel
                Spacer()
                Button("Refresh") {
                    model.refresh()
                }
                .controlSize(.small)
                .disabled(model.isRefreshing)
            }
            .font(.caption)
            Button {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    settingsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: settingsExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                    Text("Settings")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            if settingsExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sections")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(ProviderID.allCases) { provider in
                        Toggle(provider.displayName, isOn: Binding(
                            get: { model.isSectionEnabled(provider) },
                            set: { model.setSectionEnabled(provider, enabled: $0) }
                        ))
                        .toggleStyle(.checkbox)
                    }
                    Divider()
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
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .controlSize(.small)
                }
                .padding(.top, 4)
                .font(.subheadline)
            }
        }
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    @ViewBuilder
    private var updatedLabel: some View {
        if let date = model.latestFetchedAt {
            HStack(spacing: 4) {
                Text("Updated")
                Text(date, style: .relative)
            }
            .foregroundStyle(.secondary)
        } else {
            Text("Not updated yet")
                .foregroundStyle(.secondary)
        }
    }
}
