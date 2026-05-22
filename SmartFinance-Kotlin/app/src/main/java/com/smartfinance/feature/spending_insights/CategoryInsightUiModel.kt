package com.smartfinance.feature.spending_insights

data class CategoryInsightUiModel(
    val category: String,
    val amountText: String,
    val percentage: Int,
    val icon: String
)