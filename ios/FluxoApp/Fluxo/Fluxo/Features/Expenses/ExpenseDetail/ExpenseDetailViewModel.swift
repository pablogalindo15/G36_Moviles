import Foundation
import Combine

@MainActor
final class ExpenseDetailViewModel: ObservableObject {
    @Published private(set) var currentExpense: Expense
    @Published private(set) var isDeleting: Bool = false
    @Published private(set) var didDelete: Bool = false
    @Published var deleteError: String? = nil

    let expensesService: ExpensesApplicationService

    init(expense: Expense, expensesService: ExpensesApplicationService) {
        self.currentExpense = expense
        self.expensesService = expensesService
    }

    func handleSavedFromEdit(_ updated: Expense) {
        currentExpense = updated
    }

    func delete() async {
        isDeleting = true
        deleteError = nil
        do {
            try await expensesService.deleteExpense(id: currentExpense.id)
            didDelete = true
        } catch {
            deleteError = error.localizedDescription
        }
        isDeleting = false
    }
}
