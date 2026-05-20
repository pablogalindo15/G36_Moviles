import SwiftUI

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.icon)
                .font(.title3)
                .foregroundColor(FluxoTheme.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(FluxoTheme.titleText)
                if let note = expense.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(FluxoTheme.secondaryText)
                        .lineLimit(1)
                }
                Text(expense.occurredAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(FluxoTheme.secondaryText)
            }

            Spacer()

            Text("\(expense.currency) \(expense.amount.formatted(.number.precision(.fractionLength(2))))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(FluxoTheme.titleText)
        }
        .padding(.vertical, 4)
    }
}
