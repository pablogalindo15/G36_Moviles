package com.smartfinance.feature.expenses

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.core.model.UiState
import com.smartfinance.domain.expenses.ExpenseApplicationService
import com.smartfinance.domain.expenses.ExpenseVO
import com.smartfinance.domain.expenses.LogExpenseRequestDTO
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

@HiltViewModel
class LogExpenseViewModel @Inject constructor(
    private val expenseApplicationService: ExpenseApplicationService
) : ViewModel() {

    private val _saveExpenseState = MutableStateFlow<UiState<ExpenseVO>>(UiState.Idle)
    val saveExpenseState: StateFlow<UiState<ExpenseVO>> = _saveExpenseState.asStateFlow()

    fun saveExpense(request: LogExpenseRequestDTO) {
        viewModelScope.launch {
            _saveExpenseState.value = UiState.Loading
            try {
                _saveExpenseState.value = UiState.Success(
                    expenseApplicationService.logExpense(request)
                )
            } catch (e: Exception) {
                _saveExpenseState.value = UiState.Error(
                    e.message ?: "Couldn't save expense."
                )
            }
        }
    }

    fun resetState() {
        _saveExpenseState.value = UiState.Idle
    }
}
