package com.smartfinance.data.plan_insights

import com.smartfinance.domain.plan_insights.SavingsProjectionVO
import com.smartfinance.domain.plan_insights.TopCategoriesResultVO
import com.smartfinance.domain.plan_insights.TopCategoryVO
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import javax.inject.Inject

class PlanRemoteDataSource @Inject constructor(
    private val supabaseClient: SupabaseClient
) {

    suspend fun getSavingsProjection(): SavingsProjectionVO {
        val response = supabaseClient.functions.invoke("get-bq-savings-projection")
        val body = response.bodyAsText()
        val json = Json.parseToJsonElement(body).jsonObject

        return SavingsProjectionVO(
            isOnTrack = json.booleanValue("isOnTrack", "is_on_track") ?: false,
            projectedSavings = json.doubleValue("projectedSavings", "projected_savings") ?: 0.0,
            savingsGoal = json.doubleValue("savingsGoal", "savings_goal") ?: 0.0,
            message = json.stringValue("message").orEmpty(),
            computedAt = json.longValue("computedAt", "computed_at") ?: System.currentTimeMillis()
        )
    }

    suspend fun getTopCategories(): TopCategoriesResultVO {
        val response = supabaseClient.functions.invoke("get-bq-top-categories")
        val body = response.bodyAsText()
        val json = Json.parseToJsonElement(body).jsonObject

        val topCategories = json["top_categories"]?.jsonArray?.map {
            val obj = it.jsonObject
            TopCategoryVO(
                category = obj.stringValue("category").orEmpty(),
                count = obj.intValue("count") ?: 0,
                percentage = obj.doubleValue("percentage") ?: 0.0
            )
        } ?: emptyList()

        return TopCategoriesResultVO(
            totalExpenses = json.intValue("total_expenses") ?: 0,
            periodDays = json.intValue("period_days") ?: 0,
            topCategories = topCategories,
            reason = json.stringValue("reason")
        )
    }

    private fun JsonObject.booleanValue(vararg keys: String): Boolean? {
        return firstPrimitive(keys)?.booleanOrNull
    }

    private fun JsonObject.doubleValue(vararg keys: String): Double? {
        return firstPrimitive(keys)?.doubleOrNull
    }

    private fun JsonObject.longValue(vararg keys: String): Long? {
        return firstPrimitive(keys)?.longOrNull
    }

    private fun JsonObject.stringValue(vararg keys: String): String? {
        return firstPrimitive(keys)?.contentOrNull
    }

    private fun JsonObject.intValue(vararg keys: String): Int? {
        return firstPrimitive(keys)?.intOrNull
    }

    private fun JsonObject.firstPrimitive(keys: Array<out String>) =
        keys.firstNotNullOfOrNull { key -> this[key]?.jsonPrimitive }
}
