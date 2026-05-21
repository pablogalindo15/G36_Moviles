package com.smartfinance.feature.expenses

import android.app.AlertDialog
import android.app.DatePickerDialog
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import android.widget.PopupMenu
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import com.smartfinance.databinding.FragmentExpenseDetailBinding
import com.smartfinance.domain.expenses.ExpenseApplicationService
import com.smartfinance.domain.expenses.UpdateExpenseRequestDTO
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Locale
import javax.inject.Inject

@AndroidEntryPoint
class ExpenseDetailFragment : Fragment() {

    private var _binding: FragmentExpenseDetailBinding? = null
    private val binding get() = _binding!!

    @Inject
    lateinit var expenseApplicationService: ExpenseApplicationService

    private lateinit var expenseId: String
    private lateinit var originalOccurredAt: String
    private lateinit var selectedDate: LocalDate

    private var isEditMode = false

    private var initialCategory = ""
    private var initialNote = ""
    private var initialAmount = 0.0
    private var initialDateText = ""

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentExpenseDetailBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        readArguments()
        renderExpenseDetail()
        setupListeners()
        setEditMode(false)
    }

    private fun readArguments() {
        expenseId = requireArguments().getString(ARG_ID).orEmpty()
        originalOccurredAt = requireArguments().getString(ARG_OCCURRED_AT).orEmpty()
        selectedDate = parseLocalDate(originalOccurredAt)
    }

    private fun renderExpenseDetail() {
        val category = requireArguments().getString(ARG_CATEGORY).orEmpty()
        val amountText = requireArguments().getString(ARG_AMOUNT).orEmpty()
        val note = requireArguments().getString(ARG_NOTE).orEmpty()
        val date = requireArguments().getString(ARG_DATE).orEmpty()
        val icon = requireArguments().getString(ARG_ICON).orEmpty()

        initialCategory = category
        initialNote = note
        initialDateText = date
        initialAmount = extractAmountValue(amountText)

        binding.detailIconTextView.text = icon
        binding.detailAmountEditText.setText(String.format(Locale.US, "%.2f", initialAmount))
        binding.detailCategoryEditText.setText(category)
        binding.detailNoteEditText.setText(note)
        binding.detailDateEditText.setText(date)
    }

    private fun setupListeners() {
        binding.backButtonTextView.setOnClickListener {
            findNavController().navigateUp()
        }

        binding.editExpenseIconButton.setOnClickListener {
            setEditMode(true)
        }

        binding.cancelEditButton.setOnClickListener {
            restoreInitialValues()
            setEditMode(false)
        }

        binding.saveExpenseButton.setOnClickListener {
            saveExpense()
        }

        binding.deleteExpenseIconButton.setOnClickListener {
            confirmDeleteExpense()
        }

        binding.detailDateEditText.setOnClickListener {
            if (isEditMode) showDatePicker()
        }
        binding.detailCategoryEditText.setOnClickListener {
            if (isEditMode) showCategoryPicker()
        }
    }

    private fun setEditMode(enabled: Boolean) {
        isEditMode = enabled

        binding.detailAmountEditText.isEnabled = enabled
        binding.detailNoteEditText.isEnabled = enabled
        binding.detailDateEditText.isEnabled = enabled
        binding.detailDateEditText.isClickable = enabled

        binding.detailCategoryEditText.isEnabled = enabled
        binding.detailCategoryEditText.isClickable = enabled
        binding.detailCategoryEditText.isFocusable = false

        binding.editActionsContainer.visibility = if (enabled) View.VISIBLE else View.GONE
        binding.editExpenseIconButton.visibility = if (enabled) View.GONE else View.VISIBLE
        binding.deleteExpenseIconButton.visibility = if (enabled) View.GONE else View.VISIBLE
    }

    private fun restoreInitialValues() {
        binding.detailAmountEditText.setText(String.format(Locale.US, "%.2f", initialAmount))
        binding.detailCategoryEditText.setText(initialCategory)
        binding.detailNoteEditText.setText(initialNote)
        binding.detailDateEditText.setText(initialDateText)
        selectedDate = parseLocalDate(originalOccurredAt)
    }

    private fun showDatePicker() {
        val currentDate = selectedDate

        val datePickerDialog = DatePickerDialog(
            requireContext(),
            { _, year, month, dayOfMonth ->
                val pickedDate = LocalDate.of(year, month + 1, dayOfMonth)

                if (pickedDate.isAfter(LocalDate.now())) {
                    Toast.makeText(
                        requireContext(),
                        "The expense date cannot be in the future.",
                        Toast.LENGTH_SHORT
                    ).show()
                    return@DatePickerDialog
                }

                selectedDate = pickedDate
                binding.detailDateEditText.setText(formatDisplayDate(pickedDate))
            },
            currentDate.year,
            currentDate.monthValue - 1,
            currentDate.dayOfMonth
        )

        datePickerDialog.datePicker.maxDate = System.currentTimeMillis()
        datePickerDialog.show()
    }

    private fun saveExpense() {
        val category = binding.detailCategoryEditText.text.toString().trim()
        val note = binding.detailNoteEditText.text.toString().trim()
        val amountText = binding.detailAmountEditText.text.toString().trim()

        if (category.isBlank()) {
            binding.detailCategoryEditText.error = "Name is required"
            return
        }

        if (amountText.isBlank()) {
            binding.detailAmountEditText.error = "Amount is required"
            return
        }

        val amount = amountText.toDoubleOrNull()
        if (amount == null || amount <= 0.0) {
            binding.detailAmountEditText.error = "Enter a valid amount"
            return
        }

        val updatedOccurredAt = selectedDate
            .atStartOfDay()
            .atOffset(ZoneOffset.UTC)
            .toString()

        lifecycleScope.launch {
            try {
                expenseApplicationService.updateExpense(
                    UpdateExpenseRequestDTO(
                        expenseId = expenseId,
                        category = category,
                        note = note,
                        amount = amount,
                        occurredAt = updatedOccurredAt
                    )
                )

                Toast.makeText(
                    requireContext(),
                    "Expense updated.",
                    Toast.LENGTH_SHORT
                ).show()

                findNavController().navigateUp()
            } catch (exception: Exception) {
                Toast.makeText(
                    requireContext(),
                    exception.message ?: "Could not update expense.",
                    Toast.LENGTH_LONG
                ).show()
            }
        }
    }

    private fun confirmDeleteExpense() {
        AlertDialog.Builder(requireContext())
            .setTitle("Delete expense")
            .setMessage("Are you sure you want to delete this expense?")
            .setPositiveButton("Delete") { _, _ ->
                deleteExpense()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun deleteExpense() {
        lifecycleScope.launch {
            try {
                expenseApplicationService.deleteExpense(expenseId)

                Toast.makeText(
                    requireContext(),
                    "Expense deleted.",
                    Toast.LENGTH_SHORT
                ).show()

                findNavController().navigateUp()
            } catch (exception: Exception) {
                Toast.makeText(
                    requireContext(),
                    exception.message ?: "Could not delete expense.",
                    Toast.LENGTH_LONG
                ).show()
            }
        }
    }

    private fun extractAmountValue(amountText: String): Double {
        return amountText
            .replace("USD", "", ignoreCase = true)
            .trim()
            .toDoubleOrNull() ?: 0.0
    }

    private fun formatDisplayDate(date: LocalDate): String {
        val month = date.month.name.lowercase().replaceFirstChar { it.uppercase() }.take(3)
        return "${date.dayOfMonth} $month, 00:00"
    }

    private fun parseLocalDate(rawDate: String): LocalDate {
        return try {
            OffsetDateTime.parse(rawDate).toLocalDate()
        } catch (_: Exception) {
            LocalDate.now()
        }
    }

    private fun showCategoryPicker() {
        val categories = listOf(
            "Food",
            "Transport",
            "Shopping",
            "Health",
            "Entertainment",
            "Education",
            "Housing",
            "Utilities",
            "Other"
        )

        val popupMenu = PopupMenu(requireContext(), binding.detailCategoryEditText)

        categories.forEach { category ->
            popupMenu.menu.add(category)
        }

        popupMenu.setOnMenuItemClickListener { item ->
            binding.detailCategoryEditText.setText(item.title.toString())
            true
        }

        popupMenu.show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    companion object {
        const val ARG_ID = "id"
        const val ARG_CATEGORY = "category"
        const val ARG_AMOUNT = "amount"
        const val ARG_NOTE = "note"
        const val ARG_DATE = "date"
        const val ARG_OCCURRED_AT = "occurredAt"
        const val ARG_ICON = "icon"
    }
}