package com.smartfinance.feature.plan_insights

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.core.model.UiState
import com.smartfinance.domain.insights.ComparativeInsightApplicationService
import com.smartfinance.domain.insights.ComparativeInsightVO
import com.smartfinance.domain.onboarding.ExistingPlanVO
import com.smartfinance.domain.onboarding.OnboardingApplicationService
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
    private val comparativeInsightApplicationService: ComparativeInsightApplicationService,
    private val supabase: SupabaseClient
) : ViewModel() {

    private val _existingPlanState = MutableStateFlow<UiState<ExistingPlanVO>>(UiState.Idle)
    val existingPlanState: StateFlow<UiState<ExistingPlanVO>> = _existingPlanState.asStateFlow()

    private val _comparativeInsightState =
        MutableStateFlow<UiState<ComparativeInsightVO>>(UiState.Idle)
    val comparativeInsightState: StateFlow<UiState<ComparativeInsightVO>> =
        _comparativeInsightState.asStateFlow()

    fun loadExistingPlan(userId: String) {
        viewModelScope.launch {
            Log.d("OnboardingVM", "loadExistingPlan userId=$userId")
            _existingPlanState.value = UiState.Loading
            try {
                val existing = applicationService.fetchExistingPlan(userId)
                Log.d("OnboardingVM", "fetchExistingPlan result=$existing")
                _existingPlanState.value = if (existing != null) {
                    UiState.Success(existing)
                } else {
                    UiState.Idle
                }
            } catch (e: Exception) {
                Log.e("OnboardingVM", "fetchExistingPlan error", e)
                _existingPlanState.value = UiState.Error(e.message ?: "An unexpected error occurred")
            }
        }
    }

    fun loadComparativeInsight() {
        viewModelScope.launch {
            _comparativeInsightState.value = UiState.Loading
            try {
                _comparativeInsightState.value = UiState.Success(
                    comparativeInsightApplicationService.fetchWeeklyComparison()
                )
            } catch (e: Exception) {
                Log.e("InsightsViewModel", "Failed to load comparative insight", e)
                _comparativeInsightState.value =
                    UiState.Error("Couldn't load spending comparison.")
            }
        }
    }

    private val _signOutState = MutableStateFlow<UiState<Unit>>(UiState.Idle)
    val signOutState: StateFlow<UiState<Unit>> = _signOutState.asStateFlow()

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
