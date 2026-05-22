package com.smartfinance.feature.expenses

import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.PopupMenu
import android.widget.TextView
import androidx.core.os.bundleOf
import androidx.core.view.isVisible
import androidx.core.widget.doAfterTextChanged
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.android.material.snackbar.Snackbar
import com.smartfinance.R
import com.smartfinance.databinding.FragmentMyExpensesBinding
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch

@AndroidEntryPoint
class MyExpensesFragment : Fragment() {

    private var _binding: FragmentMyExpensesBinding? = null
    private val binding get() = _binding!!

    private val viewModel: MyExpensesViewModel by viewModels()
    private val expensesAdapter = MyExpensesAdapter { expense ->
        openExpenseDetail(expense)
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentMyExpensesBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        setupRecyclerView()
        setupListeners()
        observeUiState()
    }

    override fun onResume() {
        super.onResume()
        viewModel.loadExpenses()
    }

    private fun setupRecyclerView() {
        binding.myExpensesRecyclerView.apply {
            adapter = expensesAdapter
            layoutManager = LinearLayoutManager(requireContext())
            setHasFixedSize(true)
        }
    }

    private fun setupListeners() {
        binding.myExpensesSearchEditText.doAfterTextChanged { editable ->
            viewModel.onSearchQueryChanged(editable?.toString().orEmpty())
        }

        binding.currentCycleTextView.setOnClickListener {
            viewModel.onFilterChanged(ExpenseListFilter.CURRENT_CYCLE)
        }

        binding.allExpensesTextView.setOnClickListener {
            viewModel.onFilterChanged(ExpenseListFilter.ALL)
        }
        binding.categoryFilterTextView.setOnClickListener {
            showCategoryFilterMenu()
        }

        binding.fabAddExpense.setOnClickListener {
            val userId = viewModel.currentUserId
            val currency = viewModel.uiState.value.expenses.firstOrNull()?.amountText?.split(" ")?.firstOrNull() ?: "USD"

            if (userId == null) {
                Snackbar.make(binding.root, "User session not found", Snackbar.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            findNavController().navigate(
                R.id.action_myExpenses_to_logExpense,
                bundleOf(
                    "userId" to userId,
                    "currency" to currency
                )
            )
        }
    }

    private fun observeUiState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    renderState(state)
                }
            }
        }
    }

    private fun renderState(state: MyExpensesUiState) {
        binding.myExpensesProgressBar.isVisible = state.isLoading

        binding.myExpensesErrorTextView.isVisible = state.errorMessage != null
        binding.myExpensesErrorTextView.text = state.errorMessage

        binding.categoryFilterTextView.text = if (state.selectedCategory.isNullOrBlank()) {
            "All categories ▾"
        } else {
            "${state.selectedCategory} ▾"
        }

        expensesAdapter.submitList(state.filteredExpenses)

        if (state.selectedFilter == ExpenseListFilter.CURRENT_CYCLE) {
            updateFilterStyle(
                selected = binding.currentCycleTextView,
                unselected = binding.allExpensesTextView
            )
        } else {
            updateFilterStyle(
                selected = binding.allExpensesTextView,
                unselected = binding.currentCycleTextView
            )
        }
    }

    private fun updateFilterStyle(
        selected: TextView,
        unselected: TextView
    ) {
        selected.setTextColor(Color.parseColor("#166534"))
        selected.setTypeface(null, Typeface.BOLD)
        selected.setBackgroundResource(R.drawable.bg_filter_chip_selected)

        unselected.setTextColor(Color.parseColor("#6B7280"))
        unselected.setTypeface(null, Typeface.BOLD)
        unselected.setBackgroundResource(R.drawable.bg_filter_chip_unselected)
    }

    private fun showCategoryFilterMenu() {
        val state = viewModel.uiState.value

        val categories = state.expenses
            .map { expense -> expense.category }
            .distinct()
            .sorted()

        val popupMenu = PopupMenu(requireContext(), binding.categoryFilterTextView)

        popupMenu.menu.add("All categories")

        categories.forEach { category ->
            popupMenu.menu.add(category)
        }

        popupMenu.setOnMenuItemClickListener { menuItem ->
            val selectedTitle = menuItem.title.toString()

            if (selectedTitle == "All categories") {
                viewModel.onCategorySelected(null)
            } else {
                viewModel.onCategorySelected(selectedTitle)
            }

            true
        }

        popupMenu.show()
    }

    private fun openExpenseDetail(expense: ExpenseItemUiModel) {
        findNavController().navigate(
            R.id.action_myExpenses_to_expenseDetail,
            bundleOf(
                ExpenseDetailFragment.ARG_ID to expense.id,
                ExpenseDetailFragment.ARG_CATEGORY to expense.category,
                ExpenseDetailFragment.ARG_AMOUNT to expense.amountText,
                ExpenseDetailFragment.ARG_NOTE to expense.note,
                ExpenseDetailFragment.ARG_DATE to expense.dateText,
                ExpenseDetailFragment.ARG_OCCURRED_AT to expense.occurredAt,
                ExpenseDetailFragment.ARG_ICON to expense.icon
            )
        )
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
