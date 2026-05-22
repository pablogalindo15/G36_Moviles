package com.smartfinance.feature.expenses


data class MyExpensesUiState(
    val isLoading: Boolean = false,
    val expenses: List<ExpenseItemUiModel> = emptyList(),
    val filteredExpenses: List<ExpenseItemUiModel> = emptyList(),
    val searchQuery: String = "",
    val selectedFilter: ExpenseListFilter = ExpenseListFilter.CURRENT_CYCLE,
    val selectedCategory: String? = null,
    val errorMessage: String? = null
)

enum class ExpenseListFilter {
    CURRENT_CYCLE,
    ALL
}