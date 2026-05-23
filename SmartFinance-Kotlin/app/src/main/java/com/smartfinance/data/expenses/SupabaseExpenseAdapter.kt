package com.smartfinance.data.expenses

import com.smartfinance.core.model.ExpenseInsert
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.data.local.toDomain
import com.smartfinance.data.local.toLocal
import com.smartfinance.domain.expenses.ExpenseVO
import com.smartfinance.domain.expenses.LogExpenseRequestDTO
import com.smartfinance.domain.expenses.UpdateExpenseRequestDTO
import kotlinx.coroutines.flow.first
import java.time.ZoneId
import java.util.UUID

class SupabaseExpenseAdapter(
    private val remoteDataSource: ExpenseRemoteDataSource,
    private val localDao: SmartFinanceDao
) : ExpenseRepository {

    override suspend fun logExpense(request: LogExpenseRequestDTO): ExpenseVO {
        var remoteExpense = remoteDataSource.insertExpense(
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

        localDao.saveExpense(
            remoteExpense.toLocal().copy(
                receiptLocalUri = request.receiptLocalUri,
                receiptSyncStatus = if (request.receiptImageBytes == null) "none" else "pending"
            )
        )

        request.receiptImageBytes?.let { imageBytes ->
            val receiptUrl = remoteDataSource.uploadReceiptImage(
                userId = request.userId,
                expenseId = remoteExpense.id,
                imageBytes = imageBytes
            )
            remoteExpense = remoteDataSource.updateReceiptImageUrl(remoteExpense.id, receiptUrl)
            localDao.saveExpense(
                remoteExpense.toLocal().copy(
                    receiptLocalUri = request.receiptLocalUri,
                    receiptSyncStatus = "uploaded"
                )
            )
        }

        return remoteExpense.toDomain()
    }

    override suspend fun getExpensesByUser(userId: String): List<ExpenseVO> {
        return try {
            val remoteExpenses = remoteDataSource.getExpensesByUser(userId)

            remoteExpenses.forEach { remoteExpense ->
                val existing = localDao.getExpenseById(remoteExpense.id)
                localDao.saveExpense(
                    remoteExpense.toLocal().copy(
                        receiptLocalUri = existing?.receiptLocalUri,
                        receiptSyncStatus = if (remoteExpense.receiptImageUrl.isNullOrBlank()) {
                            "none"
                        } else {
                            "uploaded"
                        }
                    )
                )
            }

            remoteExpenses.map { remoteExpense ->
                remoteExpense.toDomain()
            }
        } catch (exception: Exception) {
            localDao.getExpenses(userId).first().map { localExpense ->
                localExpense.toDomain()
            }
        }
    }

    override suspend fun updateExpense(request: UpdateExpenseRequestDTO): ExpenseVO {
        var requestToUpdate = request
        request.receiptImageBytes?.let { imageBytes ->
            val existing = localDao.getExpenseById(request.expenseId)
            val userId = existing?.userId ?: remoteDataSource.getExpenseById(request.expenseId).userId
            val receiptUrl = remoteDataSource.uploadReceiptImage(
                userId = userId,
                expenseId = request.expenseId,
                imageBytes = imageBytes
            )
            requestToUpdate = request.copy(receiptImageUrl = receiptUrl)
            localDao.updateExpenseReceipt(
                expenseId = request.expenseId,
                receiptImageUrl = receiptUrl,
                receiptLocalUri = request.receiptLocalUri,
                receiptSyncStatus = "uploaded"
            )
        }

        val updatedExpense = remoteDataSource.updateExpense(requestToUpdate)
        localDao.saveExpense(
            updatedExpense.toLocal().copy(
                receiptLocalUri = request.receiptLocalUri,
                receiptSyncStatus = if (updatedExpense.receiptImageUrl.isNullOrBlank()) {
                    "none"
                } else {
                    "uploaded"
                }
            )
        )

        return updatedExpense.toDomain()
    }

    override suspend fun deleteExpense(expenseId: String) {
        remoteDataSource.deleteExpense(expenseId)
        localDao.deleteExpense(expenseId)
    }
}
