package com.smartfinance.data.plan_insights

import com.smartfinance.domain.plan_insights.SavingsProjectionVO

interface BqRepository {
    suspend fun getSavingsProjection(forceRefresh: Boolean = false): SavingsProjectionVO
}