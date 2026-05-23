package com.smartfinance.data.expenses
import com.smartfinance.domain.expenses.UpdateExpenseRequestDTO

import com.smartfinance.core.model.ExpenseInsert
import com.smartfinance.core.model.ExpenseRecord
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.storage.storage
import javax.inject.Inject

class ExpenseRemoteDataSource @Inject constructor(
    private val supabaseClient: SupabaseClient
) {

    suspend fun insertExpense(expense: ExpenseInsert): ExpenseRecord {
        return supabaseClient.from("expenses")
            .insert(expense) { select() }
            .decodeSingle<ExpenseRecord>()
    }

    suspend fun getExpensesByUser(userId: String): List<ExpenseRecord> {
        return supabaseClient.from("expenses")
            .select {
                filter {
                    eq("user_id", userId)
                }
            }
            .decodeList<ExpenseRecord>()
    }

    suspend fun getExpenseById(expenseId: String): ExpenseRecord {
        return supabaseClient.from("expenses")
            .select {
                filter {
                    eq("id", expenseId)
                }
            }
            .decodeSingle<ExpenseRecord>()
    }

    suspend fun updateExpense(request: UpdateExpenseRequestDTO): ExpenseRecord {
        return supabaseClient.from("expenses")
            .update(
                {
                    set("category", request.category)
                    set("note", request.note)
                    set("amount", request.amount)
                    set("occurred_at", request.occurredAt)
                    set("receipt_image_url", request.receiptImageUrl)
                }
            ) {
                filter {
                    eq("id", request.expenseId)
                }
                select()
            }
            .decodeSingle<ExpenseRecord>()
    }

    suspend fun updateReceiptImageUrl(expenseId: String, receiptImageUrl: String?): ExpenseRecord {
        return supabaseClient.from("expenses")
            .update(
                {
                    set("receipt_image_url", receiptImageUrl)
                }
            ) {
                filter {
                    eq("id", expenseId)
                }
                select()
            }
            .decodeSingle<ExpenseRecord>()
    }

    suspend fun uploadReceiptImage(
        userId: String,
        expenseId: String,
        imageBytes: ByteArray
    ): String {
        val path = "$userId/$expenseId.jpg"
        val bucket = supabaseClient.storage.from(RECEIPTS_BUCKET)
        bucket.upload(path, imageBytes, upsert = true)
        return bucket.publicUrl(path)
    }

    suspend fun deleteExpense(expenseId: String) {
        supabaseClient.from("expenses")
            .delete {
                filter {
                    eq("id", expenseId)
                }
            }
    }

    private companion object {
        const val RECEIPTS_BUCKET = "expense-receipts"
    }
}
