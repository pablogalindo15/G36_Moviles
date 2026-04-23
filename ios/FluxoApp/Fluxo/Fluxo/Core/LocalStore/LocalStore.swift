import Foundation
import SwiftData

@MainActor
final class LocalStore {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() {
        do {
            container = try ModelContainer(
                for: LocalExpense.self,
                LocalPlan.self,
                LocalFinancialSetup.self
            )
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
    }

    // MARK: - Expenses

    func saveExpense(_ expense: Expense) {
        let clientUuid = expense.clientUuid
        let predicate = #Predicate<LocalExpense> { $0.clientUuid == clientUuid }
        let descriptor = FetchDescriptor<LocalExpense>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            // Upsert: update mutable fields, leave id/userId/clientUuid/createdAt unchanged
            existing.amount = expense.amount
            existing.currency = expense.currency
            existing.categoryRaw = expense.category.rawValue
            existing.note = expense.note
            existing.occurredAt = expense.occurredAt
        } else {
            context.insert(LocalExpense(from: expense))
        }

        try? context.save()
    }

    func saveExpenses(_ expenses: [Expense]) {
        for expense in expenses {
            saveExpense(expense)
        }
    }

    func fetchExpenses(userId: UUID) -> [Expense] {
        let predicate = #Predicate<LocalExpense> { $0.userId == userId }
        var descriptor = FetchDescriptor<LocalExpense>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.occurredAt, order: .reverse)]

        return ((try? context.fetch(descriptor)) ?? []).map { $0.toDTO() }
    }

    // MARK: - Plan

    func saveSetup(_ setup: FinancialSetupRow) {
        let id = setup.id
        let predicate = #Predicate<LocalFinancialSetup> { $0.id == id }
        let descriptor = FetchDescriptor<LocalFinancialSetup>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            existing.userId = setup.user_id
            existing.currency = setup.currency
            existing.monthlyIncome = Decimal(setup.monthly_income)
            existing.fixedMonthlyExpenses = Decimal(setup.fixed_monthly_expenses)
            existing.monthlySavingsGoal = Decimal(setup.monthly_savings_goal)
            existing.nextPayday = setup.next_payday
            existing.createdAt = setup.created_at
            existing.updatedAt = setup.updated_at
        } else {
            context.insert(LocalFinancialSetup(from: setup))
        }

        try? context.save()
    }

    func fetchLatestSetup(userId: String) -> FinancialSetupRow? {
        let normalized = userId.lowercased()
        let predicate = #Predicate<LocalFinancialSetup> { $0.userId == normalized }
        var descriptor = FetchDescriptor<LocalFinancialSetup>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        descriptor.fetchLimit = 1

        return (try? context.fetch(descriptor))?.first?.toDTO()
    }

    func savePlan(_ plan: GeneratedPlanDTO) {
        // Replace strategy: delete all existing plans for this user, insert the new one.
        let userId = plan.user_id.lowercased()
        let predicate = #Predicate<LocalPlan> { $0.userId == userId }
        let descriptor = FetchDescriptor<LocalPlan>(predicate: predicate)

        if let existing = try? context.fetch(descriptor) {
            for old in existing { context.delete(old) }
        }

        context.insert(LocalPlan(from: plan))
        try? context.save()
    }

    func fetchLatestPlan(userId: String) -> GeneratedPlanDTO? {
        let normalized = userId.lowercased()
        let predicate = #Predicate<LocalPlan> { $0.userId == normalized }
        var descriptor = FetchDescriptor<LocalPlan>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.generatedAt, order: .reverse)]
        descriptor.fetchLimit = 1

        return (try? context.fetch(descriptor))?.first?.toDTO()
    }

    // MARK: - Sign out cleanup

    func clearAll() {
        if let expenses = try? context.fetch(FetchDescriptor<LocalExpense>()) {
            for e in expenses { context.delete(e) }
        }
        if let plans = try? context.fetch(FetchDescriptor<LocalPlan>()) {
            for p in plans { context.delete(p) }
        }
        if let setups = try? context.fetch(FetchDescriptor<LocalFinancialSetup>()) {
            for s in setups { context.delete(s) }
        }
        try? context.save()
    }
}
