package com.smartfinance.data.plan_insights

import android.util.Log
import com.smartfinance.data.local.LocalSavingsProjectionCache
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.domain.plan_insights.PlanSnapshotVO
import com.smartfinance.domain.plan_insights.SavingsProjectionVO
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BqRepositoryImpl @Inject constructor(
    private val remoteDataSource: PlanRemoteDataSource,
    private val memoryCache: PlanMemoryCache,
    private val localDao: SmartFinanceDao,
    private val supabaseClient: SupabaseClient
) : BqRepository {

    override suspend fun getSavingsProjection(forceRefresh: Boolean): SavingsProjectionVO {
        val userId = requireUserId()
        val cachedProjection = memoryCache.getSnapshot()?.savingsProjection

        if (!forceRefresh) {
            if (cachedProjection != null) {
                Log.d("BqRepository", "Returning savings projection from memory cache")
                return cachedProjection
            }

            val persistedProjection = localDao.getSavingsProjectionCache(userId)?.toDomain()
            if (persistedProjection != null) {
                Log.d("BqRepository", "Returning savings projection from Room cache")
                memoryCache.saveSnapshot(
                    PlanSnapshotVO(
                        savingsProjection = persistedProjection,
                        fetchedAt = System.currentTimeMillis()
                    )
                )
                return persistedProjection
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
            localDao.saveSavingsProjectionCache(freshProjection.toLocal(userId))
            Log.d("BqRepository", "Saved fresh savings projection in memory cache")

            return freshProjection
        } catch (e: Exception) {
            val persistedProjection = localDao.getSavingsProjectionCache(userId)?.toDomain()
            val fallbackProjection = cachedProjection ?: persistedProjection

            if (fallbackProjection != null) {
                Log.w("BqRepository", "Remote savings projection failed; returning cache", e)
                memoryCache.saveSnapshot(
                    PlanSnapshotVO(
                        savingsProjection = fallbackProjection,
                        fetchedAt = System.currentTimeMillis()
                    )
                )
                return fallbackProjection
            }
            throw e
        }
    }

    private fun requireUserId(): String {
        return supabaseClient.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("No authenticated user for savings projection cache")
    }

    private fun LocalSavingsProjectionCache.toDomain(): SavingsProjectionVO {
        return SavingsProjectionVO(
            isOnTrack = isOnTrack,
            projectedSavings = projectedSavings,
            savingsGoal = savingsGoal,
            message = message,
            computedAt = computedAt
        )
    }

    private fun SavingsProjectionVO.toLocal(userId: String): LocalSavingsProjectionCache {
        return LocalSavingsProjectionCache(
            userId = userId,
            isOnTrack = isOnTrack,
            projectedSavings = projectedSavings,
            savingsGoal = savingsGoal,
            message = message,
            computedAt = computedAt,
            cachedAt = System.currentTimeMillis()
        )
    }
}
