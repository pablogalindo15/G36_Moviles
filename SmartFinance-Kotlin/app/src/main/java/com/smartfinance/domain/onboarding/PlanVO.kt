package com.smartfinance.domain.onboarding

data class PlanVO(
    val currency: String,
    val monthlySavingsGoal: Double,
    val safeToSpendMonthly: Double,
    val proratedSafeToSpend: Double,
    val weeklyCap: Double,
    val isProrated: Boolean,
    val contextualInsightMessage: String
)
