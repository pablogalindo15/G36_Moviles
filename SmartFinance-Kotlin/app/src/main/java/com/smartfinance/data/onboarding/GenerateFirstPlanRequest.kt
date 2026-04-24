package com.smartfinance.data.onboarding

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class GenerateFirstPlanRequest(
    @SerialName("user_id") val userId: String,
    @SerialName("current_date") val currentDate: String,
    @SerialName("currency") val currency: String,
    @SerialName("monthly_income") val monthlyIncome: Double,
    @SerialName("fixed_monthly_expenses") val fixedMonthlyExpenses: Double,
    @SerialName("monthly_savings_goal") val monthlySavingsGoal: Double,
    @SerialName("next_payday") val nextPayday: String
)

@Serializable
data class GenerateFirstPlanResponse(
    val plan: com.smartfinance.core.model.GeneratedPlan
)
