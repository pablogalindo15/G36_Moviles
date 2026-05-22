package com.smartfinance.data.insights

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class TopSpendingCategoriesResponse(
    @SerialName("period")
    val period: String = "",

    @SerialName("total_spent")
    val totalSpent: Double = 0.0,

    @SerialName("top_categories")
    val topCategories: List<TopSpendingCategoryRecord> = emptyList()
)

@Serializable
data class TopSpendingCategoryRecord(
    @SerialName("category")
    val category: String,

    @SerialName("total")
    val total: Double = 0.0,

    @SerialName("percentage")
    val percentage: Double = 0.0
)