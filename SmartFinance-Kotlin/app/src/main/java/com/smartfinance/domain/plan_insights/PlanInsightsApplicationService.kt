package com.smartfinance.domain.plan_insights

import javax.inject.Inject

class PlanInsightsApplicationService @Inject constructor(
    private val facade: PlanInsightsFacade
) {
    suspend fun getSavingsProjection(forceRefresh: Boolean = false): SavingsProjectionVO {
        return facade.getSavingsProjection(forceRefresh)
    }

    suspend fun getTopCategories(forceRefresh: Boolean = false): TopCategoriesResultVO {
        return facade.getTopCategories(forceRefresh)
    }
}