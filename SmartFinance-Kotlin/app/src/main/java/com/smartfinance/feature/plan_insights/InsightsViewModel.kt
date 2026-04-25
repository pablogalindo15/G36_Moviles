package com.smartfinance.feature.plan_insights

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.core.model.UiState
import com.smartfinance.domain.onboarding.ExistingPlanVO
import com.smartfinance.domain.onboarding.OnboardingApplicationService
import com.smartfinance.domain.onboarding.PlanVO
import com.smartfinance.domain.plan_insights.PlanInsightsApplicationService
import com.smartfinance.domain.plan_insights.SavingsProjectionVO
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class InsightsViewModel @Inject constructor(
    private val applicationService: OnboardingApplicationService,
    private val planInsightsApplicationService: PlanInsightsApplicationService,
    private val supabase: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow<UiState<PlanVO>>(UiState.Idle)
    val uiState: StateFlow<UiState<PlanVO>> = _uiState.asStateFlow()

    private val _existingPlanState = MutableStateFlow<UiState<ExistingPlanVO>>(UiState.Idle)
    val existingPlanState: StateFlow<UiState<ExistingPlanVO>> = _existingPlanState.asStateFlow()

    private val _savingsProjectionState =
        MutableStateFlow<UiState<SavingsProjectionVO>>(UiState.Idle)
    val savingsProjectionState: StateFlow<UiState<SavingsProjectionVO>> =
        _savingsProjectionState.asStateFlow()

    private val _signOutState = MutableStateFlow<UiState<Unit>>(UiState.Idle)
    val signOutState: StateFlow<UiState<Unit>> = _signOutState.asStateFlow()

    fun loadExistingPlan(userId: String) {
        viewModelScope.launch {
            Log.d("InsightsVM", "loadExistingPlan userId=$userId")
            _existingPlanState.value = UiState.Loading
            try {
                val existing = applicationService.fetchExistingPlan(userId)
                Log.d("InsightsVM", "fetchExistingPlan result=$existing")
                _existingPlanState.value = if (existing != null) {
                    UiState.Success(existing)
                } else {
                    UiState.Idle
                }
            } catch (e: Exception) {
                Log.e("InsightsVM", "fetchExistingPlan error", e)
                _existingPlanState.value =
                    UiState.Error(e.message ?: "An unexpected error occurred")
            }
        }
    }

    fun loadSavingsProjection(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _savingsProjectionState.value = UiState.Loading
            try {
                val result = planInsightsApplicationService.getSavingsProjection(forceRefresh)
                _savingsProjectionState.value = UiState.Success(result)
            } catch (e: Exception) {
                Log.e("InsightsVM", "loadSavingsProjection error", e)
                _savingsProjectionState.value =
                    UiState.Error(e.message ?: "Could not load savings projection")
            }
        }
    }

    fun refreshSavingsProjection() {
        loadSavingsProjection(forceRefresh = true)
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