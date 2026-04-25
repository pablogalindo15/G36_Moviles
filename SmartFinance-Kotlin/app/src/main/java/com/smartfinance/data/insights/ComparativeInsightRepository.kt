package com.smartfinance.data.insights

import com.smartfinance.domain.insights.ComparativeInsightVO

interface ComparativeInsightRepository {
    suspend fun fetchWeeklyComparison(): ComparativeInsightVO
}
