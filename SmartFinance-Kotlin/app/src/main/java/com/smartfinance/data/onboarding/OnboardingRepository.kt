package com.smartfinance.data.onboarding

import com.smartfinance.core.model.FinancialSetup
import com.smartfinance.core.model.GeneratedPlan
import com.smartfinance.domain.onboarding.PlanRequestDTO

interface OnboardingRepository {
    suspend fun saveFinancialSetup(setup: FinancialSetup): String
    suspend fun saveGeneratedPlan(plan: GeneratedPlan)
    suspend fun fetchFinancialSetup(userId: String): FinancialSetup?
    suspend fun fetchGeneratedPlan(userId: String): GeneratedPlan?
}
