package com.smartfinance.data.plan_insights

import android.util.Log
import com.smartfinance.domain.plan_insights.PlanSnapshotVO
import com.smartfinance.domain.plan_insights.SavingsProjectionVO
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BqRepositoryImpl @Inject constructor(
    private val remoteDataSource: PlanRemoteDataSource,
    private val memoryCache: PlanMemoryCache
) : BqRepository {

    override suspend fun getSavingsProjection(forceRefresh: Boolean): SavingsProjectionVO {
        val cachedProjection = memoryCache.getSnapshot()?.savingsProjection

        if (!forceRefresh) {
            if (cachedProjection != null) {
                Log.d("BqRepository", "Returning savings projection from memory cache")
                return cachedProjection
            }
        }

        try {
            Log.d("BqRepository", "Fetching savings projection from remote")
            val freshProjection = remoteDataSource.getSavingsProjection()

            val newSnapshot = PlanSnapshotVO(
                savingsProjection = freshProjection,
                fetchedAt = System.currentTimeMillis()
            )

            memoryCache.saveSnapshot(newSnapshot)
            Log.d("BqRepository", "Saved fresh savings projection in memory cache")

            return freshProjection
        } catch (e: Exception) {
            if (cachedProjection != null) {
                Log.w("BqRepository", "Remote savings projection failed; returning cache", e)
                return cachedProjection
            }
            throw e
        }
    }
}
