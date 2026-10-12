import SwiftUI

struct CredentialEditor: View {
    let prompt: CredentialPrompt
    var onSave: (String) -> Void

    @State private var secret = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prompt.instructions)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if prompt.showsSecretField {
                SecureField(prompt.fieldLabel, text: $secret)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit(save)
                Button(prompt.actionTitle, action: save)
                    .controlSize(.small)
                    .disabled(secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        secret = ""
    }
}
