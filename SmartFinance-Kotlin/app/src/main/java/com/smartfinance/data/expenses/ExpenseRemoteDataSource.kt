package com.smartfinance.data.expenses
import com.smartfinance.domain.expenses.UpdateExpenseRequestDTO

import com.smartfinance.core.model.ExpenseInsert
import com.smartfinance.core.model.ExpenseRecord
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
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

    suspend fun updateExpense(request: UpdateExpenseRequestDTO): ExpenseRecord {
        return supabaseClient.from("expenses")
            .update(
                {
                    set("category", request.category)
                    set("note", request.note)
                    set("amount", request.amount)
                    set("occurred_at", request.occurredAt)
                }
            ) {
                filter {
                    eq("id", request.expenseId)
                }
                select()
            }
            .decodeSingle<ExpenseRecord>()
    }

    suspend fun deleteExpense(expenseId: String) {
        supabaseClient.from("expenses")
            .delete {
                filter {
                    eq("id", expenseId)
                }
            }
    }
}