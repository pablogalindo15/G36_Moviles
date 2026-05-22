package com.smartfinance.data.expenses

import com.smartfinance.domain.expenses.ExpenseVO
import com.smartfinance.domain.expenses.LogExpenseRequestDTO
import com.smartfinance.domain.expenses.UpdateExpenseRequestDTO

interface ExpenseRepository {

    suspend fun logExpense(request: LogExpenseRequestDTO): ExpenseVO

    suspend fun getExpensesByUser(userId: String): List<ExpenseVO>

    suspend fun updateExpense(request: UpdateExpenseRequestDTO): ExpenseVO

    suspend fun deleteExpense(expenseId: String)
}
