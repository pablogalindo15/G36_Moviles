package com.smartfinance.data.plan_insights

import com.smartfinance.domain.plan_insights.SavingsProjectionVO
import com.smartfinance.domain.plan_insights.TopCategoriesResultVO

interface BqRepository {
    suspend fun getSavingsProjection(forceRefresh: Boolean = false): SavingsProjectionVO
    suspend fun getTopCategories(forceRefresh: Boolean = false): TopCategoriesResultVO
}