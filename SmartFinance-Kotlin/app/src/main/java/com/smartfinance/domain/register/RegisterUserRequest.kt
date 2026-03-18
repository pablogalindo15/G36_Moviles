package com.smartfinance.domain.register

data class RegisterUserRequest(
    val fullName: String,
    val email: String,
    val password: String
)