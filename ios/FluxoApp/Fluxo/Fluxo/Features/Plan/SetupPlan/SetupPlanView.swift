import SwiftUI

struct SetupPlanView: View {
    let user: AuthenticatedUser
    let onSignOut: () -> Void

    @StateObject private var viewModel: SetupPlanViewModel

    init(
        user: AuthenticatedUser,
        planService: PlanApplicationService,
        locationService: LocationService,
        locationAdapter: LocationAdapter,
        authAdapter: AuthAdapter,
        onPlanGenerated: @escaping () -> Void,
        onSignOut: @escaping () -> Void
    ) {
        self.user = user
        self.onSignOut = onSignOut
        _viewModel = StateObject(
            wrappedValue: SetupPlanViewModel(
                planService: planService,
                locationService: locationService,
                locationAdapter: locationAdapter,
                authAdapter: authAdapter,
                userId: user.id,
                onPlanGenerated: onPlanGenerated
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FluxoTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        if let warning = viewModel.inflationWarning {
                            inflationWarningCard(message: warning)
                        }
                        formSection
                        generateButton
                    }
                    .padding(20)
                }

                if viewModel.isLoading || viewModel.isLoadingInitialData {
                    LoadingOverlay(
                        title: viewModel.isLoadingInitialData
                            ? "Fetching your currency..."
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

    private func inflationWarningCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Currency Alert")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(FluxoTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluxoCardContainer()
    }

    private var formSection: some View {
        VStack(spacing: 14) {
            FluxoInputField(title: "Currency") {
                TextField("USD / COP / EUR", text: $viewModel.currency)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.currency) { _, new in
                        if new.count > 3 {
                            viewModel.currency = String(new.prefix(3))
                        }
                    }
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
                    in: Date()...,
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
}
