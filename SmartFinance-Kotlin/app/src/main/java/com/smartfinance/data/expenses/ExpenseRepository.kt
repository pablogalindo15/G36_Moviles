package com.smartfinance.data.expenses

import com.smartfinance.domain.expenses.ExpenseVO
import com.smartfinance.domain.expenses.LogExpenseRequestDTO

interface ExpenseRepository {
    suspend fun logExpense(request: LogExpenseRequestDTO): ExpenseVO
}
