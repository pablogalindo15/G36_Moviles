package com.smartfinance.data.register

import com.smartfinance.domain.register.RegisterUserRequest

class SupabaseRegisterAdapter(
    private val remoteDataSource: RegisterRemoteDataSource
) : RegisterRepository {

    override suspend fun registerUser(request: RegisterUserRequest): String {
        return remoteDataSource.registerUser(request)
    }
}
