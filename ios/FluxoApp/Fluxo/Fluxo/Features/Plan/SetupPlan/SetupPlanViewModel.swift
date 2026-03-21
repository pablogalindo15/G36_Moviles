import Foundation
import Combine

@MainActor
final class SetupPlanViewModel: ObservableObject {
    @Published var currency = "USD"
    @Published var monthlyIncome = ""
    @Published var fixedMonthlyExpenses = ""
    @Published var monthlySavingsGoal = ""
    @Published var nextPayday = Date()

    @Published var generatedPlan: GeneratedPlanDTO?
    @Published var isLoading = false
    @Published var isLoadingInitialData = false
    @Published var errorMessage: String?
    @Published var hasLoadedInitialData = false

    private let planService: PlanApplicationService
    private let userId: String

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(planService: PlanApplicationService, userId: String) {
        self.planService = planService
        self.userId = userId
    }

    func loadLatestIfNeeded() async {
        guard !hasLoadedInitialData else { return }
        hasLoadedInitialData = true
        isLoadingInitialData = true
        defer { isLoadingInitialData = false }

        do {
            // Load latest setup + latest generated plan for this signed-in user.
            let snapshot = try await planService.loadLatestSnapshot(userId: userId)
            if let setup = snapshot.setup {
                currency = setup.currency
                monthlyIncome = Self.moneyString(setup.monthly_income)
                fixedMonthlyExpenses = Self.moneyString(setup.fixed_monthly_expenses)
                monthlySavingsGoal = Self.moneyString(setup.monthly_savings_goal)
                nextPayday = dateFormatter.date(from: setup.next_payday) ?? nextPayday
            }
            generatedPlan = snapshot.plan
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateFirstPlan() async {
        errorMessage = nil
        guard let input = validateInput() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Calls Supabase Edge Function `generate-first-plan`.
            generatedPlan = try await planService.generateFirstPlan(
                userId: userId,
                setup: input
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateInput() -> SaveFinancialSetupDTO? {
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCurrency.isEmpty else {
            errorMessage = "Please enter a currency (example: USD)."
            return nil
        }

        guard let income = Double(monthlyIncome), income >= 0 else {
            errorMessage = "Monthly income must be a valid non-negative number."
            return nil
        }
        guard let fixed = Double(fixedMonthlyExpenses), fixed >= 0 else {
            errorMessage = "Fixed monthly expenses must be a valid non-negative number."
            return nil
        }
        guard let savings = Double(monthlySavingsGoal), savings >= 0 else {
            errorMessage = "Monthly savings goal must be a valid non-negative number."
            return nil
        }

        return SaveFinancialSetupDTO(
            currency: trimmedCurrency.uppercased(),
            monthly_income: income,
            fixed_monthly_expenses: fixed,
            monthly_savings_goal: savings,
            next_payday: dateFormatter.string(from: nextPayday)
        )
    }

    private static func moneyString(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
