package com.smartfinance.domain.register

import com.smartfinance.data.register.RegisterRepository

class RegisterFacade(
    private val repository: RegisterRepository
) {
    suspend fun registerUser(request: RegisterUserRequest): String {
        return repository.registerUser(request)
    }
}