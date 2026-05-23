package com.smartfinance.data.expenses

import android.content.Context
import androidx.work.Constraints
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.smartfinance.data.local.LocalExpense
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.data.local.toDomain
import com.smartfinance.data.sync.SyncWorker
import com.smartfinance.domain.expenses.ExpenseVO
import com.smartfinance.domain.expenses.LogExpenseRequestDTO
import com.smartfinance.domain.expenses.UpdateExpenseRequestDTO
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import javax.inject.Inject

class SupabaseExpenseAdapter @Inject constructor(
    @ApplicationContext private val context: Context,
    private val remoteDataSource: ExpenseRemoteDataSource,
    private val localDao: SmartFinanceDao
) : ExpenseRepository {

    override suspend fun logExpense(request: LogExpenseRequestDTO): ExpenseVO {
        val clientUuid = UUID.randomUUID().toString()
        val tempId = "temp_$clientUuid"
        
        val localExpense = LocalExpense(
            id = tempId,
            userId = request.userId,
            amount = request.amount,
            currency = request.currency,
            category = request.category,
            note = request.note.ifBlank { null },
            occurredAt = request.occurredAt
                .atZone(ZoneId.systemDefault())
                .toInstant()
                .toString(),
            createdAt = Instant.now().toString(),
            clientUuid = clientUuid,
            receiptImageUrl = null,
            receiptLocalUri = null,
            receiptSyncStatus = "none",
            syncStatus = "PENDING_INSERT"
        )

        localDao.saveExpense(localExpense)
        scheduleSync()
        
        return localExpense.toDomain()
    }

    override suspend fun getExpensesByUser(userId: String): List<ExpenseVO> {
        try {
            val remoteExpenses = remoteDataSource.getExpensesByUser(userId)
            remoteExpenses.forEach { remoteExpense ->
                val existing = localDao.getExpenseById(remoteExpense.id)
                if (existing?.syncStatus == null || existing.syncStatus == "SYNCED") {
                    localDao.saveExpense(
                        LocalExpense(
                            id = remoteExpense.id,
                            userId = remoteExpense.userId,
                            amount = remoteExpense.amount,
                            currency = remoteExpense.currency,
                            category = remoteExpense.category,
                            note = remoteExpense.note,
                            occurredAt = remoteExpense.occurredAt,
                            createdAt = remoteExpense.createdAt,
                            clientUuid = remoteExpense.clientUuid,
                            receiptImageUrl = remoteExpense.receiptImageUrl,
                            receiptLocalUri = existing?.receiptLocalUri,
                            receiptSyncStatus = if (remoteExpense.receiptImageUrl.isNullOrBlank()) "none" else "uploaded",
                            syncStatus = "SYNCED"
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // Offline or error, fallback to local data
        }

        return localDao.getExpenses(userId).first().map { it.toDomain() }
    }

    override suspend fun updateExpense(request: UpdateExpenseRequestDTO): ExpenseVO {
        val existing = localDao.getExpenseById(request.expenseId)
            ?: throw IllegalStateException("Expense not found locally")

        val updatedLocal = existing.copy(
            amount = request.amount,
            category = request.category,
            note = request.note.ifBlank { null },
            occurredAt = request.occurredAt.ifBlank { existing.occurredAt },
            syncStatus = if (existing.syncStatus == "PENDING_INSERT") "PENDING_INSERT" else "PENDING_UPDATE"
        )

        localDao.saveExpense(updatedLocal)
        scheduleSync()
        
        return updatedLocal.toDomain()
    }

    override suspend fun deleteExpense(expenseId: String) {
        val existing = localDao.getExpenseById(expenseId) ?: return
        
        if (existing.syncStatus == "PENDING_INSERT") {
            localDao.deleteExpense(expenseId)
        } else {
            localDao.saveExpense(existing.copy(syncStatus = "PENDING_DELETE"))
            scheduleSync()
        }
    }

    private fun scheduleSync() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val syncRequest = OneTimeWorkRequestBuilder<SyncWorker>()
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(context).enqueue(syncRequest)
    }
}
