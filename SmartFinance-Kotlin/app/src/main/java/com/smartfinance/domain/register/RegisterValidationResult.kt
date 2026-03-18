package com.smartfinance.domain.register

data class RegisterValidationResult(
    val fullNameError: String? = null,
    val emailError: String? = null,
    val passwordError: String? = null,
    val confirmPasswordError: String? = null,
    val termsError: String? = null
) {
    val isValid: Boolean
        get() = fullNameError == null &&
            emailError == null &&
            passwordError == null &&
            confirmPasswordError == null &&
            termsError == null
}
