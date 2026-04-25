package com.smartfinance.domain.plan_insights

import com.smartfinance.domain.insights.ComparativeInsightVO
import kotlinx.serialization.Serializable

@Serializable
data class ExportInsightsVO(
    val savingsProjection: SavingsProjectionExport? = null,
    val topCategories: TopCategoriesResultVO? = null,
    val comparativeInsight: ComparativeInsightExport? = null,
    val exportedAt: Long = System.currentTimeMillis()
)

@Serializable
data class SavingsProjectionExport(
    val isOnTrack: Boolean,
    val projectedSavings: Double,
    val savingsGoal: Double,
    val message: String
)

@Serializable
data class ComparativeInsightExport(
    val type: String,
    val myWeeklySpending: Double? = null,
    val cohortAverageWeeklySpending: Double? = null,
    val percentile: Double? = null,
    val cohortSize: Int,
    val currency: String? = null
)
