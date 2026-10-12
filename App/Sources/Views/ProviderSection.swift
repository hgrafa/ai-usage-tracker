import SwiftUI

struct ProviderSection: View {
    let provider: ProviderID
    let phase: ProviderPhase
    let hasSavedSecret: Bool
    var onSave: (String) -> Void
    var onRemove: () -> Void

    @State private var replacing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ProviderMark(provider: provider)
                    .frame(width: 14, height: 14)
                Text(provider.displayName)
                    .font(.headline)
            }
            content
            if showsSecretControls {
                secretControls
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .unconfigured:
            unconfigured
        case .loading(let stale):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Updating")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let stale {
                snapshotBody(stale)
            }
        case .loaded(let snapshot):
            snapshotBody(snapshot)
        case .failed(let message, let stale):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            if let stale {
                snapshotBody(stale)
            }
        }
    }

    @ViewBuilder
    private var unconfigured: some View {
        if provider == .codex {
            Text(CodexAppServerClient.missingCLIMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if let prompt = CredentialPrompt.prompt(for: provider) {
            CredentialEditor(prompt: prompt, onSave: onSave)
        }
    }

    @ViewBuilder
    private func snapshotBody(_ snapshot: UsageSnapshot) -> some View {
        if let note = snapshot.note, !note.isEmpty {
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(snapshot.meters) { meter in
            MeterRow(meter: meter)
        }
        if let breakdown = snapshot.breakdown {
            BreakdownChart(breakdown: breakdown)
        }
    }

    private var showsSecretControls: Bool {
        hasSavedSecret && (provider == .claude || provider == .cursor) && !isUnconfigured
    }

    private var isUnconfigured: Bool {
        if case .unconfigured = phase { return true }
        return false
    }

    private var secretControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(replacing ? "Cancel" : "Replace") {
                    replacing.toggle()
                }
                Spacer()
                Button("Remove", role: .destructive, action: onRemove)
            }
            .font(.caption)
            .buttonStyle(.borderless)
            if replacing, let prompt = CredentialPrompt.prompt(for: provider) {
                CredentialEditor(prompt: prompt) { value in
                    onSave(value)
                    replacing = false
                }
            }
        }
    }
}
