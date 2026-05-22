package com.smartfinance.data.insights

import android.util.Log
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.json.Json
import javax.inject.Inject

class SpendingInsightsRemoteDataSource @Inject constructor(
    private val supabaseClient: SupabaseClient
) {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun getTopSpendingCategories(): TopSpendingCategoriesResponse {
        val response = supabaseClient.functions.invoke(
            "get-bq-top-spending-categories"
        )

        val jsonString = response.bodyAsText()

        Log.d("TopSpendingCategories", "Response: $jsonString")

        return json.decodeFromString<TopSpendingCategoriesResponse>(jsonString)
    }

    suspend fun getCategoryStreaks(): CategoryStreaksResponse {
        val response = supabaseClient.functions.invoke(
            "get-bq-category-streaks"
        )
        val jsonString = response.bodyAsText()
        Log.d("CategoryStreaks", "Response: $jsonString")
        return json.decodeFromString<CategoryStreaksResponse>(jsonString)
    }
}
