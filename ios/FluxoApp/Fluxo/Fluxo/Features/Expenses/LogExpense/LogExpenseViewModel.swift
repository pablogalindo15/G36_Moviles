import Foundation
import Combine

enum LogExpenseSubmitState: Equatable {
    case idle
    case submitting
    case success(Expense)
    case failure(String)
}

@MainActor
final class LogExpenseViewModel: ObservableObject {
    @Published var amountText: String = ""
    @Published var selectedCategory: ExpenseCategory = .food
    @Published var note: String = ""
    @Published var occurredAt: Date = Date()
    @Published var submitState: LogExpenseSubmitState = .idle
    @Published var infoMessage: String? = nil

    let currency: String
    private let service: ExpensesApplicationService
    private let preferencesAdapter: PreferencesAdapter
    private let onExpenseCreated: (Expense) -> Void

    init(
        currency: String,
        service: ExpensesApplicationService,
        preferencesAdapter: PreferencesAdapter,
        onExpenseCreated: @escaping (Expense) -> Void
    ) {
        self.currency = currency
        self.service = service
        self.preferencesAdapter = preferencesAdapter
        self.onExpenseCreated = onExpenseCreated
        restoreDraftIfNeeded()
    }

    var isSubmitEnabled: Bool {
        guard !amountText.isEmpty,
              let value = Decimal(string: amountText, locale: .current),
              value > 0
        else { return false }
        return submitState != .submitting
    }

    func submit() async {
        submitState = .submitting
        infoMessage = nil

        guard let amount = Decimal(string: amountText, locale: .current) else {
            submitState = .failure("Invalid amount")
            return
        }

        do {
            let expense = try await service.createExpense(
                amount: amount,
                currency: currency,
                category: selectedCategory,
                note: note.isEmpty ? nil : note,
                occurredAt: occurredAt
            )
            preferencesAdapter.setLastSeenCurrency(currency)
            preferencesAdapter.clearExpenseDraft()
            submitState = .success(expense)
            onExpenseCreated(expense)
        } catch let svcErr as ExpensesServiceError {
            let message: String
            switch svcErr {
            case .invalidAmount:       message = "Amount must be greater than zero"
            case .invalidCurrency:     message = "Invalid currency"
            case .noteTooLong:         message = "Note is too long (max 120 characters)"
            case .futureDate:          message = "Date cannot be in the future"
            case .tooOldDate:          message = "Date too old (max 7 days ago)"
            case .notAuthenticated:    message = "Your session expired, please sign in again"
            case .duplicateExpense:    message = "This expense was already registered"
            case .underlying(let e):
                if ConnectivitySupport.isConnectivityIssue(e) {
                    persistDraft()
                    message = ConnectivitySupport.draftPreservedMessage(for: "save this expense")
                } else {
                    message = e.localizedDescription
                }
            }
            submitState = .failure(message)
        } catch {
            if ConnectivitySupport.isConnectivityIssue(error) {
                persistDraft()
                submitState = .failure(ConnectivitySupport.draftPreservedMessage(for: "save this expense"))
            } else {
                submitState = .failure("Something went wrong. Please try again.")
            }
        }
    }

    func persistDraft() {
        let draft = ExpenseDraft(
            amountText: amountText,
            selectedCategoryRaw: selectedCategory.rawValue,
            note: note,
            occurredAtTimeInterval: occurredAt.timeIntervalSince1970
        )
        preferencesAdapter.setExpenseDraft(draft)
    }

    func reset() {
        amountText = ""
        selectedCategory = .food
        note = ""
        occurredAt = Date()
        submitState = .idle
        infoMessage = nil
        preferencesAdapter.clearExpenseDraft()
    }

    private func restoreDraftIfNeeded() {
        guard let draft = preferencesAdapter.getExpenseDraft() else { return }
        amountText = draft.amountText
        selectedCategory = draft.selectedCategory
        note = draft.note
        occurredAt = draft.occurredAt
        infoMessage = "Recovered your saved expense draft. Review it and try again."
    }
}
