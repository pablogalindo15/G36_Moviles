package com.smartfinance.data.onboarding

import com.smartfinance.core.model.FinancialSetup
import com.smartfinance.core.model.GeneratedPlan

class SupabasePlanAdapter(
    private val remoteDataSource: OnboardingRemoteDataSource
) : OnboardingRepository {

    override suspend fun saveFinancialSetup(setup: FinancialSetup): String {
        return remoteDataSource.insertFinancialSetup(setup)
    }

    override suspend fun saveGeneratedPlan(plan: GeneratedPlan) {
        remoteDataSource.generatePlan(plan)
    }

    override suspend fun fetchFinancialSetup(userId: String): FinancialSetup? {
        return remoteDataSource.fetchFinancialSetup(userId)
    }

    override suspend fun fetchGeneratedPlan(userId: String): GeneratedPlan? {
        return remoteDataSource.fetchGeneratedPlan(userId)
    }
}
