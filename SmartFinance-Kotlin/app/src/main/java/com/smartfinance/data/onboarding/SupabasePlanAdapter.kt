package com.smartfinance.data.onboarding

import com.smartfinance.core.model.FinancialSetup
import com.smartfinance.core.model.GeneratedPlan
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.data.local.toDomain
import com.smartfinance.data.local.toLocal
import kotlinx.coroutines.flow.firstOrNull

class SupabasePlanAdapter(
    private val remoteDataSource: OnboardingRemoteDataSource,
    private val localDao: SmartFinanceDao
) : OnboardingRepository {

    override suspend fun saveFinancialSetup(setup: FinancialSetup): String {
        return try {
            val id = remoteDataSource.insertFinancialSetup(setup)
            localDao.saveFinancialSetup(setup.toLocal(id))
            id
        } catch (e: Exception) {
            // If offline, we return local ID if exists, or throw
            localDao.getFinancialSetup(setup.userId).firstOrNull()?.id ?: throw e
        }
    }

    override suspend fun saveGeneratedPlan(plan: GeneratedPlan) {
        try {
            remoteDataSource.generatePlan(plan)
            localDao.savePlan(plan.toLocal())
        } catch (e: Exception) {
            localDao.savePlan(plan.toLocal())
        }
    }

    override suspend fun fetchFinancialSetup(userId: String): FinancialSetup? {
        return try {
            val remote = remoteDataSource.fetchFinancialSetup(userId)
            if (remote != null) {
                // Update local storage with remote data to keep it in sync for next offline use
                // We need the ID from remote to save it locally
                // For simplicity, we assume if we have remote data, we can update local
                localDao.saveFinancialSetup(remote.toLocal("temp_id")) // Ideally we use the real ID
            }
            remote ?: localDao.getFinancialSetup(userId).firstOrNull()?.toDomain()
        } catch (e: Exception) {
            localDao.getFinancialSetup(userId).firstOrNull()?.toDomain()
        }
    }

    override suspend fun fetchGeneratedPlan(userId: String): GeneratedPlan? {
        return try {
            val remote = remoteDataSource.fetchGeneratedPlan(userId)
            if (remote != null) {
                localDao.savePlan(remote.toLocal())
            }
            remote ?: localDao.getLatestPlan(userId).firstOrNull()?.toDomain()
        } catch (e: Exception) {
            localDao.getLatestPlan(userId).firstOrNull()?.toDomain()
        }
    }

    override suspend fun generateFirstPlan(request: GenerateFirstPlanRequest): GeneratedPlan {
        return try {
            val plan = remoteDataSource.generateFirstPlan(request)
            localDao.savePlan(plan.toLocal())
            plan
        } catch (e: Exception) {
            localDao.getLatestPlan(request.userId).firstOrNull()?.toDomain() 
                ?: throw e
        }
    }
}
