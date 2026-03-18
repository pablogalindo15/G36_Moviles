package com.smartfinance.domain.onboarding

import com.smartfinance.core.model.FinancialSetup
import com.smartfinance.core.model.GeneratedPlan
import com.smartfinance.data.onboarding.OnboardingRepository

class OnboardingFacade(
    private val repository: OnboardingRepository
) {

    suspend fun saveFinancialSetup(setup: FinancialSetup): String {
        return repository.saveFinancialSetup(setup)
    }

    suspend fun saveGeneratedPlan(plan: GeneratedPlan) {
        repository.saveGeneratedPlan(plan)
    }
}
