package com.smartfinance.domain.plan_insights

import com.smartfinance.data.plan_insights.BqRepository
import javax.inject.Inject

class PlanInsightsFacade @Inject constructor(
    private val repository: BqRepository
) {
    suspend fun getSavingsProjection(forceRefresh: Boolean = false): SavingsProjectionVO {
        return repository.getSavingsProjection(forceRefresh)
    }

    suspend fun getTopCategories(forceRefresh: Boolean = false): TopCategoriesResultVO {
        return repository.getTopCategories(forceRefresh)
    }
}