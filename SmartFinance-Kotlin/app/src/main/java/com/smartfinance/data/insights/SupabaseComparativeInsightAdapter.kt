package com.smartfinance.data.insights

import android.util.Log
import com.smartfinance.domain.insights.ComparativeInsightVO

class SupabaseComparativeInsightAdapter(
    private val remoteDataSource: ComparativeInsightRemoteDataSource,
    private val memoryCache: ComparativeInsightMemoryCache
) : ComparativeInsightRepository {

    override suspend fun fetchWeeklyComparison(forceRefresh: Boolean): ComparativeInsightVO {
        val cachedInsight = memoryCache.getInsight()

        if (!forceRefresh && cachedInsight != null) {
            Log.d("ComparativeInsight", "Returning weekly comparison from memory cache")
            return cachedInsight
        }

        try {
            Log.d("ComparativeInsight", "Fetching weekly comparison from remote")
            val freshInsight = remoteDataSource.fetchWeeklyComparison()
            memoryCache.saveInsight(freshInsight)
            Log.d("ComparativeInsight", "Saved weekly comparison in memory cache")
            return freshInsight
        } catch (e: Exception) {
            if (cachedInsight != null) {
                Log.w("ComparativeInsight", "Remote weekly comparison failed; returning cache", e)
                return cachedInsight
            }
            throw e
        }
    }
}
