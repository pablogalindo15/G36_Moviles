package com.smartfinance.data.onboarding

import com.smartfinance.core.model.FinancialSetup
import com.smartfinance.core.model.FinancialSetupResponse
import com.smartfinance.core.model.GeneratedPlan
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from

class OnboardingRemoteDataSource(
    private val supabaseClient: SupabaseClient
) {

    suspend fun insertFinancialSetup(setup: FinancialSetup): String {
        val response = supabaseClient.from("financial_setups")
            .insert(setup) { select() }
            .decodeSingle<FinancialSetupResponse>()
        return response.id
    }

    suspend fun insertGeneratedPlan(plan: GeneratedPlan) {
        supabaseClient.from("generated_plans").insert(plan)
    }
}
