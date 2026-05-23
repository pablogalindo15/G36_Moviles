import SwiftUI

struct CategoryCycleComparisonCard: View {
    let data: CategoryCycleComparison?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by category")
                .font(.headline)
                .foregroundColor(FluxoTheme.titleText)

            if let data {
                Text("\(data.cycleStart) – \(data.cycleEnd)")
                    .font(.caption)
                    .foregroundColor(FluxoTheme.secondaryText)

                let top = Array(data.categories.prefix(4))
                if top.isEmpty {
                    placeholderText("No expenses this cycle yet.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(top, id: \.category) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.category.icon)
                                    .foregroundColor(FluxoTheme.primary)
                                    .frame(width: 20)

                                Text(item.category.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(FluxoTheme.titleText)

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(item.currentAmount, format: .currency(code: data.currency))
                                        .font(.subheadline.bold())
                                        .foregroundColor(FluxoTheme.titleText)

                                    deltaLabel(item.deltaPercent)
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

    @ViewBuilder
    private func deltaLabel(_ deltaPercent: Double?) -> some View {
        if let pct = deltaPercent {
            let isUp = pct >= 0
            HStack(spacing: 2) {
                Image(systemName: isUp ? "arrow.up" : "arrow.down")
                Text("\(abs(pct).formatted(.number.precision(.fractionLength(1))))%")
            }
            .font(.caption.bold())
            .foregroundColor(isUp ? FluxoTheme.error : Color.green)
        } else {
            Text("—")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(FluxoTheme.secondaryText)
    }
}
