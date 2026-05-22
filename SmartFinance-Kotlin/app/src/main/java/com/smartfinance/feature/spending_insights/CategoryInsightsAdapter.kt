package com.smartfinance.feature.spending_insights

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.smartfinance.databinding.ItemCategoryInsightBinding

class CategoryInsightsAdapter :
    ListAdapter<CategoryInsightUiModel, CategoryInsightsAdapter.CategoryInsightViewHolder>(
        DiffCallback
    ) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): CategoryInsightViewHolder {
        val binding = ItemCategoryInsightBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return CategoryInsightViewHolder(binding)
    }

    override fun onBindViewHolder(holder: CategoryInsightViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    class CategoryInsightViewHolder(
        private val binding: ItemCategoryInsightBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(item: CategoryInsightUiModel) {
            binding.categoryIconTextView.text = item.icon
            binding.categoryNameTextView.text = item.category
            binding.categoryAmountTextView.text = item.amountText

            binding.categoryBarView.post {
                val parentWidth = (binding.categoryBarView.parent as ViewGroup).width
                val newWidth = (parentWidth * item.percentage) / 100

                binding.categoryBarView.layoutParams =
                    binding.categoryBarView.layoutParams.apply {
                        width = newWidth
                    }

                binding.categoryBarView.requestLayout()
            }
        }
    }

    private object DiffCallback : DiffUtil.ItemCallback<CategoryInsightUiModel>() {
        override fun areItemsTheSame(
            oldItem: CategoryInsightUiModel,
            newItem: CategoryInsightUiModel
        ): Boolean {
            return oldItem.category == newItem.category
        }

        override fun areContentsTheSame(
            oldItem: CategoryInsightUiModel,
            newItem: CategoryInsightUiModel
        ): Boolean {
            return oldItem == newItem
        }
    }
}