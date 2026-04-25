package com.smartfinance.domain.insights

sealed class ComparativeInsightVO {
    data class Available(
        val myWeeklySpending: Double,
        val cohortAverageWeeklySpending: Double,
        val cohortSize: Int,
        val percentile: Double,
        val currency: String,
        val weekStart: String,
        val weekEnd: String
    ) : ComparativeInsightVO()

    data class Unavailable(
        val cohortSize: Int,
        val reason: String
    ) : ComparativeInsightVO()
}
