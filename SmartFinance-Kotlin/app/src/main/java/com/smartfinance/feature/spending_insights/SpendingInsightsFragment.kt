package com.smartfinance.feature.spending_insights

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.recyclerview.widget.LinearLayoutManager
import com.smartfinance.R
import com.smartfinance.databinding.FragmentSpendingInsightsBinding
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch

@AndroidEntryPoint
class SpendingInsightsFragment : Fragment() {

    private var _binding: FragmentSpendingInsightsBinding? = null
    private val binding get() = _binding!!

    private val viewModel: SpendingInsightsViewModel by viewModels()
    private val categoryInsightsAdapter = CategoryInsightsAdapter()
    private val streaksAdapter = CategoryStreaksAdapter()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentSpendingInsightsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        setupRecyclerViews()
        observeUiState()
    }

    override fun onResume() {
        super.onResume()
        viewModel.loadInsights()
    }

    private fun setupRecyclerViews() {
        binding.categoryInsightsRecyclerView.apply {
            adapter = categoryInsightsAdapter
            layoutManager = LinearLayoutManager(requireContext())
            isNestedScrollingEnabled = false
        }

        binding.streaksRecyclerView.apply {
            adapter = streaksAdapter
            layoutManager = LinearLayoutManager(requireContext())
            isNestedScrollingEnabled = false
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

    private fun renderState(state: SpendingInsightsUiState) {
        binding.insightsProgressBar.isVisible = state.isLoading
        binding.insightsErrorTextView.isVisible = state.errorMessage != null
        binding.insightsErrorTextView.text = state.errorMessage

        val hasBiggestExpense = state.biggestExpense != null
        val hasCategories = state.topCategories.isNotEmpty()
        val hasStreaks = state.streaks.isNotEmpty()

        binding.biggestExpenseCard.isVisible = !state.isLoading && hasBiggestExpense
        state.biggestExpense?.let { biggestExpense ->
            binding.biggestExpenseAmountTextView.text = biggestExpense.amountText
            binding.biggestExpenseCycleTextView.text = biggestExpense.cycleText
            binding.biggestExpenseDateTextView.text = biggestExpense.expenseDateText
            binding.biggestExpenseCategoryTotalTextView.text =
                getString(
                    R.string.biggest_expense_category_total,
                    biggestExpense.categoryTotalText
                )
            binding.biggestExpenseCategoryIconTextView.text = biggestExpense.categoryIcon
            binding.biggestExpenseCategoryTextView.text = biggestExpense.categoryText
        }

        binding.topCategoriesCard.isVisible = !state.isLoading && hasCategories
        categoryInsightsAdapter.submitList(state.topCategories)

        binding.streaksCard.isVisible = !state.isLoading && hasStreaks
        binding.streaksDescriptionTextView.text = state.evaluatedAtText
        streaksAdapter.submitList(state.streaks)

        binding.emptyInsightsTextView.isVisible = 
            !state.isLoading && state.errorMessage == null &&
                !hasBiggestExpense && !hasCategories && !hasStreaks
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
