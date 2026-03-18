package com.smartfinance.data.signin

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.providers.builtin.Email
import io.github.jan.supabase.gotrue.auth
import javax.inject.Inject

class SignInRemoteDataSource @Inject constructor(
    private val supabase: SupabaseClient
) {
    suspend fun signIn(email: String, password: String): String {
        val result = supabase.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }

        val user = supabase.auth.currentUserOrNull()
            ?: throw Exception("Invalid email or password")

        return user.id
    }
}