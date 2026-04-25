package com.smartfinance.feature.plan_insights

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import com.google.android.material.snackbar.Snackbar
import com.smartfinance.R
import com.smartfinance.core.model.UiState
import com.smartfinance.databinding.FragmentPlanInsightsBinding
import com.smartfinance.domain.insights.ComparativeInsightVO
import com.smartfinance.domain.onboarding.ExistingPlanVO
import dagger.hilt.android.AndroidEntryPoint
import java.util.Locale
import kotlin.math.max
import kotlin.math.roundToInt
import kotlinx.coroutines.launch

@AndroidEntryPoint
class InsightsFragment : Fragment() {

    private var _binding: FragmentPlanInsightsBinding? = null
    private val binding get() = _binding!!

    private val viewModel: InsightsViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentPlanInsightsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val userId = arguments?.getString("userId")

        if (userId != null) {
            viewModel.loadExistingPlan(userId)
            viewModel.loadSavingsProjection(false)
            viewModel.loadComparativeInsight()
        } else {
            Snackbar.make(binding.root, "Error: User ID not found", Snackbar.LENGTH_LONG).show()
        }

        setupListeners()
        observeViewModel()
    }

    private fun setupListeners() {
        binding.btnSignOut.setOnClickListener {
            viewModel.signOut()
        }

        binding.btnRefreshInsights.setOnClickListener {
            viewModel.refreshSavingsProjection()
        }
    }

    private fun observeViewModel() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {

                launch {
                    viewModel.existingPlanState.collect { state ->
                        when (state) {
                            is UiState.Loading -> Unit
                            is UiState.Success -> {
                                populateUI(state.data)
                            }
                            is UiState.Error -> {
                                Snackbar.make(binding.root, state.message, Snackbar.LENGTH_LONG).show()
                            }
                            else -> Unit
                        }
                    }
                }

                launch {
                    viewModel.savingsProjectionState.collect { state ->
                        when (state) {
                            is UiState.Loading -> {
                                binding.tvSavingsProjectionMessage.text =
                                    "Loading savings projection..."
                            }

                            is UiState.Success -> {
                                val data = state.data
                                binding.tvSavingsProjectionMessage.text = data.message
                                binding.tvSavingsProjectionValues.text =
                                    "Projected: ${
                                        String.format(
                                            Locale.US,
                                            "%.2f",
                                            data.projectedSavings
                                        )
                                    } | Goal: ${
                                        String.format(
                                            Locale.US,
                                            "%.2f",
                                            data.savingsGoal
                                        )
                                    }"
                            }

                            is UiState.Error -> {
                                binding.tvSavingsProjectionMessage.text =
                                    "Couldn't load savings projection."
                                Snackbar.make(
                                    binding.root,
                                    state.message,
                                    Snackbar.LENGTH_SHORT
                                ).show()
                            }

                            else -> Unit
                        }
                    }
                }

                launch {
                    viewModel.comparativeInsightState.collect { state ->
                        renderComparativeInsight(state)
                    }
                }

                launch {
                    viewModel.signOutState.collect { state ->
                        if (state is UiState.Success) {
                            findNavController().navigate(R.id.action_planResult_to_signIn)
                        } else if (state is UiState.Error) {
                            Snackbar.make(binding.root, state.message, Snackbar.LENGTH_SHORT).show()
                        }
                    }
                }
            }
        }
    }

    private fun renderComparativeInsight(state: UiState<ComparativeInsightVO>) {
        when (state) {
            is UiState.Idle -> {
                binding.comparisonLoadingText.visibility = View.GONE
                binding.comparisonUnavailableText.visibility = View.GONE
                binding.comparisonSubtitle.visibility = View.GONE
                binding.comparisonContent.visibility = View.GONE
            }
            is UiState.Loading -> {
                binding.comparisonLoadingText.visibility = View.VISIBLE
                binding.comparisonUnavailableText.visibility = View.GONE
                binding.comparisonSubtitle.visibility = View.GONE
                binding.comparisonContent.visibility = View.GONE
            }
            is UiState.Success -> {
                when (val insight = state.data) {
                    is ComparativeInsightVO.Available -> populateComparison(insight)
                    is ComparativeInsightVO.Unavailable -> showComparisonUnavailable(insight)
                }
            }
            is UiState.Error -> {
                binding.comparisonLoadingText.visibility = View.GONE
                binding.comparisonSubtitle.visibility = View.GONE
                binding.comparisonContent.visibility = View.GONE
                binding.comparisonUnavailableText.visibility = View.VISIBLE
                binding.comparisonUnavailableText.text = getString(R.string.comparison_error)
            }
        }
    }

    private fun populateComparison(insight: ComparativeInsightVO.Available) {
        val maxAmount = max(insight.myWeeklySpending, insight.cohortAverageWeeklySpending)
        val topPercent = ((1.0 - insight.percentile.coerceIn(0.0, 1.0)) * 100)
            .roundToInt()
            .coerceIn(1, 100)

        with(binding) {
            comparisonLoadingText.visibility = View.GONE
            comparisonUnavailableText.visibility = View.GONE
            comparisonSubtitle.visibility = View.VISIBLE
            comparisonContent.visibility = View.VISIBLE

            comparisonSubtitle.text = "You're in the top $topPercent% of spenders"
            comparisonUserAmount.text = formatComparisonMoney(
                insight.currency,
                insight.myWeeklySpending
            )
            comparisonCohortAmount.text = formatComparisonMoney(
                insight.currency,
                insight.cohortAverageWeeklySpending
            )
            comparisonUserProgress.progress = progressFor(insight.myWeeklySpending, maxAmount)
            comparisonCohortProgress.progress =
                progressFor(insight.cohortAverageWeeklySpending, maxAmount)
            comparisonFootnote.text =
                "Based on ${insight.cohortSize} users with similar income in ${insight.currency}"
        }
    }

    private fun showComparisonUnavailable(insight: ComparativeInsightVO.Unavailable) {
        binding.comparisonLoadingText.visibility = View.GONE
        binding.comparisonSubtitle.visibility = View.GONE
        binding.comparisonContent.visibility = View.GONE
        binding.comparisonUnavailableText.visibility = View.VISIBLE
        binding.comparisonUnavailableText.text =
            "Not enough similar users yet (${insight.cohortSize}/5)."
    }

    private fun formatComparisonMoney(currency: String, amount: Double): String {
        return String.format(Locale.US, "%s %.0f", currency, amount)
    }

    private fun progressFor(amount: Double, maxAmount: Double): Int {
        if (amount <= 0.0 || maxAmount <= 0.0) return 0
        return ((amount / maxAmount) * 100).roundToInt().coerceIn(2, 100)
    }

    private fun populateUI(existingPlan: ExistingPlanVO) {
        val planDetails = existingPlan.plan
        val currency = existingPlan.currency

        with(binding) {
            safeToSpendAmount.text =
                "$currency ${String.format(Locale.US, "%.2f", planDetails.proratedSafeToSpend)}"

            weeklyCapAmount.text =
                "$currency ${String.format(Locale.US, "%.2f", planDetails.weeklyCap)}"

            targetSavingsAmount.text =
                "$currency ${String.format(Locale.US, "%.2f", planDetails.monthlySavingsGoal)}"
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
