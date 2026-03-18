package com.smartfinance.data.register

import com.smartfinance.domain.register.RegisterUserRequest

interface RegisterRepository {
    suspend fun registerUser(request: RegisterUserRequest): String
}
