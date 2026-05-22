package com.smartfinance.feature.spending_insights

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.smartfinance.data.insights.SpendingInsightsRemoteDataSource
import com.smartfinance.data.insights.TopSpendingCategoryRecord
import com.smartfinance.domain.onboarding.OnboardingApplicationService
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import java.util.Locale
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@HiltViewModel
class SpendingInsightsViewModel @Inject constructor(
    private val remoteDataSource: SpendingInsightsRemoteDataSource,
    private val onboardingService: OnboardingApplicationService,
    private val supabase: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(SpendingInsightsUiState())
    val uiState: StateFlow<SpendingInsightsUiState> = _uiState.asStateFlow()

    fun loadInsights() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                errorMessage = null
            )

            try {
                val userId = supabase.auth.currentUserOrNull()?.id
                    ?: throw IllegalStateException("User not authenticated")

                val insights = withContext(Dispatchers.IO) {
                    val response = remoteDataSource.getTopSpendingCategories()
                    val existingPlan = onboardingService.fetchExistingPlan(userId)
                    val userCurrency = existingPlan?.currency ?: "USD"

                    buildUiModels(response.topCategories, userCurrency)
                }

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    topCategories = insights
                )
            } catch (exception: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = exception.message ?: "Could not load insights."
                )
            }
        }
    }

    private fun buildUiModels(
        categories: List<TopSpendingCategoryRecord>,
        currency: String
    ): List<CategoryInsightUiModel> {
        return categories
            .sortedByDescending { item -> item.total }
            .map { item ->
                CategoryInsightUiModel(
                    category = item.category,
                    amountText = "$currency ${String.format(Locale.US, "%,.0f", item.total)}",
                    percentage = (item.percentage * 100).toInt().coerceIn(1, 100),
                    icon = getIconForCategory(item.category)
                )
            }
    }

    private fun getIconForCategory(category: String): String {
        return when (category.lowercase()) {
            "transport", "transportation", "taxi", "uber" -> "🚗"
            "food", "restaurant", "groceries" -> "🍽️"
            "shopping" -> "🛍️"
            "health" -> "🩺"
            "entertainment" -> "🎬"
            "education" -> "🎓"
            "housing" -> "🏠"
            "utilities" -> "💡"
            "bills" -> "💸"
            else -> "💸"
        }
    }
}
