package com.smartfinance.feature.spending_insights

data class SpendingInsightsUiState(
    val isLoading: Boolean = false,
    val topCategories: List<CategoryInsightUiModel> = emptyList(),
    val errorMessage: String? = null
)

