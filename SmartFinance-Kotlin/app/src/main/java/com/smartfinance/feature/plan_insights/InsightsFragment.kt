package com.smartfinance.feature.plan_insights

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.core.os.bundleOf
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.snackbar.Snackbar
import com.smartfinance.R
import com.smartfinance.core.location.LocationCountryResolver
import com.smartfinance.core.model.LocationContext
import com.smartfinance.core.model.UiState
import com.smartfinance.databinding.FragmentPlanInsightsBinding
import com.smartfinance.databinding.ItemTopCategoryBinding
import com.smartfinance.domain.insights.ComparativeInsightVO
import com.smartfinance.domain.onboarding.ExistingPlanVO
import com.smartfinance.domain.plan_insights.TopCategoriesResultVO
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
    private val fusedLocationClient by lazy {
        LocationServices.getFusedLocationProviderClient(requireActivity())
    }

    private var currentUserId: String? = null
    private var currentCurrency: String? = null
    private var smartFeatureDialogVisible = false

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
        currentUserId = userId

        if (userId != null) {
            viewModel.loadExistingPlan(userId)
            viewModel.loadSavingsProjection(false)
            viewModel.loadTopCategories(false)
            viewModel.loadComparativeInsight()
            viewModel.loadSmartFeatureContext()
            resolveSmartFeatureContextIfNeeded()
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
            viewModel.refreshInsights()
        }

        binding.btnExportJson.setOnClickListener {
            viewModel.exportInsightsToJson()
        }

        binding.fabAddExpense.setOnClickListener {
            val userId = currentUserId
            val currency = currentCurrency

            if (userId.isNullOrBlank() || currency.isNullOrBlank()) {
                Snackbar.make(binding.root, "Plan data is still loading.", Snackbar.LENGTH_SHORT)
                    .show()
                return@setOnClickListener
            }

            findNavController().navigate(
                R.id.action_insights_to_logExpense,
                bundleOf(
                    "userId" to userId,
                    "currency" to currency
                )
            )
        }
    }

    private fun observeViewModel() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {

                launch {
                    viewModel.existingPlanState.collect { state ->
                        when (state) {
                            is UiState.Loading -> Unit
                            is UiState.Success -> populateUI(state.data)
                            is UiState.Error -> {
                                Snackbar.make(binding.root, state.message, Snackbar.LENGTH_LONG)
                                    .show()
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
                                if (data.message.startsWith("Not enough data yet.")) {
                                    binding.tvSavingsProjectionValues.visibility = View.GONE
                                } else {
                                    binding.tvSavingsProjectionValues.visibility = View.VISIBLE
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
                            }

                            is UiState.Error -> {
                                binding.tvSavingsProjectionMessage.text =
                                    "Couldn't load savings projection."
                                binding.tvSavingsProjectionValues.visibility = View.GONE
                            }

                            else -> Unit
                        }
                    }
                }

                launch {
                    viewModel.topCategoriesState.collect { state ->
                        when (state) {
                            is UiState.Loading -> Unit
                            is UiState.Success -> populateTopCategories(state.data)
                            is UiState.Error -> {
                                binding.topCategoriesCard.visibility = View.GONE
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
                    viewModel.smartFeatureContextState.collect { state ->
                        renderSmartFeatureDialog(state)
                    }
                }

                launch {
                    viewModel.exportJsonEvent.collect { json ->
                        Log.d("InsightsFragment", "Exported JSON: $json")
                        copyToClipboard(json)
                        Snackbar.make(
                            binding.root,
                            "JSON exported to clipboard & logcat",
                            Snackbar.LENGTH_LONG
                        ).show()
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

        findNavController().currentBackStackEntry
            ?.savedStateHandle
            ?.getLiveData<Boolean>("expense_saved")
            ?.observe(viewLifecycleOwner) { wasSaved ->
                if (wasSaved == true) {
                    viewModel.refreshInsights()
                    findNavController().currentBackStackEntry
                        ?.savedStateHandle
                        ?.set("expense_saved", false)
                    Snackbar.make(binding.root, "Expense saved.", Snackbar.LENGTH_SHORT).show()
                }
            }
    }

    private fun copyToClipboard(text: String) {
        val clipboard = context?.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        val clip = ClipData.newPlainText("Insights JSON", text)
        clipboard?.setPrimaryClip(clip)
    }

    private fun populateTopCategories(result: TopCategoriesResultVO) {
        binding.topCategoriesContainer.removeAllViews()

        if (result.reason == "insufficient_data") {
            binding.topCategoriesCard.visibility = View.GONE
            return
        }

        binding.topCategoriesCard.visibility = View.VISIBLE

        result.topCategories.forEach { categoryVO ->
            val itemBinding = ItemTopCategoryBinding.inflate(
                LayoutInflater.from(context),
                binding.topCategoriesContainer,
                false
            )

            itemBinding.tvCategoryName.text = categoryVO.category
            val percentInt = (categoryVO.percentage * 100).roundToInt()
            itemBinding.pbCategoryPercentage.progress = percentInt
            itemBinding.tvCategoryPercentage.text = "$percentInt%"

            binding.topCategoriesContainer.addView(itemBinding.root)
        }

        binding.tvTopCategoriesFooter.text = getString(
            R.string.top_categories_footer,
            result.totalExpenses,
            result.periodDays
        )
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

    private fun renderSmartFeatureDialog(state: UiState<LocationContext>) {
        if (state !is UiState.Success || smartFeatureDialogVisible || !isAdded) return

        val message = state.data.inflationWarning
            ?: getString(
                R.string.smart_feature_safe_message,
                state.data.currency,
                state.data.inflationRate ?: 0.0
            )

        val dialog = MaterialAlertDialogBuilder(requireContext())
            .setTitle(getString(R.string.smart_feature_dialog_title, state.data.currency))
            .setMessage(message)
            .setPositiveButton(R.string.smart_feature_dialog_close) { dialogInterface, _ ->
                viewModel.dismissSmartFeaturePopup()
                dialogInterface.dismiss()
            }
            .setCancelable(false)
            .create()

        smartFeatureDialogVisible = true
        dialog.setOnDismissListener {
            smartFeatureDialogVisible = false
        }
        dialog.show()
    }

    private fun resolveSmartFeatureContextIfNeeded() {
        if (
            ContextCompat.checkSelfPermission(
                requireContext(),
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val tokenSource = CancellationTokenSource()
        try {
            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                tokenSource.token
            ).addOnSuccessListener { location ->
                if (location != null) {
                    viewLifecycleOwner.lifecycleScope.launch {
                        val countryCode = LocationCountryResolver.resolve(
                            context = requireContext(),
                            latitude = location.latitude,
                            longitude = location.longitude
                        )
                        viewModel.detectSmartFeatureContext(
                            latitude = location.latitude,
                            longitude = location.longitude,
                            countryCode = countryCode
                        )
                    }
                }
            }
        } catch (_: SecurityException) {
            // Non-blocking by design; the popup is skipped if location access fails here.
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
        currentCurrency = currency

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
