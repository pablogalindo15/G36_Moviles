package com.smartfinance.feature.spending_insights

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.domain.expenses.ExpenseApplicationService
import com.smartfinance.domain.onboarding.OnboardingApplicationService
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import java.time.OffsetDateTime
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
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
    private val expenseService: ExpenseApplicationService,
    private val onboardingService: OnboardingApplicationService,
    private val supabase: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(SpendingInsightsUiState())
    val uiState: StateFlow<SpendingInsightsUiState> = _uiState.asStateFlow()

    fun loadInsights() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)

            try {
                val userId = supabase.auth.currentUserOrNull()?.id
                    ?: throw IllegalStateException("User not authenticated")

                // Obtenemos los gastos directamente (Tiempo Real / Postgres)
                val allExpenses = withContext(Dispatchers.IO) {
                    expenseService.getExpensesByUser(userId)
                }
                
                val existingPlan = withContext(Dispatchers.IO) {
                    onboardingService.fetchExistingPlan(userId)
                }
                val userCurrency = existingPlan?.currency ?: "USD"

                if (allExpenses.isEmpty()) {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false, 
                        biggestExpense = null,
                        topCategories = emptyList(), 
                        streaks = emptyList(),
                        evaluatedAtText = null
                    )
                    return@launch
                }

                // 1. Spending by Category (Mes actual)
                val currentMonth = YearMonth.now()
                val currentMonthExpenses = allExpenses.filter { 
                    try {
                        val date = OffsetDateTime.parse(it.occurredAt)
                        YearMonth.from(date) == currentMonth
                    } catch (e: Exception) { false }
                }
                
                val totalByCat = currentMonthExpenses.groupBy { it.category.lowercase().trim() }
                    .mapValues { entry -> entry.value.sumOf { it.amount } }
                
                val totalSpent = totalByCat.values.sum()
                val biggestExpense = currentMonthExpenses
                    .maxByOrNull { it.amount }
                    ?.let { expense ->
                        val categoryKey = expense.category.lowercase().trim()
                        BiggestExpenseUiModel(
                            amountText = formatMoney(expense.currency, expense.amount),
                            cycleText = formatCycle(currentMonth),
                            expenseDateText = formatExpenseDate(expense.occurredAt),
                            categoryTotalText = formatMoney(
                                expense.currency,
                                totalByCat[categoryKey] ?: expense.amount
                            ),
                            categoryIcon = getIconForCategory(expense.category),
                            categoryText = formatCategoryName(expense.category)
                        )
                    }
                val topCategories = totalByCat.entries
                    .sortedByDescending { it.value }
                    .map { (cat, amount) ->
                        CategoryInsightUiModel(
                            category = formatCategoryName(cat),
                            amountText = "$userCurrency ${String.format(Locale.US, "%,.0f", amount)}",
                            percentage = if (totalSpent > 0) ((amount / totalSpent) * 100).toInt().coerceIn(1, 100) else 0,
                            icon = getIconForCategory(cat)
                        )
                    }

                // 2. Streaks (Tiempo Real - Solo categorías con gastos reales)
                val now = OffsetDateTime.now()
                val streaks = allExpenses.groupBy { it.category.lowercase().trim() }
                    .map { (cat, expenses) ->
                        val latest = expenses.map { OffsetDateTime.parse(it.occurredAt) }.maxOrNull()
                        val days = if (latest != null) {
                            val d = ChronoUnit.DAYS.between(latest, now).toInt()
                            if (d < 0) 0 else d
                        } else 30
                        
                        cat to days
                    }
                    .sortedByDescending { it.second } // Días más altos primero
                    .take(5)
                    .map { (cat, days) ->
                        CategoryStreakUiModel(
                            category = formatCategoryName(cat),
                            daysText = "$days days",
                            icon = getIconForCategory(cat)
                        )
                    }

                val evaluatedAtText = "Days without spending · ${now.format(DateTimeFormatter.ofPattern("d MMM yyyy", Locale.US))}"

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    biggestExpense = biggestExpense,
                    topCategories = topCategories,
                    streaks = streaks,
                    evaluatedAtText = evaluatedAtText
                )

            } catch (exception: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = "Could not load insights."
                )
            }
        }
    }

    private fun formatCategoryName(category: String): String {
        return when(category.lowercase().trim()) {
            "utilities", "bills" -> "Bills"
            else -> category.trim().replaceFirstChar { it.titlecase(Locale.getDefault()) }
        }
    }

    private fun formatMoney(currency: String, amount: Double): String {
        return "${currency.uppercase(Locale.US)} ${String.format(Locale.US, "%,.2f", amount)}"
    }

    private fun formatCycle(cycle: YearMonth): String {
        val formatter = DateTimeFormatter.ofPattern("MMM d", Locale.US)
        val start = cycle.atDay(1)
        val end = cycle.atEndOfMonth()
        return "${start.format(formatter)} - ${end.format(formatter)}, ${cycle.year}"
    }

    private fun formatExpenseDate(rawDate: String): String {
        return try {
            OffsetDateTime.parse(rawDate)
                .format(DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US))
        } catch (_: Exception) {
            rawDate
        }
    }

    private fun getIconForCategory(category: String): String {
        return when (category.lowercase().trim()) {
            "transport", "transportation" -> "🚗"
            "food", "restaurant", "groceries" -> "🍴"
            "shopping" -> "🛍️"
            "health" -> "🩺"
            "entertainment" -> "🎮"
            "utilities", "bills" -> "💡"
            else -> "💸"
        }
    }
}
