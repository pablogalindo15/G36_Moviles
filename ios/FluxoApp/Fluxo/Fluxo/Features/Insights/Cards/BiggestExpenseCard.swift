import SwiftUI

struct BiggestExpenseCard: View {
    let data: BiggestExpenseOfCycle?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biggest expense this cycle")
                .font(.headline)
                .foregroundColor(FluxoTheme.titleText)

            if let data {
                Text("\(data.cycleStart) – \(data.cycleEnd)")
                    .font(.caption)
                    .foregroundColor(FluxoTheme.secondaryText)

                if let biggest = data.biggest {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(biggest.amount, format: .currency(code: data.currency))
                            .font(.title2.bold())
                            .foregroundColor(FluxoTheme.titleText)

                        HStack(spacing: 8) {
                            Image(systemName: biggest.category.icon)
                                .foregroundColor(FluxoTheme.primary)
                            Text(biggest.category.displayName)
                                .font(.subheadline)
                                .foregroundColor(FluxoTheme.secondaryText)
                            Spacer()
                            Text(biggest.occurredAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(FluxoTheme.secondaryText)
                        }

                        if let pct = biggest.percentOfBudget {
                            Text("\(pct.formatted(.number.precision(.fractionLength(1))))% of your budget")
                                .font(.footnote)
                                .foregroundColor(pct > 50 ? FluxoTheme.error : FluxoTheme.secondaryText)
                        }
                    }
                } else {
                    placeholderText("No expenses this cycle yet.")
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
