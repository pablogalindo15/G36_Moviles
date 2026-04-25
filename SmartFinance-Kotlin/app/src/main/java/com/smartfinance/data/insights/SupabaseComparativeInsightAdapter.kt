package com.smartfinance.data.insights

import android.util.Log
import com.smartfinance.data.local.LocalComparativeInsightCache
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.domain.insights.ComparativeInsightVO
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth

class SupabaseComparativeInsightAdapter(
    private val remoteDataSource: ComparativeInsightRemoteDataSource,
    private val memoryCache: ComparativeInsightMemoryCache,
    private val localDao: SmartFinanceDao,
    private val supabaseClient: SupabaseClient
) : ComparativeInsightRepository {

    override suspend fun fetchWeeklyComparison(forceRefresh: Boolean): ComparativeInsightVO {
        val userId = requireUserId()
        val cachedInsight = memoryCache.getInsight()

        if (!forceRefresh && cachedInsight != null) {
            Log.d("ComparativeInsight", "Returning weekly comparison from memory cache")
            return cachedInsight
        }

        if (!forceRefresh) {
            val persistedInsight = localDao.getComparativeInsightCache(userId)?.toDomain()
            if (persistedInsight != null) {
                Log.d("ComparativeInsight", "Returning weekly comparison from Room cache")
                memoryCache.saveInsight(persistedInsight)
                return persistedInsight
            }
        }

        try {
            Log.d("ComparativeInsight", "Fetching weekly comparison from remote")
            val freshInsight = remoteDataSource.fetchWeeklyComparison()
            memoryCache.saveInsight(freshInsight)
            localDao.saveComparativeInsightCache(freshInsight.toLocal(userId))
            Log.d("ComparativeInsight", "Saved weekly comparison in memory cache")
            return freshInsight
        } catch (e: Exception) {
            val persistedInsight = localDao.getComparativeInsightCache(userId)?.toDomain()
            val fallbackInsight = cachedInsight ?: persistedInsight

            if (fallbackInsight != null) {
                Log.w("ComparativeInsight", "Remote weekly comparison failed; returning cache", e)
                memoryCache.saveInsight(fallbackInsight)
                return fallbackInsight
            }
            throw e
        }
    }

    private fun requireUserId(): String {
        return supabaseClient.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("No authenticated user for comparative insight cache")
    }

    private fun LocalComparativeInsightCache.toDomain(): ComparativeInsightVO {
        return when (type) {
            AVAILABLE_TYPE -> ComparativeInsightVO.Available(
                myWeeklySpending = myWeeklySpending
                    ?: throw IllegalStateException("Missing cached myWeeklySpending"),
                cohortAverageWeeklySpending = cohortAverageWeeklySpending
                    ?: throw IllegalStateException("Missing cached cohortAverageWeeklySpending"),
                cohortSize = cohortSize,
                percentile = percentile
                    ?: throw IllegalStateException("Missing cached percentile"),
                currency = currency
                    ?: throw IllegalStateException("Missing cached currency"),
                weekStart = weekStart
                    ?: throw IllegalStateException("Missing cached weekStart"),
                weekEnd = weekEnd
                    ?: throw IllegalStateException("Missing cached weekEnd")
            )

            UNAVAILABLE_TYPE -> ComparativeInsightVO.Unavailable(
                cohortSize = cohortSize,
                reason = reason ?: "cohort_too_small"
            )

            else -> throw IllegalStateException("Unknown cached comparative insight type: $type")
        }
    }

    private fun ComparativeInsightVO.toLocal(userId: String): LocalComparativeInsightCache {
        return when (this) {
            is ComparativeInsightVO.Available -> LocalComparativeInsightCache(
                userId = userId,
                type = AVAILABLE_TYPE,
                myWeeklySpending = myWeeklySpending,
                cohortAverageWeeklySpending = cohortAverageWeeklySpending,
                cohortSize = cohortSize,
                percentile = percentile,
                currency = currency,
                weekStart = weekStart,
                weekEnd = weekEnd,
                reason = null,
                cachedAt = System.currentTimeMillis()
            )

            is ComparativeInsightVO.Unavailable -> LocalComparativeInsightCache(
                userId = userId,
                type = UNAVAILABLE_TYPE,
                myWeeklySpending = null,
                cohortAverageWeeklySpending = null,
                cohortSize = cohortSize,
                percentile = null,
                currency = null,
                weekStart = null,
                weekEnd = null,
                reason = reason,
                cachedAt = System.currentTimeMillis()
            )
        }
    }

    private companion object {
        const val AVAILABLE_TYPE = "available"
        const val UNAVAILABLE_TYPE = "unavailable"
    }
}
