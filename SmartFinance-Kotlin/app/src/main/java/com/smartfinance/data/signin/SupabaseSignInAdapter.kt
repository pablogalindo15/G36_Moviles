package com.smartfinance.data.signin

import javax.inject.Inject

class SupabaseSignInAdapter @Inject constructor(
    private val remoteDataSource: SignInRemoteDataSource
) : SignInRepository {

    override suspend fun signIn(email: String, password: String): String {
        return remoteDataSource.signIn(email, password)
    }
}