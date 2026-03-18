package com.smartfinance.feature.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.core.model.UiState
import com.smartfinance.domain.onboarding.OnboardingApplicationService
import com.smartfinance.domain.onboarding.PlanRequestDTO
import com.smartfinance.domain.onboarding.PlanVO
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val applicationService: OnboardingApplicationService
) : ViewModel() {

    private val _uiState = MutableStateFlow<UiState<PlanVO>>(UiState.Idle)
    val uiState: StateFlow<UiState<PlanVO>> = _uiState.asStateFlow()

    fun submitPlan(dto: PlanRequestDTO) {
        viewModelScope.launch {
            _uiState.value = UiState.Loading
            try {
                val plan = applicationService.setupPlan(dto)
                _uiState.value = UiState.Success(plan)
            } catch (e: Exception) {
                _uiState.value = UiState.Error(e.message ?: "An unexpected error occurred")
            }
        }
    }
}
