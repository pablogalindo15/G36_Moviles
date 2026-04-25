package com.smartfinance.domain.insights

import com.smartfinance.data.insights.ComparativeInsightRepository

class ComparativeInsightApplicationService(
    private val repository: ComparativeInsightRepository
) {

    suspend fun fetchWeeklyComparison(): ComparativeInsightVO {
        return repository.fetchWeeklyComparison()
    }
}
