import SwiftUI

struct SavingsProjectionCard: View {
    let result: SavingsProjectionResult?
    let isLoading: Bool
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Savings projection")
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
            case .ready(let p):
                readyContent(p)
            case .insufficientData(let n):
                insufficientContent(n)
            }
        } else {
            Text("—")
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }

    private func readyContent(_ p: SavingsProjection) -> some View {
        let statusColor: Color = p.onTrack ? FluxoTheme.primary : FluxoTheme.error
        let statusText: String = p.onTrack ? "On track" : "Off track"
        let statusIcon: String = p.onTrack ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"

        let absDelta = abs(p.delta)
        let deltaText: String = p.onTrack
            ? "You'll exceed your goal by \(p.currency) \(formatted(absDelta))"
            : "You'll be short by \(p.currency) \(formatted(absDelta))"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.callout.bold())
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                labeledRow(
                    label: "Projected savings",
                    value: "\(p.currency) \(formatted(p.projectedSavings))"
                )
                labeledRow(
                    label: "Your goal",
                    value: "\(p.currency) \(formatted(p.savingsGoal))"
                )
            }

            Text(deltaText)
                .font(.footnote.bold())
                .foregroundColor(statusColor)

            Text("Based on your avg \(p.currency) \(formatted(p.weeklySpendingRate))/week over the last \(p.projectionBasisWeeks) weeks. \(p.cycleDaysRemaining) days until next payday.")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }

    private func insufficientContent(_ expensesCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not enough data yet")
                .font(.callout.bold())
                .foregroundColor(FluxoTheme.titleText)
            Text("Log at least 3 expenses in the last 2 weeks to see a projection. Current: \(expensesCount).")
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }

    private func labeledRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.footnote.bold())
                .foregroundColor(FluxoTheme.titleText)
        }
    }

    private func formatted(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }
}
