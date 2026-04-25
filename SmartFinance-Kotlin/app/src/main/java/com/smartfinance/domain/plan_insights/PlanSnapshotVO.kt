package com.smartfinance.domain.plan_insights

data class PlanSnapshotVO(
    val savingsProjection: SavingsProjectionVO?,
    val topCategories: TopCategoriesResultVO? = null,
    val fetchedAt: Long
)