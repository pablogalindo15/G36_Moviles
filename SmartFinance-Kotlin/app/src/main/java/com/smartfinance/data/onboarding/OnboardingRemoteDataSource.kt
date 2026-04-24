package com.smartfinance.data.onboarding

import com.smartfinance.core.model.FinancialSetup
import com.smartfinance.core.model.FinancialSetupResponse
import com.smartfinance.core.model.GeneratedPlan
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.json.Json

class OnboardingRemoteDataSource(
    private val supabaseClient: SupabaseClient
) {

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun insertFinancialSetup(setup: FinancialSetup): String {
        val response = supabaseClient.from("financial_setups")
            .insert(setup) { select() }
            .decodeSingle<FinancialSetupResponse>()
        return response.id
    }

    suspend fun generatePlan(plan: GeneratedPlan) {
        // Old method
    }

    suspend fun generateFirstPlan(request: GenerateFirstPlanRequest): GeneratedPlan {
        // Passing the request directly to invoke() allows Supabase-kt to handle serialization and headers automatically
        val response = supabaseClient.functions.invoke("generate-first-plan", request)
        val jsonString = response.bodyAsText()
        return json.decodeFromString<GenerateFirstPlanResponse>(jsonString).plan
    }

    suspend fun fetchFinancialSetup(userId: String): FinancialSetup? {
        return supabaseClient.from("financial_setups")
            .select { filter { eq("user_id", userId) } }
            .decodeSingleOrNull<FinancialSetup>()
    }

    suspend fun fetchGeneratedPlan(userId: String): GeneratedPlan? {
        return try {
            supabaseClient.from("generated_plans")
                .select {
                    filter { eq("user_id", userId) }
                    order("generated_at", order = Order.DESCENDING)
                    limit(1)
                }
                .decodeSingleOrNull<GeneratedPlan>()
        } catch (e: Exception) {
            null // Evita que la app se cierre si hay un error de red
        }
    }

}
