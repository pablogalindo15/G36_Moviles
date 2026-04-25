import SwiftUI

struct ComparativeSpendingCard: View {
    let result: ComparativeSpendingResult?
    let isLoading: Bool
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How you compare")
                .font(.subheadline.bold())
                .foregroundColor(FluxoTheme.titleText)

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if let error = error {
            Text(error)
                .font(.footnote)
                .foregroundColor(FluxoTheme.error)
        } else if isLoading && result == nil {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 60)
        } else if let result = result {
            switch result {
            case .ready(let data):
                readyContent(data)
            case .cohortTooSmall(let size):
                tooSmallContent(size)
            }
        } else {
            Text("—")
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }

    private func readyContent(_ data: ComparativeSpending) -> some View {
        let pct = Int((data.myPercentile * 100).rounded())
        let topOrBottomText: String = pct >= 50
            ? "You're in the top \(100 - pct)% of spenders"
            : "You spend less than \(100 - pct)% of users"

        return VStack(alignment: .leading, spacing: 12) {
            Text(topOrBottomText)
                .font(.callout)
                .foregroundColor(FluxoTheme.titleText)

            VStack(alignment: .leading, spacing: 8) {
                barRow(
                    label: "You",
                    amount: data.myWeeklySpending,
                    currency: data.currency,
                    fraction: fractionFor(
                        value: data.myWeeklySpending,
                        max: Swift.max(data.myWeeklySpending, data.cohortAvgWeeklySpending)
                    ),
                    color: FluxoTheme.primary
                )
                barRow(
                    label: "Cohort avg",
                    amount: data.cohortAvgWeeklySpending,
                    currency: data.currency,
                    fraction: fractionFor(
                        value: data.cohortAvgWeeklySpending,
                        max: Swift.max(data.myWeeklySpending, data.cohortAvgWeeklySpending)
                    ),
                    color: FluxoTheme.secondaryText.opacity(0.6)
                )
            }

            Text("Based on \(data.cohortSize) users with similar income in \(data.currency)")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }

    private func tooSmallContent(_ size: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not enough data yet")
                .font(.callout.bold())
                .foregroundColor(FluxoTheme.titleText)
            Text("We need at least 5 users with similar income in your currency to show this insight. Current cohort: \(size).")
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }

    private func barRow(
        label: String,
        amount: Decimal,
        currency: String,
        fraction: Double,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(FluxoTheme.secondaryText.opacity(0.15))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(fraction)), height: 10)
                }
            }
            .frame(height: 10)
            Text("\(currency) \(amount.formatted(.number.precision(.fractionLength(0))))")
                .font(.caption.bold())
                .foregroundColor(FluxoTheme.titleText)
                .frame(width: 80, alignment: .trailing)
        }
    }

    private func fractionFor(value: Decimal, max: Decimal) -> Double {
        guard max > 0 else { return 0 }
        let ratio = (value as NSDecimalNumber).doubleValue / (max as NSDecimalNumber).doubleValue
        return min(1.0, Swift.max(0.0, ratio))
    }
}
