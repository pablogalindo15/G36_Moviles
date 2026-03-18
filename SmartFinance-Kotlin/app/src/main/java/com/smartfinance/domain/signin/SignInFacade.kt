package com.smartfinance.domain.signin

import com.smartfinance.data.signin.SignInRepository
import javax.inject.Inject

class SignInFacade @Inject constructor(
    private val repository: SignInRepository
) {
    suspend fun signIn(dto: SignInDTO): String {
        return repository.signIn(dto.email, dto.password)
    }
}