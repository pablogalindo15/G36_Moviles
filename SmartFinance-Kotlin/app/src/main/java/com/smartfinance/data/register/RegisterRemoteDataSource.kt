package com.smartfinance.data.register

import com.smartfinance.core.model.Profile
import com.smartfinance.domain.register.RegisterUserRequest
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.gotrue.providers.builtin.Email
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class RegisterRemoteDataSource(
    private val supabaseClient: SupabaseClient
) {

    suspend fun registerUser(request: RegisterUserRequest): String {
        val signedUpUser = supabaseClient.auth.signUpWith(Email) {
            email = request.email.trim()
            password = request.password
            data = buildJsonObject {
                put("full_name", request.fullName.trim())
            }
        }

        val userId = signedUpUser?.id
            ?: supabaseClient.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("No se pudo obtener el userId del usuario registrado")

        supabaseClient.from("profiles").insert(
            Profile(
                id = userId,
                fullName = request.fullName.trim(),
                avatarUrl = null
            )
        )

        return userId
    }
}
