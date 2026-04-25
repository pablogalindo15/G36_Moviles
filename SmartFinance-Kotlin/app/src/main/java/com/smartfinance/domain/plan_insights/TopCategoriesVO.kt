package com.smartfinance.domain.plan_insights

import kotlinx.serialization.Serializable

@Serializable
data class TopCategoryVO(
    val category: String,
    val count: Int,
    val percentage: Double
)

@Serializable
data class TopCategoriesResultVO(
    val totalExpenses: Int,
    val periodDays: Int,
    val topCategories: List<TopCategoryVO>,
    val reason: String? = null
)
