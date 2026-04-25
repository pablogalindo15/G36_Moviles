import Foundation

struct SetupPlanDraft: Codable {
    let currency: String
    let monthlyIncome: String
    let fixedMonthlyExpenses: String
    let monthlySavingsGoal: String
    let nextPaydayTimeInterval: TimeInterval

    var nextPayday: Date {
        Date(timeIntervalSince1970: nextPaydayTimeInterval)
    }
}

struct ExpenseDraft: Codable {
    let amountText: String
    let selectedCategoryRaw: String
    let note: String
    let occurredAtTimeInterval: TimeInterval

    var selectedCategory: ExpenseCategory {
        ExpenseCategory(rawValue: selectedCategoryRaw) ?? .other
    }

    var occurredAt: Date {
        Date(timeIntervalSince1970: occurredAtTimeInterval)
    }
}
