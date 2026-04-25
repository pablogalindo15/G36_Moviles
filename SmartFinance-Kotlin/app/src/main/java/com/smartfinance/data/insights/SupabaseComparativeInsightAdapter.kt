package com.smartfinance.data.insights

import com.smartfinance.domain.insights.ComparativeInsightVO

class SupabaseComparativeInsightAdapter(
    private val remoteDataSource: ComparativeInsightRemoteDataSource
) : ComparativeInsightRepository {

    override suspend fun fetchWeeklyComparison(): ComparativeInsightVO {
        return remoteDataSource.fetchWeeklyComparison()
    }
}
