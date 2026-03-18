package com.smartfinance.domain.signin

import javax.inject.Inject

class SignInApplicationService @Inject constructor(
    private val facade: SignInFacade
) {
    suspend fun execute(dto: SignInDTO): SignInVO {
        require(dto.email.isNotBlank()) { "Email is required" }
        require(dto.password.isNotBlank()) { "Password is required" }

        val userId = facade.signIn(dto)
        return SignInVO(userId)
    }
}