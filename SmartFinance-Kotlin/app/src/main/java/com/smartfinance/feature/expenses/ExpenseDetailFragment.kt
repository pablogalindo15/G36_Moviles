package com.smartfinance.feature.expenses

import android.app.AlertDialog
import android.app.DatePickerDialog
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import android.widget.PopupMenu
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import com.smartfinance.databinding.FragmentExpenseDetailBinding
import com.smartfinance.domain.expenses.ExpenseApplicationService
import com.smartfinance.domain.expenses.UpdateExpenseRequestDTO
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.URL
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
    private var initialReceiptImageUrl: String? = null
    private var selectedReceiptUri: Uri? = null
    private var cameraReceiptUri: Uri? = null

    private val pickReceiptLauncher = registerForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            selectedReceiptUri = uri
            renderReceipt(uri)
        }
    }

    private val takeReceiptLauncher = registerForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success && cameraReceiptUri != null) {
            selectedReceiptUri = cameraReceiptUri
            renderReceipt(cameraReceiptUri)
        }
    }

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
        initialReceiptImageUrl = requireArguments().getString(ARG_RECEIPT_IMAGE_URL)

        initialCategory = category
        initialNote = note
        initialDateText = date
        initialAmount = extractAmountValue(amountText)

        binding.detailIconTextView.text = icon
        binding.detailAmountEditText.setText(String.format(Locale.US, "%.2f", initialAmount))
        binding.detailCategoryEditText.setText(category)
        binding.detailNoteEditText.setText(note)
        binding.detailDateEditText.setText(date)
        renderRemoteReceipt(initialReceiptImageUrl)
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

        binding.changeReceiptCameraButton.setOnClickListener {
            if (isEditMode) {
                cameraReceiptUri = createImageUri()
                takeReceiptLauncher.launch(cameraReceiptUri)
            }
        }

        binding.changeReceiptGalleryButton.setOnClickListener {
            if (isEditMode) {
                pickReceiptLauncher.launch(
                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                )
            }
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

        binding.detailReceiptActionsContainer.visibility = if (enabled) View.VISIBLE else View.GONE
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
        selectedReceiptUri = null
        renderRemoteReceipt(initialReceiptImageUrl)
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
                val receiptPayload = selectedReceiptUri?.let { uri ->
                    withContext(Dispatchers.IO) {
                        copyReceiptToLocalCache(uri)
                    }
                }

                withContext(Dispatchers.IO) {
                    expenseApplicationService.updateExpense(
                        UpdateExpenseRequestDTO(
                            expenseId = expenseId,
                            category = category,
                            note = note,
                            amount = amount,
                            occurredAt = updatedOccurredAt,
                            receiptImageBytes = receiptPayload?.first,
                            receiptLocalUri = receiptPayload?.second,
                            receiptImageUrl = initialReceiptImageUrl
                        )
                    )
                }

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

    private fun renderReceipt(uri: Uri?) {
        binding.detailReceiptImageView.visibility = if (uri == null) View.GONE else View.VISIBLE
        binding.detailReceiptEmptyTextView.visibility = if (uri == null) View.VISIBLE else View.GONE
        binding.detailReceiptImageView.setImageURI(uri)
    }

    private fun renderRemoteReceipt(receiptUrl: String?) {
        if (receiptUrl.isNullOrBlank()) {
            renderReceipt(null)
            return
        }

        lifecycleScope.launch {
            val bitmap = withContext(Dispatchers.IO) {
                runCatching {
                    URL(receiptUrl).openStream().use { stream ->
                        BitmapFactory.decodeStream(stream)
                    }
                }.getOrNull()
            }

            if (bitmap != null) {
                binding.detailReceiptImageView.visibility = View.VISIBLE
                binding.detailReceiptEmptyTextView.visibility = View.GONE
                binding.detailReceiptImageView.setImageBitmap(bitmap)
            } else {
                renderReceipt(null)
            }
        }
    }

    private fun createImageUri(): Uri {
        val imageFile = File.createTempFile(
            "expense_receipt_${System.currentTimeMillis()}",
            ".jpg",
            requireContext().cacheDir
        )

        return FileProvider.getUriForFile(
            requireContext(),
            "${requireContext().packageName}.provider",
            imageFile
        )
    }

    private fun copyReceiptToLocalCache(uri: Uri): Pair<ByteArray, String>? {
        val imageBytes = requireContext().contentResolver.openInputStream(uri)?.use {
            it.readBytes()
        } ?: return null

        val cachedFile = File(
            requireContext().cacheDir,
            "expense_receipt_cache_${System.currentTimeMillis()}.jpg"
        )
        cachedFile.writeBytes(imageBytes)

        return imageBytes to Uri.fromFile(cachedFile).toString()
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
        const val ARG_RECEIPT_IMAGE_URL = "receiptImageUrl"
    }
}
