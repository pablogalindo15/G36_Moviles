package com.smartfinance.data.insights

import com.smartfinance.domain.insights.ComparativeInsightVO
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.json.Json

class ComparativeInsightRemoteDataSource(
    private val supabaseClient: SupabaseClient
) {

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun fetchWeeklyComparison(): ComparativeInsightVO {
        val response = supabaseClient.functions.invoke(
            FUNCTION_NAME,
            ComparativeInsightRequest()
        )
        val payload = json.decodeFromString<ComparativeInsightResponse>(response.bodyAsText())

        payload.error?.let { error ->
            throw IllegalStateException(payload.details?.let { "$error: $it" } ?: error)
        }

        if (payload.reason == COHORT_TOO_SMALL_REASON) {
            return ComparativeInsightVO.Unavailable(
                cohortSize = payload.cohortSize ?: 0,
                reason = payload.reason
            )
        }

        return ComparativeInsightVO.Available(
            myWeeklySpending = payload.myWeeklySpending
                ?: throw IllegalStateException("Missing my_weekly_spending"),
            cohortAverageWeeklySpending = payload.cohortAverageWeeklySpending
                ?: throw IllegalStateException("Missing cohort_avg_weekly_spending"),
            cohortSize = payload.cohortSize
                ?: throw IllegalStateException("Missing cohort_size"),
            percentile = payload.myPercentile
                ?: throw IllegalStateException("Missing my_percentile"),
            currency = payload.currency
                ?: throw IllegalStateException("Missing currency"),
            weekStart = payload.weekStart
                ?: throw IllegalStateException("Missing week_start"),
            weekEnd = payload.weekEnd
                ?: throw IllegalStateException("Missing week_end")
        )
    }

    private companion object {
        const val FUNCTION_NAME = "get-bq-comparative-spending"
        const val COHORT_TOO_SMALL_REASON = "cohort_too_small"
    }
}
