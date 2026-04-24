package com.smartfinance.data.onboarding

import com.smartfinance.core.model.FinancialSetup
import com.smartfinance.core.model.FinancialSetupResponse
import com.smartfinance.core.model.GeneratedPlan
import com.smartfinance.domain.onboarding.PlanRequestDTO
import com.smartfinance.domain.onboarding.PlanVO
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.query.Order
import io.ktor.client.request.setBody

class OnboardingRemoteDataSource(
    private val supabaseClient: SupabaseClient
) {

    suspend fun insertFinancialSetup(setup: FinancialSetup): String {
        val response = supabaseClient.from("financial_setups")
            .insert(setup) { select() }
            .decodeSingle<FinancialSetupResponse>()
        return response.id
    }

    suspend fun generatePlan(plan: GeneratedPlan) {
        val response = supabaseClient.functions.invoke("generate-first-plan") {
            setBody(plan)
        }
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
