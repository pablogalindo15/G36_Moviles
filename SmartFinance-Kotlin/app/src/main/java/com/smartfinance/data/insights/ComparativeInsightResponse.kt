package com.smartfinance.data.insights

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ComparativeInsightRequest(
    @SerialName("week_end") val weekEnd: String? = null
)

@Serializable
data class ComparativeInsightResponse(
    @SerialName("my_weekly_spending") val myWeeklySpending: Double? = null,
    @SerialName("cohort_avg_weekly_spending") val cohortAverageWeeklySpending: Double? = null,
    @SerialName("cohort_size") val cohortSize: Int? = null,
    @SerialName("my_percentile") val myPercentile: Double? = null,
    val currency: String? = null,
    @SerialName("week_start") val weekStart: String? = null,
    @SerialName("week_end") val weekEnd: String? = null,
    val reason: String? = null,
    val error: String? = null,
    val details: String? = null
)
