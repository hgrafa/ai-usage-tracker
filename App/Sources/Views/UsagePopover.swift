import SwiftUI

struct UsagePopover: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AI Usage")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 4)
            ForEach(Array(ProviderID.allCases.enumerated()), id: \.element) { index, provider in
                if index > 0 {
                    Divider()
                }
                ProviderSection(
                    provider: provider,
                    phase: model.phases[provider] ?? .unconfigured,
                    hasSavedSecret: model.savedSecretProviders.contains(provider),
                    onSave: { model.saveSecret(for: provider, value: $0) },
                    onRemove: { model.removeSecret(for: provider) }
                )
            }
            Divider()
                .padding(.bottom, 8)
            PopoverFooter(model: model)
        }
        .padding(Theme.padding)
        .frame(width: Theme.popoverWidth, alignment: .leading)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .onAppear {
            model.refreshIfStale()
        }
    }
}
