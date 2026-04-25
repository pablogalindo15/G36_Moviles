package com.smartfinance.data.plan_insights

import com.smartfinance.domain.plan_insights.SavingsProjectionVO
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import javax.inject.Inject

class PlanRemoteDataSource @Inject constructor(
    private val supabaseClient: SupabaseClient
) {

    suspend fun getSavingsProjection(): SavingsProjectionVO {
        val response = supabaseClient.functions.invoke("get-bq-savings-projection")
        val body = response.bodyAsText()
        val json = Json.parseToJsonElement(body).jsonObject

        return SavingsProjectionVO(
            isOnTrack = json["isOnTrack"]?.jsonPrimitive?.booleanOrNull ?: false,
            projectedSavings = json["projectedSavings"]?.jsonPrimitive?.doubleOrNull ?: 0.0,
            savingsGoal = json["savingsGoal"]?.jsonPrimitive?.doubleOrNull ?: 0.0,
            message = json["message"]?.jsonPrimitive?.content.orEmpty(),
            computedAt = json["computedAt"]?.jsonPrimitive?.longOrNull ?: System.currentTimeMillis()
        )
    }
}