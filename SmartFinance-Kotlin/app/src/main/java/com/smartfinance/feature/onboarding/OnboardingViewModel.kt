package com.smartfinance.feature.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.core.model.LocationContext
import com.smartfinance.core.model.UiState
import com.smartfinance.domain.location_context.LocationContextApplicationService
import com.smartfinance.domain.onboarding.ExistingPlanVO
import com.smartfinance.domain.onboarding.OnboardingApplicationService
import com.smartfinance.domain.onboarding.PlanRequestDTO
import com.smartfinance.domain.onboarding.PlanVO
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val applicationService: OnboardingApplicationService,
    private val locationContextApplicationService: LocationContextApplicationService,
    private val supabase: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow<UiState<PlanVO>>(UiState.Idle)
    val uiState: StateFlow<UiState<PlanVO>> = _uiState.asStateFlow()

    private val _existingPlanState = MutableStateFlow<UiState<ExistingPlanVO>>(UiState.Idle)
    val existingPlanState: StateFlow<UiState<ExistingPlanVO>> = _existingPlanState.asStateFlow()

    private val _locationContextState =
        MutableStateFlow<UiState<LocationContext>>(UiState.Idle)
    val locationContextState: StateFlow<UiState<LocationContext>> =
        _locationContextState.asStateFlow()

    private val _signOutState = MutableStateFlow<UiState<Unit>>(UiState.Idle)
    val signOutState: StateFlow<UiState<Unit>> = _signOutState.asStateFlow()

    fun loadExistingPlan(userId: String) {
        viewModelScope.launch {
            _existingPlanState.value = UiState.Loading
            try {
                val existing = applicationService.fetchExistingPlan(userId)
                if (existing != null) {
                    _existingPlanState.value = UiState.Success(existing)
                } else {
                    _existingPlanState.value = UiState.Idle
                }
            } catch (e: Exception) {
                _existingPlanState.value = UiState.Error(e.message ?: "Error loading plan")
            }
        }
    }

    fun submitPlan(dto: PlanRequestDTO) {
        viewModelScope.launch {
            _uiState.value = UiState.Loading
            try {
                val plan = applicationService.setupPlan(dto)
                _uiState.value = UiState.Success(plan)
            } catch (e: Exception) {
                _uiState.value = UiState.Error(e.message ?: "Error creating plan")
            }
        }
    }

    fun detectLocationContext(
        latitude: Double,
        longitude: Double,
        countryCode: String? = null
    ) {
        viewModelScope.launch {
            _locationContextState.value = UiState.Loading
            try {
                _locationContextState.value = UiState.Success(
                    locationContextApplicationService.detectAndCache(
                        latitude = latitude,
                        longitude = longitude,
                        countryCode = countryCode
                    )
                )
            } catch (e: Exception) {
                _locationContextState.value =
                    UiState.Error(e.message ?: "Couldn't detect local currency")
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            _signOutState.value = UiState.Loading
            try {
                supabase.auth.signOut()
                _signOutState.value = UiState.Success(Unit)
            } catch (e: Exception) {
                _signOutState.value = UiState.Error(e.message ?: "Sign out failed")
            }
        }
    }
}
