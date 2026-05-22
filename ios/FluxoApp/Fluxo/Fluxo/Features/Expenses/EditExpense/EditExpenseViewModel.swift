import Foundation
import Combine

@MainActor
final class EditExpenseViewModel: ObservableObject {
    @Published var draftAmount: Decimal
    @Published var draftCategory: ExpenseCategory
    @Published var draftNote: String
    @Published var draftOccurredAt: Date
    @Published var saveError: String? = nil
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var didSave: Bool = false

    private let originalExpense: Expense
    private let expensesService: ExpensesApplicationService
    private let onSaved: (Expense) -> Void

    init(
        expense: Expense,
        expensesService: ExpensesApplicationService,
        onSaved: @escaping (Expense) -> Void
    ) {
        self.originalExpense = expense
        self.expensesService = expensesService
        self.onSaved = onSaved
        self.draftAmount = expense.amount
        self.draftCategory = expense.category
        self.draftNote = expense.note ?? ""
        self.draftOccurredAt = expense.occurredAt
    }

    var currency: String { originalExpense.currency }

    var hasChanges: Bool {
        draftAmount != originalExpense.amount ||
        draftCategory != originalExpense.category ||
        draftNote != (originalExpense.note ?? "") ||
        draftOccurredAt != originalExpense.occurredAt
    }

    var canSave: Bool {
        hasChanges && !isSaving && draftAmount > 0
    }

    func save() async {
        var patch = ExpenseUpdatePatch()
        if draftAmount != originalExpense.amount         { patch.amount = draftAmount }
        if draftCategory != originalExpense.category     { patch.category = draftCategory }
        if draftNote != (originalExpense.note ?? "")     { patch.note = draftNote }
        if draftOccurredAt != originalExpense.occurredAt { patch.occurredAt = draftOccurredAt }

        isSaving = true
        saveError = nil
        do {
            let updated = try await expensesService.updateExpense(id: originalExpense.id, patch: patch)
            onSaved(updated)
            didSave = true
        } catch {
            if ConnectivitySupport.isConnectivityIssue(error) {
                saveError = ExpenseEvCMessages.updateRequiresInternet()
            } else if !error.isCancelledRequest {
                saveError = error.localizedDescription
            }
        }
        isSaving = false
    }
}
