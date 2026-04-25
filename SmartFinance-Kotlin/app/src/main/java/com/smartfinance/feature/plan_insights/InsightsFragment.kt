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
import com.smartfinance.domain.onboarding.ExistingPlanVO
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import java.util.Locale

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
                            is UiState.Loading -> {
                                // opcional
                            }
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

            insightMessage.text = planDetails.contextualInsightMessage
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}