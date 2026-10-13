import SwiftUI

struct PopoverFooter: View {
    @ObservedObject var model: AppModel

    var body: some View {
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
