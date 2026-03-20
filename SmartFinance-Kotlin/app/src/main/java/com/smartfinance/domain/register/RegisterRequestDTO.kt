package com.smartfinance.domain.register

data class RegisterRequestDTO(
    val fullName: String,
    val email: String,
    val password: String,
    val confirmPassword: String,
    val acceptedTerms: Boolean,
    val profileImage: ByteArray? = null
)
