package com.smartfinance.data.signin

interface SignInRepository {
    suspend fun signIn(email: String, password: String): String
}