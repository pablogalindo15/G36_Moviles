import Foundation
import Combine
import CoreLocation

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
    @Published var inflationWarning: String?

    private let planService: PlanApplicationService
    private let locationService: LocationService
    private let locationAdapter: LocationAdapter
    private let authAdapter: AuthAdapter
    private let userId: String

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(
        planService: PlanApplicationService,
        locationService: LocationService,
        locationAdapter: LocationAdapter,
        authAdapter: AuthAdapter,
        userId: String
    ) {
        self.planService = planService
        self.locationService = locationService
        self.locationAdapter = locationAdapter
        self.authAdapter = authAdapter
        self.userId = userId
    }

    func loadLatestIfNeeded() async {
        guard !hasLoadedInitialData else { return }
        hasLoadedInitialData = true
        isLoadingInitialData = true
        defer { isLoadingInitialData = false }

        // Start location detection immediately in parallel with the DB call
        // so the permission dialog appears early and GPS warms up.
        let locationTask = Task { await fetchLocationContext() }

        do {
            let snapshot = try await planService.loadLatestSnapshot(userId: userId)
            if let setup = snapshot.setup {
                // User has saved data — use it, cancel location detection.
                locationTask.cancel()
                currency = setup.currency
                monthlyIncome = Self.moneyString(setup.monthly_income)
                fixedMonthlyExpenses = Self.moneyString(setup.fixed_monthly_expenses)
                monthlySavingsGoal = Self.moneyString(setup.monthly_savings_goal)
                nextPayday = dateFormatter.date(from: setup.next_payday) ?? nextPayday
            } else {
                // First time — apply location context once it arrives.
                if let context = await locationTask.value {
                    print("[LOC] Applying: currency=\(context.currency) warning=\(context.inflation_warning ?? "none")")
                    currency = context.currency
                    inflationWarning = context.inflation_warning
                }
            }
            generatedPlan = snapshot.plan
        } catch {
            locationTask.cancel()
            errorMessage = error.localizedDescription
        }
    }

    func generateFirstPlan() async {
        errorMessage = nil
        guard let input = validateInput() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            generatedPlan = try await planService.generateFirstPlan(
                userId: userId,
                setup: input
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchLocationContext() async -> LocationContextDTO? {
        guard let location = await locationService.requestLocation() else {
            print("[LOC] requestLocation returned nil")
            return nil
        }
        print("[LOC] Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        guard let token = try? await authAdapter.currentAccessToken() else {
            print("[LOC] No access token")
            return nil
        }

        let countryCode = await locationService.resolveCountryCode(for: location)
        print("[LOC] Country code: \(countryCode ?? "nil")")

        return try? await locationAdapter.detectLocationContext(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            countryCode: countryCode,
            accessToken: token
        )
    }

    private func validateInput() -> SaveFinancialSetupDTO? {
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCurrency.isEmpty else {
            errorMessage = "Please enter a currency (example: USD)."
            return nil
        }

        let maxAmount = 999_999_999.99

        guard let income = Double(monthlyIncome), income >= 0 else {
            errorMessage = "Monthly income must be a valid non-negative number."
            return nil
        }
        guard income <= maxAmount else {
            errorMessage = "Monthly income is too large."
            return nil
        }
        guard let fixed = Double(fixedMonthlyExpenses), fixed >= 0 else {
            errorMessage = "Fixed monthly expenses must be a valid non-negative number."
            return nil
        }
        guard fixed <= maxAmount else {
            errorMessage = "Fixed monthly expenses value is too large."
            return nil
        }
        guard let savings = Double(monthlySavingsGoal), savings >= 0 else {
            errorMessage = "Monthly savings goal must be a valid non-negative number."
            return nil
        }
        guard savings <= maxAmount else {
            errorMessage = "Monthly savings goal is too large."
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
