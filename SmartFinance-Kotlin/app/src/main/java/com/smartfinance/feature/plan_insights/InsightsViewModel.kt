package com.smartfinance.feature.plan_insights

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.core.model.LocationContext
import com.smartfinance.core.model.UiState
import com.smartfinance.domain.insights.ComparativeInsightApplicationService
import com.smartfinance.domain.insights.ComparativeInsightVO
import com.smartfinance.domain.location_context.LocationContextApplicationService
import com.smartfinance.domain.onboarding.ExistingPlanVO
import com.smartfinance.domain.onboarding.OnboardingApplicationService
import com.smartfinance.domain.plan_insights.ComparativeInsightExport
import com.smartfinance.domain.plan_insights.ExportInsightsVO
import com.smartfinance.domain.plan_insights.PlanInsightsApplicationService
import com.smartfinance.domain.plan_insights.SavingsProjectionExport
import com.smartfinance.domain.plan_insights.SavingsProjectionVO
import com.smartfinance.domain.plan_insights.TopCategoriesResultVO
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject

@HiltViewModel
class InsightsViewModel @Inject constructor(
    private val applicationService: OnboardingApplicationService,
    private val planInsightsApplicationService: PlanInsightsApplicationService,
    private val comparativeInsightApplicationService: ComparativeInsightApplicationService,
    private val locationContextApplicationService: LocationContextApplicationService,
    private val supabase: SupabaseClient
) : ViewModel() {

    private val _existingPlanState = MutableStateFlow<UiState<ExistingPlanVO>>(UiState.Idle)
    val existingPlanState: StateFlow<UiState<ExistingPlanVO>> = _existingPlanState.asStateFlow()

    private val _savingsProjectionState =
        MutableStateFlow<UiState<SavingsProjectionVO>>(UiState.Idle)
    val savingsProjectionState: StateFlow<UiState<SavingsProjectionVO>> =
        _savingsProjectionState.asStateFlow()

    private val _topCategoriesState =
        MutableStateFlow<UiState<TopCategoriesResultVO>>(UiState.Idle)
    val topCategoriesState: StateFlow<UiState<TopCategoriesResultVO>> =
        _topCategoriesState.asStateFlow()

    private val _comparativeInsightState =
        MutableStateFlow<UiState<ComparativeInsightVO>>(UiState.Idle)
    val comparativeInsightState: StateFlow<UiState<ComparativeInsightVO>> =
        _comparativeInsightState.asStateFlow()

    private val _smartFeatureContextState =
        MutableStateFlow<UiState<LocationContext>>(UiState.Idle)
    val smartFeatureContextState: StateFlow<UiState<LocationContext>> =
        _smartFeatureContextState.asStateFlow()

    private val _signOutState = MutableStateFlow<UiState<Unit>>(UiState.Idle)
    val signOutState: StateFlow<UiState<Unit>> = _signOutState.asStateFlow()

    private val _exportJsonEvent = MutableSharedFlow<String>()
    val exportJsonEvent: SharedFlow<String> = _exportJsonEvent.asSharedFlow()

    fun loadExistingPlan(userId: String) {
        viewModelScope.launch {
            _existingPlanState.value = UiState.Loading
            try {
                val existing = applicationService.fetchExistingPlan(userId)
                _existingPlanState.value = if (existing != null) {
                    UiState.Success(existing)
                } else {
                    UiState.Idle
                }
            } catch (e: Exception) {
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
                _savingsProjectionState.value =
                    UiState.Error("Couldn't load savings projection.")
            }
        }
    }

    fun loadTopCategories(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _topCategoriesState.value = UiState.Loading
            try {
                val result = planInsightsApplicationService.getTopCategories(forceRefresh)
                _topCategoriesState.value = UiState.Success(result)
            } catch (e: Exception) {
                _topCategoriesState.value =
                    UiState.Error("Couldn't load top categories.")
            }
        }
    }

    fun refreshInsights() {
        loadSavingsProjection(forceRefresh = true)
        loadTopCategories(forceRefresh = true)
        loadComparativeInsight(forceRefresh = true)
    }

    fun loadComparativeInsight(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _comparativeInsightState.value = UiState.Loading
            try {
                _comparativeInsightState.value = UiState.Success(
                    comparativeInsightApplicationService.fetchWeeklyComparison(forceRefresh)
                )
            } catch (e: Exception) {
                _comparativeInsightState.value =
                    UiState.Error("Couldn't load spending comparison.")
            }
        }
    }

    fun exportInsightsToJson() {
        viewModelScope.launch {
            // Processing in IO Dispatcher as requested
            val jsonString = withContext(Dispatchers.IO) {
                val savings = (savingsProjectionState.value as? UiState.Success)?.data
                val categories = (topCategoriesState.value as? UiState.Success)?.data
                val comparative = (comparativeInsightState.value as? UiState.Success)?.data

                val exportData = ExportInsightsVO(
                    savingsProjection = savings?.let {
                        SavingsProjectionExport(it.isOnTrack, it.projectedSavings, it.savingsGoal, it.message)
                    },
                    topCategories = categories,
                    comparativeInsight = comparative?.let {
                        when (it) {
                            is ComparativeInsightVO.Available -> ComparativeInsightExport(
                                type = "available",
                                myWeeklySpending = it.myWeeklySpending,
                                cohortAverageWeeklySpending = it.cohortAverageWeeklySpending,
                                percentile = it.percentile,
                                cohortSize = it.cohortSize,
                                currency = it.currency
                            )
                            is ComparativeInsightVO.Unavailable -> ComparativeInsightExport(
                                type = "unavailable",
                                cohortSize = it.cohortSize
                            )
                        }
                    }
                )

                val jsonConfig = Json { prettyPrint = true }
                jsonConfig.encodeToString(exportData)
            }
            _exportJsonEvent.emit(jsonString)
        }
    }

    fun loadSmartFeatureContext() {
        viewModelScope.launch {
            try {
                if (!locationContextApplicationService.shouldShowSmartFeaturePopup()) {
                    _smartFeatureContextState.value = UiState.Idle
                    return@launch
                }

                val cachedContext = locationContextApplicationService.getCachedContext()
                if (cachedContext == null || (
                        cachedContext.inflationWarning.isNullOrBlank() &&
                            cachedContext.inflationRate == null
                        )
                ) {
                    _smartFeatureContextState.value = UiState.Idle
                    return@launch
                }

                _smartFeatureContextState.value = UiState.Success(cachedContext)
            } catch (e: Exception) {
                Log.e("InsightsViewModel", "Failed to load smart feature context", e)
                _smartFeatureContextState.value = UiState.Idle
            }
        }
    }

    fun detectSmartFeatureContext(
        latitude: Double,
        longitude: Double,
        countryCode: String? = null
    ) {
        viewModelScope.launch {
            try {
                if (!locationContextApplicationService.shouldShowSmartFeaturePopup()) {
                    return@launch
                }

                if (locationContextApplicationService.getCachedContext() != null) {
                    return@launch
                }

                val detectedContext = locationContextApplicationService.detectAndCache(
                    latitude = latitude,
                    longitude = longitude,
                    countryCode = countryCode
                )
                if (detectedContext.inflationWarning.isNullOrBlank() &&
                    detectedContext.inflationRate == null
                ) {
                    _smartFeatureContextState.value = UiState.Idle
                    return@launch
                }

                _smartFeatureContextState.value = UiState.Success(detectedContext)
            } catch (e: Exception) {
                Log.e("InsightsViewModel", "Failed to detect smart feature context", e)
            }
        }
    }

    fun dismissSmartFeaturePopup() {
        viewModelScope.launch {
            locationContextApplicationService.markSmartFeaturePopupShown()
            _smartFeatureContextState.value = UiState.Idle
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
