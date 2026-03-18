package com.smartfinance.feature.register

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.core.model.UiState
import com.smartfinance.domain.register.RegisterApplicationService
import com.smartfinance.domain.register.RegisterRequestDTO
import com.smartfinance.domain.register.RegisterResultVO
import com.smartfinance.domain.register.RegisterValidationResult
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

@HiltViewModel
class RegisterViewModel @Inject constructor(
    private val registerApplicationService: RegisterApplicationService
) : ViewModel() {

    private val _uiState = MutableStateFlow<UiState<RegisterResultVO>>(UiState.Idle)
    val uiState: StateFlow<UiState<RegisterResultVO>> = _uiState.asStateFlow()

    private val _validationState = MutableStateFlow(RegisterValidationResult())
    val validationState: StateFlow<RegisterValidationResult> = _validationState.asStateFlow()

    fun submitRegister(dto: RegisterRequestDTO) {
        val validation = validate(dto)
        _validationState.value = validation

        if (validation.isValid) {
            register(dto)
        }
    }

    private fun validate(dto: RegisterRequestDTO): RegisterValidationResult {
        return RegisterValidationResult(
            fullNameError = if (dto.fullName.isBlank()) "Full name is required" else null,
            emailError = if (dto.email.isBlank()) {
                "Email is required"
            } else if (!android.util.Patterns.EMAIL_ADDRESS.matcher(dto.email).matches()) {
                "Invalid email format"
            } else null,
            passwordError = if (dto.password.isBlank()) {
                "Password is required"
            } else if (dto.password.length < 6) {
                "Password must be at least 6 characters"
            } else null,
            confirmPasswordError = if (dto.confirmPassword != dto.password) "Passwords do not match" else null,
            termsError = if (!dto.acceptedTerms) "You must accept the terms and conditions" else null
        )
    }

    private fun register(dto: RegisterRequestDTO) {
        viewModelScope.launch {
            _uiState.value = UiState.Loading
            try {
                val userId = registerApplicationService.registerUser(
                    fullName = dto.fullName,
                    email = dto.email,
                    password = dto.password,
                    confirmPassword = dto.confirmPassword
                )
                _uiState.value = UiState.Success(
                    RegisterResultVO(
                        userId = userId,
                        fullName = dto.fullName,
                        email = dto.email,
                        requiresEmailConfirmation = false,
                        message = "Account created successfully"
                    )
                )
            } catch (e: Exception) {
                _uiState.value = UiState.Error(
                    e.message ?: "An unexpected error occurred"
                )
            }
        }
    }

    fun resetUiState() {
        _uiState.value = UiState.Idle
    }
}
