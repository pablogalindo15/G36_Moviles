package com.smartfinance.data.sync

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ListenableWorker.Result
import com.smartfinance.core.model.ExpenseInsert
import com.smartfinance.data.expenses.ExpenseRemoteDataSource
import com.smartfinance.data.local.LocalExpense
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.data.local.toLocal
import com.smartfinance.domain.expenses.UpdateExpenseRequestDTO
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@HiltWorker
class SyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val localDao: SmartFinanceDao,
    private val remoteDataSource: ExpenseRemoteDataSource
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val pendingExpenses = localDao.getPendingSyncExpenses()
        if (pendingExpenses.isEmpty()) return@withContext Result.success()

        var hasError = false

        pendingExpenses.forEach { localExpense ->
            try {
                when (localExpense.syncStatus) {
                    "PENDING_INSERT" -> handleInsert(localExpense)
                    "PENDING_UPDATE" -> handleUpdate(localExpense)
                    "PENDING_DELETE" -> handleDelete(localExpense)
                }
            } catch (e: Exception) {
                Log.e("SyncWorker", "Error syncing expense ${localExpense.id}", e)
                hasError = true
            }
        }

        if (hasError) Result.retry() else Result.success()
    }

    private suspend fun handleInsert(local: LocalExpense) {
        val remoteRecord = remoteDataSource.insertExpense(
            ExpenseInsert(
                userId = local.userId,
                amount = local.amount,
                currency = local.currency,
                category = local.category,
                note = local.note,
                occurredAt = local.occurredAt,
                clientUuid = local.clientUuid
            )
        )
        localDao.deleteExpense(local.id)
        localDao.saveExpense(remoteRecord.toLocal("SYNCED"))
    }

    private suspend fun handleUpdate(local: LocalExpense) {
        if (!local.id.startsWith("temp_")) {
            remoteDataSource.updateExpense(
                UpdateExpenseRequestDTO(
                    expenseId = local.id,
                    category = local.category,
                    note = local.note.orEmpty(),
                    amount = local.amount,
                    occurredAt = local.occurredAt
                )
            )
        }
        localDao.saveExpense(local.copy(syncStatus = "SYNCED"))
    }

    private suspend fun handleDelete(local: LocalExpense) {
        if (!local.id.startsWith("temp_")) {
            remoteDataSource.deleteExpense(local.id)
        }
        localDao.deleteExpense(local.id)
    }
}
