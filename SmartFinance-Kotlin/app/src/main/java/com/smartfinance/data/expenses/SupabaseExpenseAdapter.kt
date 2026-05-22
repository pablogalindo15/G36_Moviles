package com.smartfinance.data.expenses

import com.smartfinance.core.model.ExpenseInsert
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.data.local.toDomain
import com.smartfinance.data.local.toLocal
import com.smartfinance.domain.expenses.ExpenseVO
import com.smartfinance.domain.expenses.LogExpenseRequestDTO
import com.smartfinance.domain.expenses.UpdateExpenseRequestDTO
import java.time.ZoneId
import java.util.UUID

class SupabaseExpenseAdapter(
    private val remoteDataSource: ExpenseRemoteDataSource,
    private val localDao: SmartFinanceDao
) : ExpenseRepository {

    override suspend fun logExpense(request: LogExpenseRequestDTO): ExpenseVO {
        val remoteExpense = remoteDataSource.insertExpense(
            ExpenseInsert(
                userId = request.userId,
                amount = request.amount,
                currency = request.currency,
                category = request.category,
                note = request.note.ifBlank { null },
                occurredAt = request.occurredAt
                    .atZone(ZoneId.systemDefault())
                    .toInstant()
                    .toString(),
                clientUuid = UUID.randomUUID().toString()
            )
        )

        localDao.saveExpense(remoteExpense.toLocal())
        return remoteExpense.toDomain()
    }
    override suspend fun getExpensesByUser(userId: String): List<ExpenseVO> {
        val remoteExpenses = remoteDataSource.getExpensesByUser(userId)

        return remoteExpenses.map { remoteExpense ->
            remoteExpense.toDomain()
        }
    }

    override suspend fun updateExpense(request: UpdateExpenseRequestDTO): ExpenseVO {
        val updatedExpense = remoteDataSource.updateExpense(request)

        return updatedExpense.toDomain()
    }

    override suspend fun deleteExpense(expenseId: String) {
        remoteDataSource.deleteExpense(expenseId)
    }
}
