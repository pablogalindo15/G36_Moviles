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

    @Published var isLoading = false
    @Published var isLoadingInitialData = false
    @Published var errorMessage: String?
    @Published var hasLoadedInitialData = false
    @Published var inflationWarning: String?
    @Published var contextMessage: String?

    private let planService: PlanApplicationService
    private let locationService: LocationService
    private let locationAdapter: LocationAdapter
    private let authAdapter: AuthAdapter
    private let preferencesAdapter: PreferencesAdapter
    private let userId: String
    private let onPlanGenerated: () -> Void
    private var restoredDraft = false

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
        preferencesAdapter: PreferencesAdapter,
        userId: String,
        onPlanGenerated: @escaping () -> Void
    ) {
        self.planService = planService
        self.locationService = locationService
        self.locationAdapter = locationAdapter
        self.authAdapter = authAdapter
        self.preferencesAdapter = preferencesAdapter
        self.userId = userId
        self.onPlanGenerated = onPlanGenerated
    }

    func loadLatestIfNeeded() async {
        guard !hasLoadedInitialData else { return }
        hasLoadedInitialData = true
        restoreDraftIfNeeded()
        if let pendingNotice = preferencesAdapter.consumePendingUserNotice() {
            appendContextMessage(pendingNotice)
        }
        isLoadingInitialData = true
        defer { isLoadingInitialData = false }

        let locationTask = Task { await fetchLocationContext() }

        do {
            let snapshot = try await planService.loadLatestSnapshot(userId: userId)
            if let setup = snapshot.setup {
                locationTask.cancel()
                currency = setup.currency
                preferencesAdapter.setLastSeenCurrency(setup.currency)
                preferencesAdapter.clearSetupPlanDraft()
                onPlanGenerated()
            } else if snapshot.plan != nil {
                locationTask.cancel()
                preferencesAdapter.clearSetupPlanDraft()
                onPlanGenerated()
            } else {
                if let context = await locationTask.value {
                    if !restoredDraft {
                        currency = context.currency
                    }
                    inflationWarning = context.inflation_warning
                } else if !restoredDraft {
                    contextMessage = "We couldn't detect your local context right now. You can continue by entering your currency manually."
                }
            }
        } catch {
            locationTask.cancel()
            if ConnectivitySupport.isConnectivityIssue(error) {
                if restoredDraft {
                    contextMessage = "You're offline. Keep editing your saved setup draft and generate the plan when connection is back."
                } else {
                    contextMessage = "You're offline. You can still fill the form and enter your currency manually. We'll keep your draft on this device."
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func generateFirstPlan() async {
        errorMessage = nil
        guard let input = validateInput() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await planService.generateFirstPlan(userId: userId, setup: input)
            preferencesAdapter.setLastSeenCurrency(input.currency)
            preferencesAdapter.clearSetupPlanDraft()
            onPlanGenerated()
        } catch {
            persistDraft()
            if ConnectivitySupport.isConnectivityIssue(error) {
                errorMessage = ConnectivitySupport.draftPreservedMessage(for: "generate your plan")
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func persistDraft() {
        let draft = SetupPlanDraft(
            currency: currency,
            monthlyIncome: monthlyIncome,
            fixedMonthlyExpenses: fixedMonthlyExpenses,
            monthlySavingsGoal: monthlySavingsGoal,
            nextPaydayTimeInterval: nextPayday.timeIntervalSince1970
        )
        preferencesAdapter.setSetupPlanDraft(draft)
    }

    private func restoreDraftIfNeeded() {
        guard let draft = preferencesAdapter.getSetupPlanDraft() else { return }
        restoredDraft = true
        currency = draft.currency
        monthlyIncome = draft.monthlyIncome
        fixedMonthlyExpenses = draft.fixedMonthlyExpenses
        monthlySavingsGoal = draft.monthlySavingsGoal
        nextPayday = draft.nextPayday
        appendContextMessage("Recovered your saved setup draft from this device.")
    }

    private func appendContextMessage(_ message: String) {
        guard !message.isEmpty else { return }
        if let current = contextMessage, !current.isEmpty {
            contextMessage = "\(current)\n\n\(message)"
        } else {
            contextMessage = message
        }
    }

    private func fetchLocationContext() async -> LocationContextDTO? {
        guard let location = await locationService.requestLocation() else { return nil }
        guard let token = try? await authAdapter.currentAccessToken() else { return nil }

        let countryCode = await locationService.resolveCountryCode(for: location)

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
}
