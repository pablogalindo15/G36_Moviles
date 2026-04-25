import SwiftUI

struct TopCategoriesCard: View {
    let result: TopCategoriesResult?
    let isLoading: Bool
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top categories")
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
            case .ready(let payload):
                readyContent(payload)
            case .insufficientData(let total):
                insufficientContent(total)
            }
        } else {
            Text("—")
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }

    private func readyContent(_ payload: TopCategoriesPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(payload.topCategories) { item in
                categoryRow(item: item)
            }

            Text("Based on \(payload.totalExpenses) expenses in the last \(payload.periodDays) days across all Fluxo users")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }

    private func insufficientContent(_ totalExpenses: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not enough data yet")
                .font(.callout.bold())
                .foregroundColor(FluxoTheme.titleText)
            Text("We need at least 20 expenses across Fluxo to show this insight. Current total: \(totalExpenses).")
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }

    private func categoryRow(item: TopCategoryItem) -> some View {
        HStack(spacing: 10) {
            Text(item.category.rawValue.capitalized)
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)
                .frame(width: 90, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(FluxoTheme.secondaryText.opacity(0.15))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(FluxoTheme.primary)
                        .frame(width: max(4, geo.size.width * CGFloat(item.percentage)), height: 10)
                }
            }
            .frame(height: 10)
            Text("\(Int((item.percentage * 100).rounded()))%")
                .font(.caption.bold())
                .foregroundColor(FluxoTheme.titleText)
                .frame(width: 40, alignment: .trailing)
        }
    }
}
