package com.smartfinance.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class GeneratedPlan(
    @SerialName("user_id") val userId: String,
    @SerialName("financial_setup_id") val financialSetupId: String,
    @SerialName("safe_to_spend_until_next_payday") val safeToSpendUntilNextPayday: Double,
    @SerialName("weekly_cap") val weeklyCap: Double,
    @SerialName("target_savings") val targetSavings: Double,
    @SerialName("contextual_insight_message") val contextualInsightMessage: String
)
