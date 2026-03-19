package com.smartfinance.feature.onboarding

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.navigation.fragment.findNavController
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.material.datepicker.MaterialDatePicker
import com.google.android.material.snackbar.Snackbar
import com.smartfinance.R
import com.smartfinance.core.model.UiState
import com.smartfinance.databinding.FragmentOnboardingBinding
import com.smartfinance.domain.onboarding.ExistingPlanVO
import com.smartfinance.domain.onboarding.PlanRequestDTO
import com.smartfinance.domain.onboarding.PlanVO
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.time.format.DateTimeFormatter

@AndroidEntryPoint
class OnboardingFragment : Fragment() {

    private var _binding: FragmentOnboardingBinding? = null
    private val binding get() = _binding!!

    private val viewModel: OnboardingViewModel by viewModels()

    private var selectedPayday: LocalDate? = null

    private val currencies = listOf("USD", "EUR", "GBP", "MXN", "COP", "ARS", "BRL", "CLP", "PEN", "CAD")

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentOnboardingBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupCurrencySpinner()
        setupDatePicker()
        setupGenerateButton()
        setupSignOutButton()
        observeUiState()
        observeExistingPlan()
        observeSignOut()
        val userId = arguments?.getString("userId") ?: return
        viewModel.loadExistingPlan(userId)
    }

    private fun setupSignOutButton() {
        binding.btnSignOut.setOnClickListener {
            viewModel.signOut()
        }
    }

    private fun observeSignOut() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.signOutState.collect { state ->
                    when (state) {
                        is UiState.Success -> {
                            findNavController().navigate(R.id.action_onboarding_to_signIn)
                        }
                        is UiState.Error -> {
                            Snackbar.make(binding.root, state.message, Snackbar.LENGTH_LONG).show()
                        }
                        else -> Unit
                    }
                }
            }
        }
    }

    private fun setupCurrencySpinner() {
        val adapter = ArrayAdapter(
            requireContext(),
            android.R.layout.simple_dropdown_item_1line,
            currencies
        )
        binding.currencyDropdown.setAdapter(adapter)
        binding.currencyDropdown.setText(currencies[0], false)
    }

    private fun setupDatePicker() {
        binding.nextPaydayInput.setOnClickListener {
            val picker = MaterialDatePicker.Builder.datePicker()
                .setTitleText("Select next payday")
                .setSelection(MaterialDatePicker.todayInUtcMilliseconds())
                .build()

            picker.addOnPositiveButtonClickListener { millis ->
                selectedPayday = Instant.ofEpochMilli(millis)
                    .atZone(ZoneId.of("UTC"))
                    .toLocalDate()
                binding.nextPaydayInput.setText(
                    selectedPayday!!.format(DateTimeFormatter.ofPattern("MMM dd, yyyy"))
                )
            }

            picker.show(parentFragmentManager, "DATE_PICKER")
        }
    }

    private fun setupGenerateButton() {
        binding.btnGenerate.setOnClickListener {
            if (!validateForm()) return@setOnClickListener

            val userId = requireArguments().getString("userId")
                ?: error("userId is required")

            val dto = PlanRequestDTO(
                userId = userId,
                currency = binding.currencyDropdown.text.toString(),
                monthlyIncome = binding.monthlyIncomeInput.text.toString().toDouble(),
                fixedMonthlyExpenses = binding.fixedExpensesInput.text.toString().toDouble(),
                monthlySavingsGoal = binding.savingsGoalInput.text.toString().toDouble(),
                nextPayday = selectedPayday!!
            )
            viewModel.submitPlan(dto)
        }
    }

    private fun validateForm(): Boolean {
        var isValid = true

        val incomeText = binding.monthlyIncomeInput.text.toString()
        val income = incomeText.toDoubleOrNull()
        when {
            incomeText.isBlank() -> {
                binding.monthlyIncomeLayout.error = "Required"
                isValid = false
            }
            income == null -> {
                binding.monthlyIncomeLayout.error = "Enter a valid number"
                isValid = false
            }
            income <= 0 -> {
                binding.monthlyIncomeLayout.error = "Income must be greater than zero"
                isValid = false
            }
            else -> binding.monthlyIncomeLayout.error = null
        }

        val expensesText = binding.fixedExpensesInput.text.toString()
        val expenses = expensesText.toDoubleOrNull()
        when {
            expensesText.isBlank() -> {
                binding.fixedExpensesLayout.error = "Required"
                isValid = false
            }
            expenses == null -> {
                binding.fixedExpensesLayout.error = "Enter a valid number"
                isValid = false
            }
            expenses < 0 -> {
                binding.fixedExpensesLayout.error = "Expenses cannot be negative"
                isValid = false
            }
            income != null && income > 0 && expenses >= income -> {
                binding.fixedExpensesLayout.error = "Expenses must be less than income"
                isValid = false
            }
            else -> binding.fixedExpensesLayout.error = null
        }

        val savingsText = binding.savingsGoalInput.text.toString()
        val savings = savingsText.toDoubleOrNull()
        when {
            savingsText.isBlank() -> {
                binding.savingsGoalLayout.error = "Required"
                isValid = false
            }
            savings == null -> {
                binding.savingsGoalLayout.error = "Enter a valid number"
                isValid = false
            }
            savings < 0 -> {
                binding.savingsGoalLayout.error = "Savings goal cannot be negative"
                isValid = false
            }
            income != null && income > 0 && savings >= income -> {
                binding.savingsGoalLayout.error = "Savings goal must be less than income"
                isValid = false
            }
            else -> binding.savingsGoalLayout.error = null
        }

        if (isValid && income != null && expenses != null && savings != null) {
            val remaining = income - expenses - savings
            if (remaining <= 0) {
                binding.savingsGoalLayout.error =
                    "Expenses + savings (\$${String.format("%.2f", expenses + savings)}) exceed your income"
                isValid = false
            }
        }

        when {
            selectedPayday == null -> {
                binding.nextPaydayLayout.error = "Select a date"
                isValid = false
            }
            !selectedPayday!!.isAfter(LocalDate.now()) -> {
                binding.nextPaydayLayout.error = "Payday must be a future date"
                isValid = false
            }
            ChronoUnit.DAYS.between(LocalDate.now(), selectedPayday) > 365 -> {
                binding.nextPaydayLayout.error = "Payday must be within the next year"
                isValid = false
            }
            else -> binding.nextPaydayLayout.error = null
        }

        return isValid
    }

    private fun observeUiState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    when (state) {
                        is UiState.Idle -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.resultSection.visibility = View.GONE
                        }
                        is UiState.Loading -> {
                            binding.progressIndicator.visibility = View.VISIBLE
                            binding.resultSection.visibility = View.GONE
                            binding.btnGenerate.isEnabled = false
                        }
                        is UiState.Success -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.btnGenerate.isEnabled = true
                            showResult(state.data)
                        }
                        is UiState.Error -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.btnGenerate.isEnabled = true
                            Snackbar.make(binding.root, state.message, Snackbar.LENGTH_LONG).show()
                        }
                    }
                }
            }
        }
    }

    private fun showResult(plan: PlanVO) {
        binding.resultSection.visibility = View.VISIBLE

        fun formatAmount(amount: Double) =
            "${plan.currency} ${"%.2f".format(amount)}"

        binding.safeToSpendAmount.text = formatAmount(plan.proratedSafeToSpend)
        binding.weeklyCapAmount.text = formatAmount(plan.weeklyCap)
        binding.targetSavingsAmount.text = formatAmount(plan.monthlySavingsGoal)

        binding.insightMessage.text = plan.contextualInsightMessage
        binding.proratedBanner.visibility = if (plan.isProrated) View.VISIBLE else View.GONE
    }

    private fun observeExistingPlan() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.existingPlanState.collect { state ->
                    when (state) {
                        is UiState.Idle -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.btnGenerate.visibility = View.VISIBLE
                        }
                        is UiState.Loading -> {
                            binding.progressIndicator.visibility = View.VISIBLE
                            binding.btnGenerate.visibility = View.GONE
                        }
                        is UiState.Success -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.btnGenerate.visibility = View.GONE
                            prefillForm(state.data)
                            disableForm()
                            showResult(state.data.plan)
                        }
                        is UiState.Error -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.btnGenerate.visibility = View.VISIBLE
                            Snackbar.make(binding.root, "Load error: ${state.message}", Snackbar.LENGTH_LONG).show()
                        }
                    }
                }
            }
        }
    }

    private fun prefillForm(data: ExistingPlanVO) {
        binding.currencyDropdown.setText(data.currency, false)
        binding.monthlyIncomeInput.setText(data.monthlyIncome.toString())
        binding.fixedExpensesInput.setText(data.fixedMonthlyExpenses.toString())
        binding.savingsGoalInput.setText(data.monthlySavingsGoal.toString())
        selectedPayday = LocalDate.parse(data.nextPayday)
        binding.nextPaydayInput.setText(
            selectedPayday!!.format(DateTimeFormatter.ofPattern("MMM dd, yyyy"))
        )
    }

    private fun disableForm() {
        binding.monthlyIncomeInput.isEnabled = false
        binding.fixedExpensesInput.isEnabled = false
        binding.savingsGoalInput.isEnabled = false
        binding.nextPaydayInput.isEnabled = false
        binding.currencyDropdown.isEnabled = false
        binding.currencyLayout.isEnabled = false
        binding.nextPaydayLayout.isEnabled = false
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
