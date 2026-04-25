package com.smartfinance.domain.plan_insights

import kotlinx.serialization.Serializable

@Serializable
data class SavingsProjectionVO(
    val isOnTrack: Boolean,
    val projectedSavings: Double,
    val savingsGoal: Double,
    val message: String,
    val computedAt: Long
)
