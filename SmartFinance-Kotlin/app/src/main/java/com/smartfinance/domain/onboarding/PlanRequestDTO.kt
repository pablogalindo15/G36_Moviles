package com.smartfinance.domain.onboarding

import java.time.LocalDate

data class PlanRequestDTO(
    val userId: String,
    val currency: String,
    val monthlyIncome: Double,
    val fixedMonthlyExpenses: Double,
    val monthlySavingsGoal: Double,
    val nextPayday: LocalDate
)
