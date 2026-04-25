package com.smartfinance.data.expenses

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
}
