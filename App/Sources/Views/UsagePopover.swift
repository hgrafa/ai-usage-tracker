import SwiftUI

/// Owned by the status bar controller so closing the popover can send it back to the usage view.
@MainActor
final class PopoverRoute: ObservableObject {
    @Published var showingSettings = false
}

struct UsagePopover: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updater: AppUpdater
    @ObservedObject var route: PopoverRoute

    private var showingSettings: Bool { route.showingSettings }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(showingSettings ? "Settings" : "AI Usage")
                    .font(.title3.weight(.semibold))
                Spacer()
                SettingsGearButton(isActive: showingSettings) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        route.showingSettings.toggle()
                    }
                }
            }
            .padding(.bottom, 4)
            if let version = updater.availableVersion {
                UpdateBanner(version: version) {
                    updater.checkForUpdates()
                }
            }
            if showingSettings {
                SettingsView(model: model, updater: updater)
            } else {
                usage
            }
        }
        .padding(Theme.padding)
        .frame(width: Theme.popoverWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            model.refreshIfStale()
        }
    }

    @ViewBuilder
    private var usage: some View {
        if model.visibleProviders.isEmpty {
            Text("No sections. Turn one on in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
        } else {
            ForEach(Array(model.visibleProviders.enumerated()), id: \.element) { index, provider in
                if index > 0 {
                    Divider()
                }
                ProviderSection(
                    provider: provider,
                    phase: model.phases[provider] ?? .unconfigured,
                    health: model.showsProviderStatus ? model.serviceHealth[provider] : nil,
                    hasSavedSecret: model.savedSecretProviders.contains(provider),
                    onSave: { model.saveSecret(for: provider, value: $0) },
                    onRemove: { model.removeSecret(for: provider) }
                )
            }
        }
        Divider()
            .padding(.bottom, 8)
        PopoverFooter(model: model)
    }
}

private struct UpdateBanner: View {
    var version: String
    var onUpdate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.green)
            Text("Version \(version) is available")
                .font(.caption)
            Spacer(minLength: 8)
            Button("Update", action: onUpdate)
                .controlSize(.small)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
        .padding(.vertical, 6)
    }
}

private struct SettingsGearButton: View {
    var isActive: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "gearshape.fill" : "gearshape")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .opacity(isActive || hovering ? 0.9 : 0.5)
        .onHover { hovering = $0 }
        .help(isActive ? "Close Settings" : "Settings")
        .accessibilityLabel(isActive ? "Close Settings" : "Settings")
    }
}
