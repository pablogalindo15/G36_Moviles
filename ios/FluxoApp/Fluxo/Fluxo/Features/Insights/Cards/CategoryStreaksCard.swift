import SwiftUI

struct CategoryStreaksCard: View {
    let data: CategoryStreaks?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending streaks")
                .font(.headline)
                .foregroundColor(FluxoTheme.titleText)

            if let data {
                Text("Days without spending · \(data.evaluatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(FluxoTheme.secondaryText)

                if data.streaks.isEmpty {
                    placeholderText("No streak data yet.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(data.streaks, id: \.category) { streak in
                            HStack(spacing: 10) {
                                Image(systemName: streak.category.icon)
                                    .foregroundColor(FluxoTheme.primary)
                                    .frame(width: 20)

                                Text(streak.category.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(FluxoTheme.titleText)

                                Spacer()

                                HStack(spacing: 4) {
                                    Text("\(streak.daysSinceLast) days")
                                        .font(.subheadline.bold())
                                        .foregroundColor(FluxoTheme.titleText)

                                    if streak.capped {
                                        Text("30+")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(FluxoTheme.primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                placeholderText("Not enough data yet.")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(FluxoTheme.secondaryText)
    }
}
