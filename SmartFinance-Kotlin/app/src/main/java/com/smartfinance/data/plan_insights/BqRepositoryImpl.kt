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
        if (!forceRefresh) {
            val cachedSnapshot = memoryCache.getSnapshot()
            val cachedProjection = cachedSnapshot?.savingsProjection

            if (cachedProjection != null) {
                Log.d("BqRepository", "Returning savings projection from memory cache")
                return cachedProjection
            }
        }

        Log.d("BqRepository", "Fetching savings projection from remote")
        val freshProjection = remoteDataSource.getSavingsProjection()

        val newSnapshot = PlanSnapshotVO(
            savingsProjection = freshProjection,
            fetchedAt = System.currentTimeMillis()
        )

        memoryCache.saveSnapshot(newSnapshot)
        Log.d("BqRepository", "Saved fresh savings projection in memory cache")

        return freshProjection
    }
}