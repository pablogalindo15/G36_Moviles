package com.smartfinance.domain.register

class RegisterApplicationService(
    private val facade: RegisterFacade
) {

    suspend fun registerUser(
        fullName: String,
        email: String,
        password: String,
        confirmPassword: String
    ): String {
        val cleanName = fullName.trim()
        val cleanEmail = email.trim()

        require(cleanName.isNotBlank()) { "Full name is required" }
        require(cleanEmail.isNotBlank()) { "Email is required" }
        require(password.isNotBlank()) { "Password is required" }
        require(password.length >= 6) { "Password must be at least 6 characters" }
        require(password == confirmPassword) { "Passwords do not match" }

        return facade.registerUser(
            RegisterUserRequest(
                fullName = cleanName,
                email = cleanEmail,
                password = password
            )
        )
    }
}