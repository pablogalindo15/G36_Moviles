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
    @Published var validationError: String? = nil

    let currency: String
    private let service: ExpensesApplicationService
    private let onExpenseCreated: (Expense) -> Void

    init(
        currency: String,
        service: ExpensesApplicationService,
        onExpenseCreated: @escaping (Expense) -> Void
    ) {
        self.currency = currency
        self.service = service
        self.onExpenseCreated = onExpenseCreated
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
        validationError = nil

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
            case .underlying(let e):   message = e.localizedDescription
            }
            submitState = .failure(message)
        } catch {
            submitState = .failure("Something went wrong. Please try again.")
        }
    }

    func reset() {
        amountText = ""
        selectedCategory = .food
        note = ""
        occurredAt = Date()
        submitState = .idle
        validationError = nil
    }
}
