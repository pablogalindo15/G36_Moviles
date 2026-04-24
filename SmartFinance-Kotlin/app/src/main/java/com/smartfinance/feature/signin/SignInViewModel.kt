package com.smartfinance.feature.signin

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.core.model.UiState
import com.smartfinance.domain.onboarding.ExistingPlanVO
import com.smartfinance.domain.onboarding.OnboardingApplicationService
import com.smartfinance.domain.onboarding.PlanVO
import com.smartfinance.domain.signin.SignInApplicationService
import com.smartfinance.domain.signin.SignInDTO
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SignInViewModel @Inject constructor(
    private val applicationService: SignInApplicationService,
    private val onboardingApplicationService: OnboardingApplicationService
) : ViewModel() {

    private val _uiState = MutableStateFlow<UiState<String>>(UiState.Idle)
    val uiState: StateFlow<UiState<String>> = _uiState

    fun signIn(email: String, password: String) {
        viewModelScope.launch {
            _uiState.value = UiState.Loading
            try {
                val result = applicationService.execute(SignInDTO(email, password))
                _uiState.value = UiState.Success(result.userId)
            } catch (e: Exception) {
                _uiState.value = UiState.Error("Usuario o contraseña incorrectos")
            }
        }
    }

    suspend fun checkExistingPlan(userId: String): ExistingPlanVO? {
        return try {
            onboardingApplicationService.fetchExistingPlan(userId)
        } catch (e: Exception) {
            null
        }
    }
}