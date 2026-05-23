package com.smartfinance.feature.spending_insights

data class SpendingInsightsUiState(
    val isLoading: Boolean = false,
    val biggestExpense: BiggestExpenseUiModel? = null,
    val topCategories: List<CategoryInsightUiModel> = emptyList(),
    val streaks: List<CategoryStreakUiModel> = emptyList(),
    val evaluatedAtText: String? = null,
    val errorMessage: String? = null
)
