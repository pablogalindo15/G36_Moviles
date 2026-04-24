import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - State

    @Published private(set) var plan: GeneratedPlanDTO?
    @Published private(set) var currency: String = "USD"
    @Published private(set) var isLoadingPlan: Bool = false
    @Published private(set) var loadError: String?
    @Published private(set) var connectivityMessage: String?
    @Published private(set) var expenseSummary: ExpenseSummary?
    @Published private(set) var comparativeSpending: ComparativeSpendingResult?
    @Published private(set) var isLoadingComparative: Bool = false
    @Published private(set) var comparativeError: String?
    @Published private(set) var topCategories: TopCategoriesResult?
    @Published private(set) var isLoadingTopCategories: Bool = false
    @Published private(set) var topCategoriesError: String?
    @Published private(set) var savingsProjection: SavingsProjectionResult?
    @Published private(set) var isLoadingSavingsProjection: Bool = false
    @Published private(set) var savingsProjectionError: String?

    @Published var showLogExpense: Bool = false
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var lastExportDate: Date?
    @Published private(set) var exportInProgress: Bool = false
    @Published private(set) var exportError: String?
    @Published private(set) var exportSuccessURL: URL?

    /// Cached from the last successful load; used when refreshing the summary
    /// after a new expense is created without re-fetching the full plan.
    private var cachedNextPayday: Date?

    // MARK: - Dependencies

    private let planService: PlanApplicationService
    let expensesService: ExpensesApplicationService
    private let comparativeSpendingService: ComparativeSpendingService
    private let topCategoriesService: TopCategoriesService
    private let savingsProjectionService: SavingsProjectionService
    let preferencesAdapter: PreferencesAdapter
    private let expensesFileAdapter: ExpensesFileAdapter
    private let onSignOut: () -> Void

    // MARK: - Init

    init(
        planService: PlanApplicationService,
        expensesService: ExpensesApplicationService,
        comparativeSpendingService: ComparativeSpendingService,
        topCategoriesService: TopCategoriesService,
        savingsProjectionService: SavingsProjectionService,
        preferencesAdapter: PreferencesAdapter,
        expensesFileAdapter: ExpensesFileAdapter,
        onSignOut: @escaping () -> Void
    ) {
        self.planService = planService
        self.expensesService = expensesService
        self.comparativeSpendingService = comparativeSpendingService
        self.topCategoriesService = topCategoriesService
        self.savingsProjectionService = savingsProjectionService
        self.preferencesAdapter = preferencesAdapter
        self.expensesFileAdapter = expensesFileAdapter
        self.onSignOut = onSignOut
        self.currency = preferencesAdapter.getLastSeenCurrency() ?? "USD"
        self.lastSyncAt = preferencesAdapter.getLastSyncAt()
        self.lastExportDate = expensesFileAdapter.lastExportDate()
    }

    // MARK: - Public API

    func load(forceRefresh: Bool = false) async {
        isLoadingPlan = true
        loadError = nil
        connectivityMessage = nil
        do {
            let snapshot = try await planService.fetchLatestSnapshot(forceRefresh: forceRefresh)
            if let setup = snapshot.setup {
                currency = setup.currency
                cachedNextPayday = Self.parseSetupDate(setup.next_payday)
                preferencesAdapter.setLastSeenCurrency(setup.currency)
            }
            plan = snapshot.plan
            if snapshot.source == .localCache {
                switch snapshot.fallbackReason {
                case .connectivity:
                    connectivityMessage = ConnectivitySupport.cachedContentMessage()
                case .refreshFailed, .none:
                    connectivityMessage = ConnectivitySupport.refreshFallbackMessage()
                }
            }
            var dashboardLoadedSuccessfully = true
            if let nextPayday = cachedNextPayday {
                dashboardLoadedSuccessfully = await loadExpenseSummary(
                    nextPayday: nextPayday,
                    currency: currency
                ) && dashboardLoadedSuccessfully
            }
            dashboardLoadedSuccessfully = await loadComparativeSpending() && dashboardLoadedSuccessfully
            dashboardLoadedSuccessfully = await loadTopCategories() && dashboardLoadedSuccessfully
            dashboardLoadedSuccessfully = await loadSavingsProjection() && dashboardLoadedSuccessfully

            if snapshot.source != .localCache, dashboardLoadedSuccessfully {
                let now = Date()
                lastSyncAt = now
                preferencesAdapter.setLastSyncAt(now)
            }
        } catch {
            if ConnectivitySupport.isConnectivityIssue(error) {
                loadError = ConnectivitySupport.noSavedContentMessage(for: "plan data")
            } else {
                loadError = "Couldn't load your plan. Pull down to retry."
            }
        }
        isLoadingPlan = false
    }

    func openLogExpense() {
        showLogExpense = true
    }

    func handleExpenseCreated(_: Expense) {
        showLogExpense = false
        // Refresh spending summary, comparative insight, and top categories after a new expense.
        if let nextPayday = cachedNextPayday {
            Task {
                _ = await loadExpenseSummary(nextPayday: nextPayday, currency: currency)
                _ = await loadComparativeSpending()
                _ = await loadTopCategories()
                _ = await loadSavingsProjection()
            }
        }
    }

    func signOut() {
        onSignOut()
    }

    func exportExpensesToFile() async {
        exportError = nil
        exportSuccessURL = nil
        exportInProgress = true
        defer { exportInProgress = false }

        let expenses: [Expense]
        do {
            expenses = try await expensesService.fetchMyExpenses()
        } catch let serviceError as ExpensesServiceError {
            switch serviceError {
            case .underlying(let error) where ConnectivitySupport.isConnectivityIssue(error):
                exportError = ConnectivitySupport.noSavedContentMessage(for: "expenses")
            default:
                exportError = "Couldn't fetch expenses to export."
            }
            return
        } catch {
            exportError = "Couldn't fetch expenses to export."
            return
        }

        do {
            let url = try expensesFileAdapter.exportExpenses(
                expenses,
                userId: nil,
                currency: currency.isEmpty ? nil : currency
            )
            exportSuccessURL = url
            lastExportDate = Date()
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Derived values

    /// Remaining budget = initial safe_to_spend - amount spent since last paycheck.
    /// Computed on the client from plan + summary; the backend plan is a static snapshot
    /// and does not reflect actual expenses.
    var remainingBudget: Decimal? {
        guard let plan = plan, let summary = expenseSummary else { return nil }
        return Decimal(plan.safe_to_spend_until_next_payday) - summary.spentSinceLastPaycheck
    }

    /// Whether the user is over the initial budget.
    var isOverBudget: Bool {
        guard let remaining = remainingBudget else { return false }
        return remaining < 0
    }

    /// "Last synced X ago" label, or nil if never synced this session.
    var lastSyncText: String? {
        guard let date = lastSyncAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last synced \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    var lastExportText: String? {
        guard let date = lastExportDate else { return nil }
        return Self.exportFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static let exportFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    /// Amount over budget as positive Decimal (for display). Zero if under budget.
    var overBudgetAmount: Decimal {
        guard let remaining = remainingBudget, remaining < 0 else { return 0 }
        return -remaining
    }

    // MARK: - Private

    private func loadExpenseSummary(nextPayday: Date, currency: String) async -> Bool {
        let previousSummary = expenseSummary
        do {
            expenseSummary = try await expensesService.fetchExpenseSummary(
                nextPayday: nextPayday,
                currency: currency
            )
            return true
        } catch {
            // Don't block plan overview on a summary error.
            expenseSummary = previousSummary
            return false
        }
    }

    private func loadComparativeSpending() async -> Bool {
        isLoadingComparative = true
        let previousResult = comparativeSpending
        comparativeError = nil
        do {
            comparativeSpending = try await comparativeSpendingService.fetchComparativeSpending()
            isLoadingComparative = false
            return true
        } catch {
            comparativeSpending = previousResult
            comparativeError = previousResult == nil ? insightErrorMessage(for: error) : nil
            isLoadingComparative = false
            return false
        }
    }

    private func loadTopCategories() async -> Bool {
        isLoadingTopCategories = true
        let previousResult = topCategories
        topCategoriesError = nil
        do {
            topCategories = try await topCategoriesService.fetchTopCategories()
            isLoadingTopCategories = false
            return true
        } catch {
            topCategories = previousResult
            topCategoriesError = previousResult == nil ? insightErrorMessage(for: error) : nil
            isLoadingTopCategories = false
            return false
        }
    }

    private func loadSavingsProjection() async -> Bool {
        isLoadingSavingsProjection = true
        let previousResult = savingsProjection
        savingsProjectionError = nil
        do {
            savingsProjection = try await savingsProjectionService.fetchSavingsProjection()
            isLoadingSavingsProjection = false
            return true
        } catch {
            savingsProjection = previousResult
            savingsProjectionError = previousResult == nil ? insightErrorMessage(for: error) : nil
            isLoadingSavingsProjection = false
            return false
        }
    }

    private func insightErrorMessage(for error: Error) -> String {
        if ConnectivitySupport.isConnectivityIssue(error) {
            return ConnectivitySupport.requiresInternetMessage(for: "This insight")
        }
        return "This insight couldn't be loaded right now."
    }

    /// Parses the "yyyy-MM-dd" UTC string stored in FinancialSetupRow.next_payday.
    private static func parseSetupDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
