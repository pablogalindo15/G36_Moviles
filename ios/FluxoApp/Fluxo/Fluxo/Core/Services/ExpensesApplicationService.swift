import Foundation

enum ExpensesServiceError: Error, LocalizedError {
    case invalidAmount
    case invalidCurrency
    case noteTooLong
    case futureDate
    case tooOldDate
    case notAuthenticated
    case duplicateExpense
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Amount must be greater than zero and less than 10,000,000,000."
        case .invalidCurrency:
            return "Currency must be a 3-letter code (e.g. USD, COP, EUR)."
        case .noteTooLong:
            return "Note must be 120 characters or fewer."
        case .futureDate:
            return "Expense date cannot be in the future."
        case .tooOldDate:
            return "Expense date cannot be more than 7 days in the past."
        case .notAuthenticated:
            return "You must be signed in to record expenses."
        case .duplicateExpense:
            return "This expense was already recorded."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

final class ExpensesApplicationService {
    private let expensesAdapter: ExpensesAdapter
    private let authAdapter: AuthAdapter
    private let localStore: LocalStore

    init(expensesAdapter: ExpensesAdapter, authAdapter: AuthAdapter, localStore: LocalStore) {
        self.expensesAdapter = expensesAdapter
        self.authAdapter = authAdapter
        self.localStore = localStore
    }

    func createExpense(
        amount: Decimal,
        currency: String,
        category: ExpenseCategory,
        note: String?,
        occurredAt: Date
    ) async throws -> Expense {
        guard amount > 0 && amount < 10_000_000_000 else {
            throw ExpensesServiceError.invalidAmount
        }
        guard currency.count == 3 && currency.allSatisfy(\.isLetter) else {
            throw ExpensesServiceError.invalidCurrency
        }
        if let note, note.count > 120 {
            throw ExpensesServiceError.noteTooLong
        }
        guard occurredAt <= Date() else {
            throw ExpensesServiceError.futureDate
        }
        guard occurredAt >= Date().addingTimeInterval(-7 * 24 * 3600) else {
            throw ExpensesServiceError.tooOldDate
        }

        let session = try await currentSession()

        let clientUuid = UUID()
        let request = ExpenseCreateRequest(
            userId: session.userId,
            amount: amount,
            currency: currency.uppercased(),
            category: category,
            note: note,
            occurredAt: occurredAt,
            clientUuid: clientUuid
        )

        do {
            let created = try await expensesAdapter.insertExpense(request, accessToken: session.token)
            await MainActor.run { localStore.saveExpense(created) }
            return created
        } catch let error as PostgrestAdapterError {
            if case .backend(let statusCode, _) = error, statusCode == 409 {
                throw ExpensesServiceError.duplicateExpense
            }
            throw ExpensesServiceError.underlying(error)
        } catch {
            throw ExpensesServiceError.underlying(error)
        }
    }

    func fetchMyExpenses() async throws -> [Expense] {
        let session = try await currentSession()
        return try await fetchExpensesWithLocalFallback(
            userId: session.userId,
            accessToken: session.token
        )
    }

    func fetchExpenseSummary(
        nextPayday: Date,
        currency: String
    ) async throws -> ExpenseSummary {
        let session = try await currentSession()
        let allExpenses = try await fetchExpensesWithLocalFallback(
            userId: session.userId,
            accessToken: session.token
        )

        let weekStart = Self.startOfCurrentWeek()
        let lastPaycheckDate = Calendar.current.date(
            byAdding: .month, value: -1, to: nextPayday
        ) ?? nextPayday

        let periodStart = min(weekStart, lastPaycheckDate)

        let relevant = allExpenses.filter {
            $0.currency.uppercased() == currency.uppercased() &&
            $0.occurredAt >= periodStart
        }

        let spentThisWeek: Decimal = relevant
            .filter { $0.occurredAt >= weekStart }
            .reduce(0) { $0 + $1.amount }

        let spentSinceLastPaycheck: Decimal = relevant
            .filter { $0.occurredAt >= lastPaycheckDate }
            .reduce(0) { $0 + $1.amount }

        return ExpenseSummary(
            spentThisWeek: spentThisWeek,
            spentSinceLastPaycheck: spentSinceLastPaycheck,
            weekStart: weekStart,
            lastPaycheckDate: lastPaycheckDate,
            currency: currency
        )
    }

    private func currentSession() async throws -> (token: String, userId: UUID) {
        do {
            return (
                token: try await authAdapter.currentAccessToken(),
                userId: try authAdapter.currentUserId()
            )
        } catch {
            throw ExpensesServiceError.notAuthenticated
        }
    }

    private func fetchExpensesWithLocalFallback(
        userId: UUID,
        accessToken: String
    ) async throws -> [Expense] {
        do {
            let remote = try await expensesAdapter.fetchExpenses(userId: userId, accessToken: accessToken)
            await MainActor.run { localStore.saveExpenses(remote) }
            return remote
        } catch {
            let local = await MainActor.run { localStore.fetchExpenses(userId: userId) }
            if !local.isEmpty {
                return local
            }
            throw ExpensesServiceError.underlying(error)
        }
    }

    private static func startOfCurrentWeek() -> Date {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return cal.date(from: comps) ?? now
    }
}
