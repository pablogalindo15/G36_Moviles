package com.smartfinance.data.local

import com.smartfinance.core.model.ExpenseRecord
import com.smartfinance.core.model.FinancialSetup
import com.smartfinance.core.model.GeneratedPlan
import com.smartfinance.domain.expenses.ExpenseVO

fun FinancialSetup.toLocal(id: String) = LocalFinancialSetup(
    id = id,
    userId = userId,
    currency = currency,
    monthlyIncome = monthlyIncome,
    fixedMonthlyExpenses = fixedMonthlyExpenses,
    monthlySavingsGoal = monthlySavingsGoal,
    nextPayday = nextPayday
)

fun LocalFinancialSetup.toDomain() = FinancialSetup(
    userId = userId,
    currency = currency,
    monthlyIncome = monthlyIncome,
    fixedMonthlyExpenses = fixedMonthlyExpenses,
    monthlySavingsGoal = monthlySavingsGoal,
    nextPayday = nextPayday
)

fun GeneratedPlan.toLocal() = LocalPlan(
    id = java.util.UUID.randomUUID().toString(), // Or use a real ID if available from backend
    userId = userId,
    financialSetupId = financialSetupId,
    safeToSpend = safeToSpend,
    weeklyCap = weeklyCap,
    targetSavings = targetSavings,
    insightMessage = insightMessage,
    generatedAt = java.time.Instant.now().toString()
)

fun LocalPlan.toDomain() = GeneratedPlan(
    userId = userId,
    financialSetupId = financialSetupId,
    safeToSpend = safeToSpend,
    weeklyCap = weeklyCap,
    targetSavings = targetSavings,
    insightMessage = insightMessage
)

fun ExpenseRecord.toLocal() = LocalExpense(
    id = id,
    userId = userId,
    amount = amount,
    currency = currency,
    category = category,
    note = note,
    occurredAt = occurredAt,
    createdAt = createdAt,
    clientUuid = clientUuid
)

fun ExpenseRecord.toDomain() = ExpenseVO(
    id = id,
    userId = userId,
    amount = amount,
    currency = currency,
    category = category,
    note = note,
    occurredAt = occurredAt,
    createdAt = createdAt,
    clientUuid = clientUuid
)
