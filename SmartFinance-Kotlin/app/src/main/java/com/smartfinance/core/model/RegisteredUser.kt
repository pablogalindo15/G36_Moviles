package com.smartfinance.core.model

data class RegisteredUser(
    val userId: String,
    val fullName: String,
    val email: String,
    val requiresEmailConfirmation: Boolean
)
