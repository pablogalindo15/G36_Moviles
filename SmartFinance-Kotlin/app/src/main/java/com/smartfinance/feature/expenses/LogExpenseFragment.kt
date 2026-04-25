package com.smartfinance.feature.expenses

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.os.Bundle
import android.text.InputFilter
import android.text.Spanned
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.widget.doAfterTextChanged
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import androidx.core.content.ContextCompat
import com.google.android.material.chip.Chip
import com.google.android.material.snackbar.Snackbar
import com.smartfinance.R
import com.smartfinance.core.model.UiState
import com.smartfinance.databinding.FragmentLogExpenseBinding
import com.smartfinance.domain.expenses.LogExpenseRequestDTO
import dagger.hilt.android.AndroidEntryPoint
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.launch

@AndroidEntryPoint
class LogExpenseFragment : Fragment() {

    private var _binding: FragmentLogExpenseBinding? = null
    private val binding get() = _binding!!

    private val viewModel: LogExpenseViewModel by viewModels()

    private var selectedDateTime: LocalDateTime = LocalDateTime.now()
    private var selectedCategory: String? = null
    private var userId: String? = null
    private var currency: String = DEFAULT_CURRENCY
    private var amountWarningCount = 0
    private var noteLengthWarningCount = 0
    private var noteSqlWarningCount = 0

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentLogExpenseBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        userId = arguments?.getString(ARG_USER_ID)
        currency = arguments?.getString(ARG_CURRENCY)?.uppercase(Locale.US) ?: DEFAULT_CURRENCY

        if (userId.isNullOrBlank()) {
            Snackbar.make(binding.root, "Missing user id.", Snackbar.LENGTH_LONG).show()
            findNavController().navigateUp()
            return
        }

