package com.smartfinance.feature.spending_insights

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.domain.expenses.ExpenseApplicationService
import com.smartfinance.domain.expenses.ExpenseVO
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import java.time.OffsetDateTime
import java.time.YearMonth
import java.util.Locale
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@HiltViewModel
class SpendingInsightsViewModel @Inject constructor(
    private val expenseApplicationService: ExpenseApplicationService,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(SpendingInsightsUiState())
    val uiState: StateFlow<SpendingInsightsUiState> = _uiState.asStateFlow()

    fun loadInsights() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                errorMessage = null
            )

            try {
                val insights = withContext(Dispatchers.IO) {
                    val userId = supabaseClient.auth.currentUserOrNull()?.id
                        ?: throw IllegalStateException("Missing user session.")

                    val expenses = expenseApplicationService.getExpensesByUser(userId)

                    buildTopCategoryInsights(expenses)
                }

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    topCategories = insights
                )
            } catch (exception: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = exception.message ?: "Could not load insights."
                )
            }
        }
    }

    private fun buildTopCategoryInsights(
        expenses: List<ExpenseVO>
    ): List<CategoryInsightUiModel> {
        val currentMonthExpenses = expenses.filter { expense ->
            isFromCurrentMonth(expense.occurredAt)
        }

        val totalsByCategory = currentMonthExpenses
            .groupBy { expense -> expense.category }
            .mapValues { entry ->
                entry.value.sumOf { expense -> expense.amount }
            }
            .toList()
            .sortedByDescending { (_, totalAmount) -> totalAmount }

        val maxAmount = totalsByCategory.maxOfOrNull { (_, amount) -> amount } ?: 0.0

        if (maxAmount <= 0.0) return emptyList()

        return totalsByCategory.map { (category, amount) ->
            val percentage = ((amount / maxAmount) * 100).toInt().coerceIn(1, 100)

            CategoryInsightUiModel(
                category = category,
                amountText = "USD ${String.format(Locale.US, "%.2f", amount)}",
                percentage = percentage,
                icon = getIconForCategory(category)
            )
        }
    }

    private fun isFromCurrentMonth(rawDate: String): Boolean {
        return try {
            val expenseDate = OffsetDateTime.parse(rawDate)
            YearMonth.from(expenseDate) == YearMonth.now(expenseDate.offset)
        } catch (_: Exception) {
            false
        }
    }

    private fun getIconForCategory(category: String): String {
        return when (category.lowercase()) {
            "transport", "transportation", "taxi", "uber" -> "🚗"
            "food", "restaurant", "groceries" -> "🍽️"
            "shopping" -> "🛍️"
            "health" -> "🩺"
            "entertainment" -> "🎬"
            "education" -> "🎓"
            "housing" -> "🏠"
            "utilities" -> "💡"
            else -> "💸"
        }
    }
}