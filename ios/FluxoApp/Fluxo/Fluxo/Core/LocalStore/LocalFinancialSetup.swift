import Foundation
import SwiftData

@Model
final class LocalFinancialSetup {
    @Attribute(.unique) var id: String
    var userId: String
    var currency: String
    var monthlyIncome: Decimal
    var fixedMonthlyExpenses: Decimal
    var monthlySavingsGoal: Decimal
    var nextPayday: String
    var createdAt: String?
    var updatedAt: String?

    init(
        id: String,
        userId: String,
        currency: String,
        monthlyIncome: Decimal,
        fixedMonthlyExpenses: Decimal,
        monthlySavingsGoal: Decimal,
        nextPayday: String,
        createdAt: String?,
        updatedAt: String?
    ) {
        self.id = id
        self.userId = userId
        self.currency = currency
        self.monthlyIncome = monthlyIncome
        self.fixedMonthlyExpenses = fixedMonthlyExpenses
        self.monthlySavingsGoal = monthlySavingsGoal
        self.nextPayday = nextPayday
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(from row: FinancialSetupRow) {
        self.init(
            id: row.id,
            userId: row.user_id.lowercased(),
            currency: row.currency,
            monthlyIncome: Decimal(row.monthly_income),
            fixedMonthlyExpenses: Decimal(row.fixed_monthly_expenses),
            monthlySavingsGoal: Decimal(row.monthly_savings_goal),
            nextPayday: row.next_payday,
            createdAt: row.created_at,
            updatedAt: row.updated_at
        )
    }

    func toDTO() -> FinancialSetupRow {
        FinancialSetupRow(
            id: id,
            user_id: userId,
            currency: currency,
            monthly_income: (monthlyIncome as NSDecimalNumber).doubleValue,
            fixed_monthly_expenses: (fixedMonthlyExpenses as NSDecimalNumber).doubleValue,
            monthly_savings_goal: (monthlySavingsGoal as NSDecimalNumber).doubleValue,
            next_payday: nextPayday,
            created_at: createdAt,
            updated_at: updatedAt
        )
    }
}
