package com.smartfinance.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class FinancialSetup(
    @SerialName("user_id") val userId: String,
    val currency: String,
    @SerialName("monthly_income") val monthlyIncome: Double,
    @SerialName("fixed_monthly_expenses") val fixedMonthlyExpenses: Double,
    @SerialName("monthly_savings_goal") val monthlySavingsGoal: Double,
    @SerialName("next_payday") val nextPayday: String
)

@Serializable
data class FinancialSetupResponse(
    val id: String,
    @SerialName("user_id") val userId: String
)
