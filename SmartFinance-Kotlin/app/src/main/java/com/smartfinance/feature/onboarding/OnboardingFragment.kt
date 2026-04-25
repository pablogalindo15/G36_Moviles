package com.smartfinance.feature.onboarding

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.material.datepicker.MaterialDatePicker
import com.google.android.material.snackbar.Snackbar
import com.smartfinance.core.location.LocationCountryResolver
import com.smartfinance.R
import com.smartfinance.core.model.UiState
import com.smartfinance.databinding.FragmentOnboardingBinding
import com.smartfinance.domain.onboarding.PlanRequestDTO
import dagger.hilt.android.AndroidEntryPoint
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.launch

@AndroidEntryPoint
class OnboardingFragment : Fragment() {

    private var _binding: FragmentOnboardingBinding? = null
    private val binding get() = _binding!!

    private val viewModel: OnboardingViewModel by viewModels()
    private val fusedLocationClient by lazy { LocationServices.getFusedLocationProviderClient(requireActivity()) }

    private var selectedPayday: LocalDate? = null
    private var currencyAdapter: ArrayAdapter<String>? = null
    private var hasShownLocationFallback = false
    private val currencies = mutableListOf(
        "USD",
        "EUR",
        "GBP",
        "MXN",
        "COP",
        "ARS",
        "BRL",
        "CLP",
        "PEN",
        "CAD"
    )

    private val locationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) {
                requestCurrentLocation()
            } else {
                showLocationFallbackMessage(getString(R.string.location_permission_denied))
            }
        }

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
        observeSignOut()
        observePlanCreation()
        observeLocationContext()
        requestLocationContextOnFirstOpen(savedInstanceState)

        val userId = arguments?.getString("userId") ?: return
        viewModel.loadExistingPlan(userId)
    }

    private fun observePlanCreation() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    when (state) {
                        is UiState.Loading -> {
                            binding.btnGenerate.isEnabled = false
                        }

                        is UiState.Success -> {
                            val userId = arguments?.getString("userId")
                            val bundle = Bundle().apply { putString("userId", userId) }

                            findNavController().navigate(
                                R.id.action_onboarding_to_insights,
                                bundle
                            )
                        }

                        is UiState.Error -> {
                            binding.btnGenerate.isEnabled = true
                            Snackbar.make(binding.root, state.message, Snackbar.LENGTH_LONG).show()
                        }

                        else -> Unit
                    }
                }
            }
        }
    }

    private fun observeLocationContext() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.locationContextState.collect { state ->
                    when (state) {
                        is UiState.Loading -> {
                            binding.currencyLayout.helperText = null
                        }

                        is UiState.Success -> {
                            binding.currencyLayout.helperText = null
                            applyCurrency(state.data.currency)
                        }

                        is UiState.Error -> {
                            binding.currencyLayout.helperText = null
                            showLocationFallbackMessage(getString(R.string.location_context_failed))
                        }

                        else -> Unit
                    }
                }
            }
        }
    }

    private fun requestLocationContextOnFirstOpen(savedInstanceState: Bundle?) {
        if (savedInstanceState != null) return

        when {
            ContextCompat.checkSelfPermission(
                requireContext(),
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED -> {
                requestCurrentLocation()
            }

            shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_COARSE_LOCATION) -> {
                Snackbar.make(
                    binding.root,
                    R.string.location_permission_rationale,
                    Snackbar.LENGTH_LONG
                ).setAction(R.string.location_permission_action) {
                    locationPermissionLauncher.launch(Manifest.permission.ACCESS_COARSE_LOCATION)
                }.show()
            }

            else -> {
                locationPermissionLauncher.launch(Manifest.permission.ACCESS_COARSE_LOCATION)
            }
        }
    }

    private fun requestCurrentLocation() {
        if (
            ContextCompat.checkSelfPermission(
                requireContext(),
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            showLocationFallbackMessage(getString(R.string.location_permission_denied))
            return
        }

        val tokenSource = CancellationTokenSource()
        try {
            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                tokenSource.token
            ).addOnSuccessListener { location ->
                if (location == null) {
                    showLocationFallbackMessage(getString(R.string.location_context_failed))
                    return@addOnSuccessListener
                }

                viewLifecycleOwner.lifecycleScope.launch {
                    val countryCode = LocationCountryResolver.resolve(
                        context = requireContext(),
                        latitude = location.latitude,
                        longitude = location.longitude
                    )
                    viewModel.detectLocationContext(
                        latitude = location.latitude,
                        longitude = location.longitude,
                        countryCode = countryCode
                    )
                }
            }.addOnFailureListener {
                showLocationFallbackMessage(getString(R.string.location_context_failed))
            }
        } catch (_: SecurityException) {
            showLocationFallbackMessage(getString(R.string.location_context_failed))
        }
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
        currencyAdapter = ArrayAdapter(
            requireContext(),
            android.R.layout.simple_dropdown_item_1line,
            currencies
        )
        binding.currencyDropdown.setAdapter(currencyAdapter)
        binding.currencyDropdown.setOnItemClickListener { _, _, position, _ ->
            currencyAdapter?.getItem(position)?.let(::applyCurrency)
        }
        applyCurrency(currencies.first())
    }

    private fun applyCurrency(currency: String) {
        ensureCurrencyOption(currency)
        binding.currencyDropdown.setText(currency, false)
        binding.monthlyIncomeLayout.prefixText = "$currency "
        binding.fixedExpensesLayout.prefixText = "$currency "
        binding.savingsGoalLayout.prefixText = "$currency "
    }

    private fun ensureCurrencyOption(currency: String) {
        if (currency !in currencies) {
            currencies.add(0, currency)
            currencyAdapter?.notifyDataSetChanged()
        }
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

    private fun showLocationFallbackMessage(message: String) {
        if (_binding == null || hasShownLocationFallback) return
        hasShownLocationFallback = true
        Snackbar.make(binding.root, message, Snackbar.LENGTH_LONG).show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
