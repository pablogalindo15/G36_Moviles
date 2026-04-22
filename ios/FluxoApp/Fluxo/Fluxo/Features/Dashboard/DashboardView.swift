import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(viewModel: DashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let syncText = viewModel.lastSyncText {
                            Text(syncText)
                                .font(.caption)
                                .foregroundColor(FluxoTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        planOverviewSection
                        spendingSection
                        insightsSection
                        exportSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .refreshable {
                    await viewModel.load()
                }
                .background(FluxoTheme.background.ignoresSafeArea())

                floatingAddButton
            }
            .navigationTitle("Your plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") {
                        viewModel.signOut()
                    }
                    .foregroundColor(FluxoTheme.primary)
                }
            }
            .task { await viewModel.load() }
            .sheet(isPresented: $viewModel.showLogExpense) {
                LogExpenseView(
                    currency: viewModel.currency,
                    service: viewModel.expensesService,
                    onExpenseCreated: { expense in
                        viewModel.handleExpenseCreated(expense)
                    }
                )
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder private var planOverviewSection: some View {
        if viewModel.isLoadingPlan && viewModel.plan == nil {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if let plan = viewModel.plan {
            VStack(alignment: .leading, spacing: 12) {
                Text("Plan overview")
                    .font(.headline)
                    .foregroundColor(FluxoTheme.titleText)

                planCard(
                    title: "Initial budget until next payday",
                    value: formatted(plan.safe_to_spend_until_next_payday)
                )

                if let remaining = viewModel.remainingBudget {
                    remainingCard(remaining: remaining, currency: viewModel.currency)
                }

                planCard(
                    title: "Recommended weekly cap",
                    value: formatted(plan.weekly_cap)
                )
                planCard(
                    title: "Target savings",
                    value: formatted(plan.target_savings)
                )

                if !plan.contextual_insight_message.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Contextual insight")
                            .font(.subheadline.bold())
                            .foregroundColor(FluxoTheme.titleText)
                        Text(plan.contextual_insight_message)
                            .font(.callout)
                            .foregroundColor(FluxoTheme.secondaryText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FluxoTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        } else if let err = viewModel.loadError {
            Text(err)
                .foregroundColor(FluxoTheme.error)
                .padding(.vertical, 8)
        } else {
            Text("No plan yet.")
                .foregroundColor(FluxoTheme.secondaryText)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder private var spendingSection: some View {
        if let summary = viewModel.expenseSummary {
            VStack(alignment: .leading, spacing: 12) {
                Text("Spending snapshot")
                    .font(.headline)
                    .foregroundColor(FluxoTheme.titleText)

                spendingCard(
                    title: "Spent this week",
                    amount: summary.spentThisWeek,
                    currency: summary.currency,
                    subtitle: weekRangeLabel(start: summary.weekStart)
                )

                spendingCard(
                    title: "Spent since last paycheck",
                    amount: summary.spentSinceLastPaycheck,
                    currency: summary.currency,
                    subtitle: paycheckRangeLabel(lastPaycheck: summary.lastPaycheckDate)
                )
            }
        }
    }

    @ViewBuilder private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
                .foregroundColor(FluxoTheme.titleText)

            ComparativeSpendingCard(
                result: viewModel.comparativeSpending,
                isLoading: viewModel.isLoadingComparative,
                error: viewModel.comparativeError
            )
            SavingsProjectionCard(
                result: viewModel.savingsProjection,
                isLoading: viewModel.isLoadingSavingsProjection,
                error: viewModel.savingsProjectionError
            )
            TopCategoriesCard(
                result: viewModel.topCategories,
                isLoading: viewModel.isLoadingTopCategories,
                error: viewModel.topCategoriesError
            )
        }
    }

    @ViewBuilder private var exportSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                Task { await viewModel.exportExpensesToFile() }
            }) {
                HStack(spacing: 6) {
                    if viewModel.exportInProgress {
                        ProgressView()
                    }
                    Image(systemName: "square.and.arrow.down")
                    Text("Export expenses (JSON)")
                }
                .font(.footnote)
            }
            .disabled(viewModel.exportInProgress)

            if let text = viewModel.lastExportText {
                Text("Last export: \(text)")
                    .font(.caption2)
                    .foregroundColor(FluxoTheme.secondaryText)
            }

            if let url = viewModel.exportSuccessURL {
                Text("Saved to: \(url.lastPathComponent)")
                    .font(.caption2)
                    .foregroundColor(FluxoTheme.primary)
            }

            if let err = viewModel.exportError {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(FluxoTheme.error)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Reusable components

    private func planCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(FluxoTheme.secondaryText)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(FluxoTheme.titleText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func placeholderCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(FluxoTheme.titleText)
            Text(subtitle)
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    FluxoTheme.secondaryText.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1, dash: [4])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var floatingAddButton: some View {
        Button(action: { viewModel.openLogExpense() }) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(20)
                .background(FluxoTheme.primary)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 24)
    }

    private func remainingCard(remaining: Decimal, currency: String) -> some View {
        let isOver = viewModel.isOverBudget
        let valueColor: Color = isOver ? FluxoTheme.error : FluxoTheme.titleText
        let subtitleText: String = isOver
            ? "Over budget by \(currency) \(viewModel.overBudgetAmount.formatted(.number.precision(.fractionLength(2))))"
            : "You're within budget"

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Remaining")
                    .font(.subheadline)
                    .foregroundColor(FluxoTheme.secondaryText)
                if isOver {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(FluxoTheme.error)
                        .font(.footnote)
                }
            }
            Text("\(currency) \(remaining.formatted(.number.precision(.fractionLength(2))))")
                .font(.title2.bold())
                .foregroundColor(valueColor)
            Text(subtitleText)
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func spendingCard(title: String, amount: Decimal, currency: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(FluxoTheme.secondaryText)
            Text("\(currency) \(amount.formatted(.number.precision(.fractionLength(2))))")
                .font(.title2.bold())
                .foregroundColor(FluxoTheme.titleText)
            Text(subtitle)
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func weekRangeLabel(start: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        return "Week of \(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private func paycheckRangeLabel(lastPaycheck: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let days = Calendar.current.dateComponents([.day], from: lastPaycheck, to: Date()).day ?? 0
        return "Since \(formatter.string(from: lastPaycheck)) (\(days) days)"
    }

    private func formatted(_ value: Double) -> String {
        "\(viewModel.currency) \(String(format: "%.2f", value))"
    }
}
