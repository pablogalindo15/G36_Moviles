package com.smartfinance.data.plan_insights

import android.util.Log
import com.smartfinance.data.local.LocalSavingsProjectionCache
import com.smartfinance.data.local.LocalTopCategoriesCache
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.domain.plan_insights.PlanSnapshotVO
import com.smartfinance.domain.plan_insights.SavingsProjectionVO
import com.smartfinance.domain.plan_insights.TopCategoriesResultVO
import com.smartfinance.domain.plan_insights.TopCategoryVO
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
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
        val cachedProjection = memoryCache.getSnapshot()
            ?.savingsProjection
            ?.takeIf { it.isValidCacheEntry() }

        if (!forceRefresh) {
            if (cachedProjection != null) {
                Log.d("BqRepository", "Returning savings projection from memory cache")
                return cachedProjection
            }

            val persistedProjection = localDao.getSavingsProjectionCache(userId)
                ?.toDomain()
                ?.takeIf { it.isValidCacheEntry() }
            if (persistedProjection != null) {
                Log.d("BqRepository", "Returning savings projection from Room cache")
                memoryCache.saveSnapshot(
                    PlanSnapshotVO(
                        savingsProjection = persistedProjection,
                        topCategories = memoryCache.getSnapshot()?.topCategories,
                        fetchedAt = System.currentTimeMillis()
                    )
                )
                return persistedProjection
            }
        }

        try {
            Log.d("BqRepository", "Fetching savings projection from remote")
            val freshProjection = remoteDataSource.getSavingsProjection()

            val currentSnapshot = memoryCache.getSnapshot()
            val newSnapshot = PlanSnapshotVO(
                savingsProjection = freshProjection,
                topCategories = currentSnapshot?.topCategories,
                fetchedAt = System.currentTimeMillis()
            )

            memoryCache.saveSnapshot(newSnapshot)
            localDao.saveSavingsProjectionCache(freshProjection.toLocal(userId))
            Log.d("BqRepository", "Saved fresh savings projection in memory cache")

            return freshProjection
        } catch (e: Exception) {
            val persistedProjection = localDao.getSavingsProjectionCache(userId)
                ?.toDomain()
                ?.takeIf { it.isValidCacheEntry() }
            val fallbackProjection = cachedProjection ?: persistedProjection

            if (fallbackProjection != null) {
                Log.w("BqRepository", "Remote savings projection failed; returning cache", e)
                memoryCache.saveSnapshot(
                    PlanSnapshotVO(
                        savingsProjection = fallbackProjection,
                        topCategories = memoryCache.getSnapshot()?.topCategories,
                        fetchedAt = System.currentTimeMillis()
                    )
                )
                return fallbackProjection
            }
            throw e
        }
    }

    override suspend fun getTopCategories(forceRefresh: Boolean): TopCategoriesResultVO {
        val userId = requireUserId()
        val cachedTopCategories = memoryCache.getSnapshot()?.topCategories

        if (!forceRefresh) {
            if (cachedTopCategories != null) {
                Log.d("BqRepository", "Returning top categories from memory cache")
                return cachedTopCategories
            }

            val persistedTopCategories = localDao.getTopCategoriesCache(userId)?.toDomain()
            if (persistedTopCategories != null) {
                Log.d("BqRepository", "Returning top categories from Room cache")
                memoryCache.saveSnapshot(
                    PlanSnapshotVO(
                        savingsProjection = memoryCache.getSnapshot()?.savingsProjection,
                        topCategories = persistedTopCategories,
                        fetchedAt = System.currentTimeMillis()
                    )
                )
                return persistedTopCategories
            }
        }

        try {
            Log.d("BqRepository", "Fetching top categories from remote")
            val freshTopCategories = remoteDataSource.getTopCategories()

            val currentSnapshot = memoryCache.getSnapshot()
            val newSnapshot = PlanSnapshotVO(
                savingsProjection = currentSnapshot?.savingsProjection,
                topCategories = freshTopCategories,
                fetchedAt = System.currentTimeMillis()
            )

            memoryCache.saveSnapshot(newSnapshot)
            localDao.saveTopCategoriesCache(freshTopCategories.toLocal(userId))
            Log.d("BqRepository", "Saved fresh top categories in memory cache and Room")

            return freshTopCategories
        } catch (e: Exception) {
            val persistedTopCategories = localDao.getTopCategoriesCache(userId)?.toDomain()
            val fallbackTopCategories = cachedTopCategories ?: persistedTopCategories

            if (fallbackTopCategories != null) {
                Log.w("BqRepository", "Remote top categories failed; returning cache", e)
                memoryCache.saveSnapshot(
                    PlanSnapshotVO(
                        savingsProjection = memoryCache.getSnapshot()?.savingsProjection,
                        topCategories = fallbackTopCategories,
                        fetchedAt = System.currentTimeMillis()
                    )
                )
                return fallbackTopCategories
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

    private fun SavingsProjectionVO.isValidCacheEntry(): Boolean {
        return message.isNotBlank() || projectedSavings != 0.0 || savingsGoal != 0.0
    }

    private fun LocalTopCategoriesCache.toDomain(): TopCategoriesResultVO {
        return TopCategoriesResultVO(
            totalExpenses = totalExpenses,
            periodDays = periodDays,
            topCategories = Json.decodeFromString<List<TopCategoryVO>>(topCategoriesJson),
            reason = reason
        )
    }

    private fun TopCategoriesResultVO.toLocal(userId: String): LocalTopCategoriesCache {
        return LocalTopCategoriesCache(
            userId = userId,
            totalExpenses = totalExpenses,
            periodDays = periodDays,
            topCategoriesJson = Json.encodeToString(topCategories) ?: "[]",
            reason = reason,
            cachedAt = System.currentTimeMillis()
        )
    }
}
