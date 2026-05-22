import Foundation
import Combine

@MainActor
final class ExpensesListViewModel: ObservableObject {

    enum ViewState {
        case idle
        case loading
        case loaded([Expense])
        case error(String)
    }

    enum Scope {
        case currentCycle
        case all
    }

    @Published private(set) var state: ViewState = .idle
    @Published var searchText: String = ""
    @Published var selectedCategory: ExpenseCategory? = nil
    @Published var scope: Scope = .currentCycle
    @Published var deleteError: String? = nil

    private var nextPayday: Date? = nil

    let expensesService: ExpensesApplicationService
    private let planService: PlanApplicationService

    init(expensesService: ExpensesApplicationService, planService: PlanApplicationService) {
        self.expensesService = expensesService
        self.planService = planService
    }

    var isCycleAvailable: Bool { nextPayday != nil }

    var cycleStart: Date? {
        guard let next = nextPayday else { return nil }
        return Calendar.current.date(byAdding: .month, value: -1, to: next)
    }

    var filteredExpenses: [Expense] {
        guard case .loaded(let expenses) = state else { return [] }

        let scoped: [Expense]
        if scope == .currentCycle, let start = cycleStart, let end = nextPayday {
            scoped = expenses.filter { $0.occurredAt >= start && $0.occurredAt < end }
        } else {
            scoped = expenses
        }

        let byCategory: [Expense]
        if let category = selectedCategory {
            byCategory = scoped.filter { $0.category == category }
        } else {
            byCategory = scoped
        }

        guard !searchText.isEmpty else { return byCategory }
        let lower = searchText.lowercased()
        return byCategory.filter { ($0.note ?? "").lowercased().contains(lower) }
    }

    func load() async {
        state = .loading
        do {
            let expenses = try await expensesService.fetchMyExpenses()
            let snapshot = try? await planService.fetchLatestSnapshot()
            if let setup = snapshot?.setup {
                nextPayday = parseSetupDate(setup.next_payday)
            }
            if nextPayday == nil && scope == .currentCycle {
                scope = .all
            }
            state = .loaded(expenses)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func delete(expense: Expense) async {
        guard case .loaded(let list) = state else { return }
        do {
            try await expensesService.deleteExpense(id: expense.id)
            state = .loaded(list.filter { $0.id != expense.id })
        } catch {
            if ConnectivitySupport.isConnectivityIssue(error) {
                deleteError = ExpenseEvCMessages.deleteRequiresInternet(fromList: true)
            } else if !error.isCancelledRequest {
                deleteError = error.localizedDescription
            }
        }
    }

    private func parseSetupDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
