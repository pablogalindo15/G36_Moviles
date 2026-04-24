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

        // 1. Obtener el userId de los argumentos (pasado desde SignIn o Onboarding)
        val userId = arguments?.getString("userId")

        if (userId != null) {
            viewModel.loadExistingPlan(userId)
        } else {
            Snackbar.make(binding.root, "Error: User ID not found", Snackbar.LENGTH_LONG).show()
        }

        setupListeners()
        observeViewModel()
    }

    private fun setupListeners() {
        // Ejemplo: Si quieres que al tocar el título se cierre sesión
        binding.tvMainTitle.setOnClickListener {
            viewModel.signOut()
        }
    }

    private fun observeViewModel() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {

                // Observar el estado del plan existente
                launch {
                    viewModel.existingPlanState.collect { state ->
                        when (state) {
                            is UiState.Loading -> {
                                // Puedes añadir un ProgressBar en tu XML si gustas
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

                // Observar el estado del Sign Out
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
        // 1. Accedemos al objeto plan contenido en el ExistingPlanVO
        val planDetails = existingPlan.plan

        // 2. Usamos la moneda definida en el nivel superior o en el plan
        val currency = existingPlan.currency

        with(binding) {
            // Safe to Spend (Prorrateado)
            safeToSpendAmount.text = "$currency ${String.format("%.2f", planDetails.proratedSafeToSpend)}"

            // Weekly Cap (Límite semanal)
            weeklyCapAmount.text = "$currency ${String.format("%.2f", planDetails.weeklyCap)}"

            // Target Savings (Meta de ahorro)
            // Nota: Ambos objetos lo tienen, usamos el del plan por consistencia
            targetSavingsAmount.text = "$currency ${String.format("%.2f", planDetails.monthlySavingsGoal)}"

            // Mensaje de Insight
            insightMessage.text = planDetails.contextualInsightMessage
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}