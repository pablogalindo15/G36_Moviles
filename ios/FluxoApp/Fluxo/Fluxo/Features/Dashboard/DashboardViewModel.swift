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
    let receiptService: ReceiptImageService
    let cameraFacade: CameraFacade
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
        receiptService: ReceiptImageService,
        cameraFacade: CameraFacade,
        preferencesAdapter: PreferencesAdapter,
        expensesFileAdapter: ExpensesFileAdapter,
        onSignOut: @escaping () -> Void
    ) {
        self.planService = planService
        self.expensesService = expensesService
        self.comparativeSpendingService = comparativeSpendingService
        self.topCategoriesService = topCategoriesService
        self.savingsProjectionService = savingsProjectionService
        self.receiptService = receiptService
        self.cameraFacade = cameraFacade
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
                    connectivityMessage = nil
                }
            }
            let dashboardLoadedSuccessfully = await loadDashboardContent(
                nextPayday: cachedNextPayday,
                currency: currency
            )

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

    func handleExpenseCreated(_: Expense, notice: String?) {
        showLogExpense = false
        if let notice {
            connectivityMessage = notice
        }
        // Refresh spending summary, comparative insight, and top categories after a new expense.
        if cachedNextPayday != nil {
            Task {
                _ = await loadDashboardContent(
                    nextPayday: cachedNextPayday,
                    currency: currency
                )
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
                exportInProgress = false
                return
            } catch {
                exportError = "Couldn't fetch expenses to export."
                exportInProgress = false
                return
            }

            let adapter = expensesFileAdapter
            let exportCurrency = currency.isEmpty ? nil : currency

            DispatchQueue.global(qos: .background).async {
                do {
                    let url = try adapter.exportExpenses(expenses, userId: nil, currency: exportCurrency)
                    DispatchQueue.main.async { [weak self] in
                        self?.exportSuccessURL = url
                        self?.lastExportDate = Date()
                        self?.exportInProgress = false
                    }
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.exportError = "Export failed: \(error.localizedDescription)"
                        self?.exportInProgress = false
                    }
                }
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

    private func loadDashboardContent(nextPayday: Date?, currency: String) async -> Bool {
        let previousSummary = expenseSummary
        let previousComparative = comparativeSpending
        let previousTopCategories = topCategories
        let previousSavingsProjection = savingsProjection

        comparativeError = nil
        topCategoriesError = nil
        savingsProjectionError = nil
        isLoadingComparative = true
        isLoadingTopCategories = true
        isLoadingSavingsProjection = true

        let expensesService = self.expensesService
        let comparativeService = self.comparativeSpendingService
        let topCategoriesService = self.topCategoriesService
        let savingsProjectionService = self.savingsProjectionService

        async let summaryTask: Result<ExpenseSummary, Error>? = {
            guard let nextPayday else { return nil }
            do {
                return .success(
                    try await expensesService.fetchExpenseSummary(
                        nextPayday: nextPayday,
                        currency: currency
                    )
                )
            } catch {
                return .failure(error)
            }
        }()

        async let comparativeTask: Result<ComparativeSpendingResult, Error> = {
            do {
                return .success(try await comparativeService.fetchComparativeSpending())
            } catch {
                return .failure(error)
            }
        }()

        async let topCategoriesTask: Result<TopCategoriesResult, Error> = {
            do {
                return .success(try await topCategoriesService.fetchTopCategories())
            } catch {
                return .failure(error)
            }
        }()

        async let savingsProjectionTask: Result<SavingsProjectionResult, Error> = {
            do {
                return .success(try await savingsProjectionService.fetchSavingsProjection())
            } catch {
                return .failure(error)
            }
        }()

        let summaryResult = await summaryTask
        let comparativeResult = await comparativeTask
        let topCategoriesResult = await topCategoriesTask
        let savingsProjectionResult = await savingsProjectionTask

        var loadedSuccessfully = true

        if let summaryResult {
            switch summaryResult {
            case .success(let summary):
                expenseSummary = summary
            case .failure:
                expenseSummary = previousSummary
                loadedSuccessfully = false
            }
        }

        loadedSuccessfully = applyComparativeResult(
            comparativeResult,
            previousResult: previousComparative
        ) && loadedSuccessfully
        loadedSuccessfully = applyTopCategoriesResult(
            topCategoriesResult,
            previousResult: previousTopCategories
        ) && loadedSuccessfully
        loadedSuccessfully = applySavingsProjectionResult(
            savingsProjectionResult,
            previousResult: previousSavingsProjection
        ) && loadedSuccessfully

        return loadedSuccessfully
    }

    private func applyComparativeResult(
        _ result: Result<ComparativeSpendingResult, Error>,
        previousResult: ComparativeSpendingResult?
    ) -> Bool {
        defer { isLoadingComparative = false }
        switch result {
        case .success(let comparative):
            comparativeSpending = comparative
            return true
        case .failure(let error):
            comparativeSpending = previousResult
            comparativeError = previousResult == nil ? insightErrorMessage(for: error) : nil
            return false
        }
    }

    private func applyTopCategoriesResult(
        _ result: Result<TopCategoriesResult, Error>,
        previousResult: TopCategoriesResult?
    ) -> Bool {
        defer { isLoadingTopCategories = false }
        switch result {
        case .success(let categories):
            topCategories = categories
            return true
        case .failure(let error):
            topCategories = previousResult
            topCategoriesError = previousResult == nil ? insightErrorMessage(for: error) : nil
            return false
        }
    }

    private func applySavingsProjectionResult(
        _ result: Result<SavingsProjectionResult, Error>,
        previousResult: SavingsProjectionResult?
    ) -> Bool {
        defer { isLoadingSavingsProjection = false }
        switch result {
        case .success(let projection):
            savingsProjection = projection
            return true
        case .failure(let error):
            savingsProjection = previousResult
            savingsProjectionError = previousResult == nil ? insightErrorMessage(for: error) : nil
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
