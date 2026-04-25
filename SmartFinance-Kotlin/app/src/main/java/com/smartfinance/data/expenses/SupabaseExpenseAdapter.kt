package com.smartfinance.data.expenses

import com.smartfinance.core.model.ExpenseInsert
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.data.local.toDomain
import com.smartfinance.data.local.toLocal
import com.smartfinance.domain.expenses.ExpenseVO
import com.smartfinance.domain.expenses.LogExpenseRequestDTO
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
}
