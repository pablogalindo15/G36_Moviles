import SwiftUI

struct SetupPlanView: View {
    let user: AuthenticatedUser
    let onSignOut: () -> Void

    @StateObject private var viewModel: SetupPlanViewModel

    init(
        user: AuthenticatedUser,
        planService: PlanApplicationService,
        onSignOut: @escaping () -> Void
    ) {
        self.user = user
        self.onSignOut = onSignOut
        _viewModel = StateObject(
            wrappedValue: SetupPlanViewModel(planService: planService, userId: user.id)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FluxoTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        formSection
                        generateButton
                        if let generatedPlan = viewModel.generatedPlan {
                            resultsSection(plan: generatedPlan)
                        }
                    }
                    .padding(20)
                }

                if viewModel.isLoading || viewModel.isLoadingInitialData {
                    LoadingOverlay(
                        title: viewModel.isLoadingInitialData
                            ? "Loading your latest plan..."
                            : "Generating your first plan..."
                    )
                }
            }
            .task {
                await viewModel.loadLatestIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign out") {
                        onSignOut()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(FluxoTheme.primary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Setup your first plan")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ProgressView(value: 1.0)
                    .tint(FluxoTheme.primary)
                Text("Last step")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(FluxoTheme.primary)
            }

            Text("Generate your first smart finance plan")
                .font(.title3.weight(.bold))
                .foregroundColor(FluxoTheme.titleText)

            Text("Answer these details once. We will calculate what is safe to spend until payday.")
                .font(.subheadline)
                .foregroundColor(FluxoTheme.secondaryText)

            Text("Signed in as \(user.email ?? "user")")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
        }
        .fluxoCardContainer()
    }

    private var formSection: some View {
        VStack(spacing: 14) {
            FluxoInputField(title: "Currency") {
                TextField("USD / COP / EUR", text: $viewModel.currency)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }

            FluxoInputField(title: "Monthly income") {
                TextField("0.00", text: $viewModel.monthlyIncome)
                    .keyboardType(.decimalPad)
            }

            FluxoInputField(title: "Fixed monthly expenses") {
                TextField("0.00", text: $viewModel.fixedMonthlyExpenses)
                    .keyboardType(.decimalPad)
            }

            FluxoInputField(title: "Monthly savings goal") {
                TextField("0.00", text: $viewModel.monthlySavingsGoal)
                    .keyboardType(.decimalPad)
            }

            FluxoInputField(title: "Next payday") {
                DatePicker(
                    "Select date",
                    selection: $viewModel.nextPayday,
                    displayedComponents: .date
                )
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var generateButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(FluxoTheme.error)
            }

            Button("Generate my first plan") {
                Task {
                    await viewModel.generateFirstPlan()
                }
            }
            .buttonStyle(FluxoPrimaryButtonStyle(isDisabled: viewModel.isLoading))
            .disabled(viewModel.isLoading)
        }
    }

    private func resultsSection(plan: GeneratedPlanDTO) -> some View {
        // Direct mapping of backend response fields to UI cards.
        VStack(alignment: .leading, spacing: 12) {
            Text("Your plan results")
                .font(.headline.weight(.bold))
                .foregroundColor(FluxoTheme.titleText)

            ResultMetricCard(
                title: "Safe to spend until next payday",
                value: "\(viewModel.currency.uppercased()) \(money(plan.safe_to_spend_until_next_payday))"
            )
            ResultMetricCard(
                title: "Recommended weekly cap",
                value: "\(viewModel.currency.uppercased()) \(money(plan.weekly_cap))"
            )
            ResultMetricCard(
                title: "Target savings",
                value: "\(viewModel.currency.uppercased()) \(money(plan.target_savings))"
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Contextual insight")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(FluxoTheme.titleText)
                Text(plan.contextual_insight_message)
                    .font(.subheadline)
                    .foregroundColor(FluxoTheme.secondaryText)
            }
            .fluxoCardContainer()
        }
    }

    private func money(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private struct ResultMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(FluxoTheme.secondaryText)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(FluxoTheme.titleText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluxoCardContainer()
    }
}
