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
import com.smartfinance.databinding.FragmentSpendingInsightsBinding
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch

@AndroidEntryPoint
class SpendingInsightsFragment : Fragment() {

    private var _binding: FragmentSpendingInsightsBinding? = null
    private val binding get() = _binding!!

    private val viewModel: SpendingInsightsViewModel by viewModels()
    private val categoryInsightsAdapter = CategoryInsightsAdapter()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentSpendingInsightsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        setupRecyclerView()
        observeUiState()
    }

    override fun onResume() {
        super.onResume()
        viewModel.loadInsights()
    }

    private fun setupRecyclerView() {
        binding.categoryInsightsRecyclerView.apply {
            adapter = categoryInsightsAdapter
            layoutManager = LinearLayoutManager(requireContext())
            setHasFixedSize(false)
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

        binding.emptyInsightsTextView.isVisible =
            !state.isLoading &&
                    state.errorMessage == null &&
                    state.topCategories.isEmpty()

        categoryInsightsAdapter.submitList(state.topCategories)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}