        binding.currencyValue.text = currency
        setupInputFilters()
        setupCategoryChips()
        setupListeners()
        renderSelectedDateTime()
        observeViewModel()
        updateSaveButtonState()
    }

    private fun setupInputFilters() {
        binding.amountInput.filters = arrayOf(amountInputFilter())
        binding.noteInput.filters = arrayOf(noteInputFilter())
    }

    private fun setupCategoryChips() {
        binding.categoryChipGroup.removeAllViews()
        CATEGORY_OPTIONS.forEachIndexed { index, category ->
            val chip = Chip(requireContext()).apply {
                text = category
                isCheckable = true
                isClickable = true
                chipBackgroundColor = ContextCompat.getColorStateList(
                    requireContext(),
                    R.color.chip_background_selector
                )
                setTextColor(
                    ContextCompat.getColorStateList(
                        requireContext(),
                        R.color.chip_text_selector
                    )
                )
                checkedIcon = null
                id = View.generateViewId()
                tag = category
                if (index == 0) {
                    isChecked = true
                    selectedCategory = category
                }
            }
            binding.categoryChipGroup.addView(chip)
        }
    }

    private fun setupListeners() {
        binding.buttonCancel.setOnClickListener {
            findNavController().navigateUp()
        }

        binding.amountInput.doAfterTextChanged {
            validateAmount(showError = false)
            updateSaveButtonState()
        }

        binding.noteInput.doAfterTextChanged {
            validateNote(showError = false)
            updateSaveButtonState()
        }

        binding.categoryChipGroup.setOnCheckedStateChangeListener { group, checkedIds ->
            selectedCategory = checkedIds.firstOrNull()
                ?.let { chipId -> group.findViewById<Chip>(chipId) }
                ?.tag as? String
            binding.categoryErrorText.visibility = View.GONE
            binding.categoryErrorText.text = null
            updateSaveButtonState()
        }

        binding.buttonDate.setOnClickListener {
            showDatePicker()
        }

        binding.buttonTime.setOnClickListener {
            showTimePicker()
        }

        binding.buttonSaveExpense.setOnClickListener {
            submitExpense()
        }
    }

    private fun observeViewModel() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.saveExpenseState.collect { state ->
                    when (state) {
                        is UiState.Idle -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.buttonSaveExpense.isEnabled = isFormValid()
                        }

                        is UiState.Loading -> {
                            binding.progressIndicator.visibility = View.VISIBLE
                            binding.buttonSaveExpense.isEnabled = false
                        }

                        is UiState.Success -> {
                            binding.progressIndicator.visibility = View.GONE
                            findNavController().previousBackStackEntry
                                ?.savedStateHandle
                                ?.set(EXPENSE_SAVED_KEY, true)
                            findNavController().navigateUp()
                            viewModel.resetState()
                        }

                        is UiState.Error -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.buttonSaveExpense.isEnabled = isFormValid()
                            Snackbar.make(binding.root, state.message, Snackbar.LENGTH_LONG).show()
                        }
                    }
                }
            }
        }
    }

    private fun showDatePicker() {
        val current = selectedDateTime
        DatePickerDialog(
            requireContext(),
            { _, year, month, dayOfMonth ->
                selectedDateTime = selectedDateTime
                    .withYear(year)
                    .withMonth(month + 1)
                    .withDayOfMonth(dayOfMonth)
                renderSelectedDateTime()
            },
            current.year,
            current.monthValue - 1,
            current.dayOfMonth
        ).show()
    }

    private fun showTimePicker() {
        val current = selectedDateTime
        TimePickerDialog(
            requireContext(),
            { _, hourOfDay, minute ->
                selectedDateTime = selectedDateTime
                    .withHour(hourOfDay)
                    .withMinute(minute)
                renderSelectedDateTime()
            },
            current.hour,
            current.minute,
            false
        ).show()
    }

    private fun renderSelectedDateTime() {
        binding.buttonDate.text = selectedDateTime.format(DATE_FORMATTER)
        binding.buttonTime.text = selectedDateTime.format(TIME_FORMATTER)
    }

    private fun submitExpense() {
        val amount = validateAmount(showError = true)
        val note = validateNote(showError = true)
        val category = selectedCategory
        val categoryIsValid = !category.isNullOrBlank()

        if (!categoryIsValid) {
            binding.categoryErrorText.visibility = View.VISIBLE
            binding.categoryErrorText.text = getString(R.string.expense_category_error)
        }

        if (amount == null || note == null || !categoryIsValid) return

        val resolvedCategory = category ?: return

        viewModel.saveExpense(
            LogExpenseRequestDTO(
                userId = userId.orEmpty(),
                amount = amount,
                currency = currency,
                category = resolvedCategory,
                note = note,
                occurredAt = selectedDateTime
            )
        )
    }

    private fun updateSaveButtonState() {
        binding.buttonSaveExpense.isEnabled = isFormValid()
    }

    private fun isFormValid(): Boolean {
        return validateAmount(showError = false) != null &&
            validateNote(showError = false) != null &&
            !selectedCategory.isNullOrBlank()
    }

    private fun validateAmount(showError: Boolean): Double? {
        val amount = binding.amountInput.text?.toString()?.toDoubleOrNull()
        val error = when {
            amount == null || amount <= 0.0 -> getString(R.string.expense_amount_error)
            amount > MAX_AMOUNT -> getString(R.string.expense_amount_too_high)
            else -> null
        }

        binding.amountLayout.error = if (showError) error else null
        return if (error == null) amount else null
    }

    private fun validateNote(showError: Boolean): String? {
        val note = binding.noteInput.text?.toString().orEmpty().trim()
        val error = when {
            note.length > MAX_NOTE_LENGTH -> getString(R.string.expense_note_too_long)
            SQL_LIKE_PATTERN.containsMatchIn(note) -> getString(R.string.expense_note_sql_like)
            else -> null
        }

        binding.noteLayout.error = if (showError) error else null
        return if (error == null) note else null
    }

    private fun amountInputFilter(): InputFilter {
        return InputFilter { source, start, end, dest, dstart, dend ->
            val replacement = source.subSequence(start, end).toString()
            val nextText = buildCandidateText(dest, replacement, dstart, dend)

            if (nextText.isBlank()) {
                return@InputFilter null
            }

            if (!AMOUNT_PATTERN.matches(nextText)) {
                showLimitedWarning(
                    message = getString(R.string.expense_amount_too_high),
                    currentCount = amountWarningCount
                ) { amountWarningCount++ }
                return@InputFilter ""
            }

            val parsedAmount = nextText.toDoubleOrNull()
            if (parsedAmount != null && parsedAmount > MAX_AMOUNT) {
                showLimitedWarning(
                    message = getString(R.string.expense_amount_too_high),
                    currentCount = amountWarningCount
                ) { amountWarningCount++ }
                return@InputFilter ""
            }

            null
        }
    }

    private fun noteInputFilter(): InputFilter {
        return InputFilter { source, start, end, dest, dstart, dend ->
            val replacement = source.subSequence(start, end).toString()
            val nextText = buildCandidateText(dest, replacement, dstart, dend)

            if (nextText.length > MAX_NOTE_LENGTH) {
                showLimitedWarning(
                    message = getString(R.string.expense_note_too_long),
                    currentCount = noteLengthWarningCount
                ) { noteLengthWarningCount++ }
                return@InputFilter ""
            }

            if (SQL_LIKE_PATTERN.containsMatchIn(nextText.trim())) {
                showLimitedWarning(
                    message = getString(R.string.expense_note_sql_like),
                    currentCount = noteSqlWarningCount
                ) { noteSqlWarningCount++ }
                return@InputFilter ""
            }

            null
        }
    }

    private fun buildCandidateText(
        dest: Spanned,
        replacement: String,
        dstart: Int,
        dend: Int
    ): String {
        return dest.substring(0, dstart) + replacement + dest.substring(dend, dest.length)
    }

    private fun showLimitedWarning(
        message: String,
        currentCount: Int,
        onShown: () -> Unit
    ) {
        if (currentCount >= MAX_WARNING_COUNT) return
        Snackbar.make(binding.root, message, Snackbar.LENGTH_SHORT).show()
        onShown()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    private companion object {
        const val ARG_USER_ID = "userId"
        const val ARG_CURRENCY = "currency"
        const val DEFAULT_CURRENCY = "USD"
        const val EXPENSE_SAVED_KEY = "expense_saved"
        const val MAX_AMOUNT = 10_000_000.0
        const val MAX_NOTE_LENGTH = 100
        const val MAX_WARNING_COUNT = 2
        val AMOUNT_PATTERN = Regex("^\\d{0,8}(\\.\\d{0,2})?$")
        val SQL_LIKE_PATTERN = Regex(
            pattern = "(^|[^A-Za-z0-9_])(select|insert|update|delete|drop|truncate|alter|create|grant|revoke|union|exec|execute)([^A-Za-z0-9_]|$)|--|/\\*|\\*/|;",
            option = RegexOption.IGNORE_CASE
        )
        val DATE_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM/yyyy")
        val TIME_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("hh:mm a")
        val CATEGORY_OPTIONS = listOf("Food", "Transport", "Entertainment", "Bills", "Shopping", "Other")
    }
}
