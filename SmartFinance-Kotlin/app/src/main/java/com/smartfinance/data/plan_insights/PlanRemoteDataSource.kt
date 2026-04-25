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
import java.util.Locale
import javax.inject.Inject

class PlanRemoteDataSource @Inject constructor(
    private val supabaseClient: SupabaseClient
) {

    suspend fun getSavingsProjection(): SavingsProjectionVO {
        val response = supabaseClient.functions.invoke("get-bq-savings-projection")
        val body = response.bodyAsText()
        val json = Json.parseToJsonElement(body).jsonObject

        json.stringValue("error")?.let { error ->
            throw IllegalStateException(error)
        }

        val insufficientData = json.booleanValue("insufficient_data") == true
        val expensesCountBasis = json.intValue("expenses_count_basis") ?: 0
        if (insufficientData) {
            return SavingsProjectionVO(
                isOnTrack = false,
                projectedSavings = 0.0,
                savingsGoal = 0.0,
                message = "Not enough data yet. Log at least 3 expenses in the last 2 weeks. Current: $expensesCountBasis.",
                computedAt = System.currentTimeMillis()
            )
        }

        val isOnTrack = json.booleanValue("isOnTrack", "is_on_track", "on_track")
            ?: throw IllegalStateException("Missing on_track")
        val projectedSavings = json.doubleValue("projectedSavings", "projected_savings")
            ?: throw IllegalStateException("Missing projected_savings")
        val savingsGoal = json.doubleValue("savingsGoal", "savings_goal")
            ?: throw IllegalStateException("Missing savings_goal")
        val currency = json.stringValue("currency").orEmpty()
        val delta = json.doubleValue("delta")

        return SavingsProjectionVO(
            isOnTrack = isOnTrack,
            projectedSavings = projectedSavings,
            savingsGoal = savingsGoal,
            message = buildSavingsProjectionMessage(
                isOnTrack = isOnTrack,
                currency = currency,
                delta = delta
            ),
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

    private fun buildSavingsProjectionMessage(
        isOnTrack: Boolean,
        currency: String,
        delta: Double?
    ): String {
        if (delta == null) {
            return if (isOnTrack) "On track." else "Off track."
        }

        val formattedDelta = String.format(Locale.US, "%.2f", kotlin.math.abs(delta))
        return if (isOnTrack) {
            "On track. You'll exceed your goal by $currency $formattedDelta."
        } else {
            "Off track. You'll be short by $currency $formattedDelta."
        }
    }

    private fun JsonObject.firstPrimitive(keys: Array<out String>) =
        keys.firstNotNullOfOrNull { key -> this[key]?.jsonPrimitive }
}
