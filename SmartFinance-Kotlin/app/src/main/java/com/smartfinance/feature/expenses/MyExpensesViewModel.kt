package com.smartfinance.feature.expenses

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.domain.expenses.ExpenseApplicationService
import com.smartfinance.domain.expenses.ExpenseVO
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.YearMonth

@HiltViewModel
class MyExpensesViewModel @Inject constructor(
    private val expenseApplicationService: ExpenseApplicationService,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(MyExpensesUiState())
    val uiState: StateFlow<MyExpensesUiState> = _uiState.asStateFlow()

    val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    fun loadExpenses() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                errorMessage = null
            )

            try {
                val expenses = withContext(Dispatchers.IO) {
                    val userId = currentUserId
                        ?: throw IllegalStateException("Missing user session.")

                    expenseApplicationService
                        .getExpensesByUser(userId)
                        .sortedByDescending { expense ->
                            runCatching { OffsetDateTime.parse(expense.occurredAt) }.getOrNull()
                        }
                        .map { expense ->
                            expense.toUiModel()
                        }
                }

                val currentState = _uiState.value

                _uiState.value = currentState.copy(
                    isLoading = false,
                    expenses = expenses,
                    filteredExpenses = applyFilters(
                        expenses = expenses,
                        query = currentState.searchQuery,
                        filter = currentState.selectedFilter,
                        selectedCategory = currentState.selectedCategory
                    )
                )
            } catch (exception: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = exception.message ?: "Could not load expenses."
                )
            }
        }
    }

    fun onSearchQueryChanged(query: String) {
        val currentState = _uiState.value

        _uiState.value = currentState.copy(
            searchQuery = query,
            filteredExpenses = applyFilters(
                expenses = currentState.expenses,
                query = query,
                filter = currentState.selectedFilter,
                selectedCategory = currentState.selectedCategory
            )
        )
    }

    fun onFilterChanged(filter: ExpenseListFilter) {
        val currentState = _uiState.value

        _uiState.value = currentState.copy(
            selectedFilter = filter,
            filteredExpenses = applyFilters(
                expenses = currentState.expenses,
                query = currentState.searchQuery,
                filter = filter,
                selectedCategory = currentState.selectedCategory
            )
        )
    }

    fun onCategorySelected(category: String?) {
        val currentState = _uiState.value

        _uiState.value = currentState.copy(
            selectedCategory = category,
            filteredExpenses = applyFilters(
                expenses = currentState.expenses,
                query = currentState.searchQuery,
                filter = currentState.selectedFilter,
                selectedCategory = category
            )
        )
    }

    private fun applyFilters(
        expenses: List<ExpenseItemUiModel>,
        query: String,
        filter: ExpenseListFilter,
        selectedCategory: String?
    ): List<ExpenseItemUiModel> {
        val byCycle = when (filter) {
            ExpenseListFilter.CURRENT_CYCLE -> expenses.filter { expense ->
                isFromCurrentMonth(expense.occurredAt)
            }

            ExpenseListFilter.ALL -> expenses
        }

        val byCategory = if (selectedCategory.isNullOrBlank()) {
            byCycle
        } else {
            byCycle.filter { expense ->
                expense.category.equals(selectedCategory, ignoreCase = true)
            }
        }

        if (query.isBlank()) return byCategory

        return byCategory.filter { expense ->
            expense.category.contains(query, ignoreCase = true) ||
                    expense.note.contains(query, ignoreCase = true)
        }
    }

    private fun ExpenseVO.toUiModel(): ExpenseItemUiModel {
        // Mapeamos utilities -> Bills para el usuario
        val displayCategory = when(category.lowercase()) {
            "utilities" -> "Bills"
            else -> category.replaceFirstChar { it.titlecase(Locale.getDefault()) }
        }

        return ExpenseItemUiModel(
            id = id,
            category = displayCategory,
            note = note?.ifBlank { "No note" } ?: "No note",
            dateText = formatDate(occurredAt),
            amountText = "${currency.uppercase()} ${String.format(Locale.US, "%.2f", amount)}",
            icon = getIconForCategory(category),
            occurredAt = occurredAt,
            receiptImageUrl = receiptImageUrl
        )
    }

    private fun formatDate(rawDate: String): String {
        return try {
            val parsedDate = OffsetDateTime.parse(rawDate)
            val formatter = DateTimeFormatter.ofPattern("d MMM, HH:mm", Locale.US)
            parsedDate.format(formatter)
        } catch (exception: Exception) {
            rawDate
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
            "food", "restaurant", "groceries" -> "🍴"
            "shopping" -> "🛍️"
            "health" -> "🩺"
            "entertainment" -> "🎮"
            "utilities", "bills" -> "💡"
            else -> "💸"
        }
    }
}
