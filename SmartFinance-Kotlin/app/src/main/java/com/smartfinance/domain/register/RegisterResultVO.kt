package com.smartfinance.domain.register

data class RegisterResultVO(
    val userId: String,
    val fullName: String,
    val email: String,
    val requiresEmailConfirmation: Boolean,
    val message: String
)
