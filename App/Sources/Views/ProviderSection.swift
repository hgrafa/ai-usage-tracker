import SwiftUI

struct ProviderSection: View {
    let provider: ProviderID
    let phase: ProviderPhase
    var health: ServiceHealth?
    let hasSavedSecret: Bool
    var onSave: (String) -> Void
    var onRemove: () -> Void

    @State private var replacing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ProviderMark(provider: provider)
                    .frame(width: 16, height: 16)
                Text(provider.displayName)
                    .font(.headline)
                Spacer(minLength: 8)
                if let health, health.level.reportsTrouble {
                    StatusLamp(health: health)
                }
            }
            content
            if showsSecretControls {
                secretControls
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .geometryGroup()
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
        if let extras = snapshot.extras {
            ClaudeExtrasSection(extras: extras)
        }
        if let source = snapshot.source {
            Text(source)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(0.6)
        }
    }

    private var showsSecretControls: Bool {
        hasSavedSecret && CredentialPrompt.prompt(for: provider)?.showsSecretField == true && !isUnconfigured
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

private struct StatusLamp: View {
    var health: ServiceHealth
    @State private var bright = true

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .opacity(opacity)
            Text(health.level.word)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .help(health.detail)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(health.level.word). \(health.detail)")
        .onAppear(perform: startPulse)
        .onChange(of: health.level) { _, _ in
            startPulse()
        }
    }

    private var pulses: Bool { health.level != .unknown }

    private var opacity: Double {
        guard pulses else { return 0.4 }
        return bright ? 1 : floor
    }

    private var floor: Double {
        health.level == .operational ? 0.45 : 0.2
    }

    private var color: Color {
        switch health.level {
        case .operational: Color(red: 0.36, green: 0.80, blue: 0.48)
        case .degraded: .yellow
        case .partial: .orange
        case .major: .red
        case .unknown: Color(white: 0.55)
        }
    }

    private func startPulse() {
        guard pulses else {
            bright = true
            return
        }
        bright = true
        let duration = health.level == .operational ? 1.6 : 0.8
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            bright = false
        }
    }
}

private struct ClaudeExtrasSection: View {
    var extras: ClaudeAccountExtras

    private var settingsURL: URL { URL(string: "https://claude.ai/new#settings/usage")! }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if extras.showsCreditSection {
                if extras.spentMinor > 0, let fraction = extras.extraFraction {
                    ZStack(alignment: .topTrailing) {
                        MeterRow(meter: Meter(
                            id: "extra-usage",
                            title: "Extra usage",
                            fraction: fraction,
                            caption: extraCaption
                        ))
                        manageLink
                    }
                } else {
                    HStack {
                        Text("Extra usage")
                            .font(.subheadline)
                        Spacer()
                        manageLink
                    }
                    if extras.spentMinor > 0 {
                        Text(extras.extraCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if extras.freeCreditsMinor > 0 {
                    Text("\(extras.money(extras.freeCreditsMinor)) free credits left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .opacity(0.85)
                }
            }
            if let line = extras.limitResetCaption ?? extras.reassurance {
                Text(line)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .opacity(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var extraCaption: String {
        if let reset = extras.extraResetCaption {
            return "\(extras.extraCaption) · \(reset)"
        }
        return extras.extraCaption
    }

    private var manageLink: some View {
        Link("Manage", destination: settingsURL)
            .font(.caption.weight(.semibold))
    }
}
