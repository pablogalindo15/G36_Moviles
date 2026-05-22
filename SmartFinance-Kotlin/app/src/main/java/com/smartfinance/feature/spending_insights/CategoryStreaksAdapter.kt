package com.smartfinance.feature.spending_insights

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.smartfinance.databinding.ItemCategoryStreakBinding

class CategoryStreaksAdapter : ListAdapter<CategoryStreakUiModel, CategoryStreaksAdapter.ViewHolder>(DiffCallback) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemCategoryStreakBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    class ViewHolder(private val binding: ItemCategoryStreakBinding) : RecyclerView.ViewHolder(binding.root) {
        fun bind(uiModel: CategoryStreakUiModel) {
            binding.streakIconTextView.text = uiModel.icon
            binding.streakCategoryTextView.text = uiModel.category
            binding.streakDaysTextView.text = uiModel.daysText
        }
    }

    companion object DiffCallback : DiffUtil.ItemCallback<CategoryStreakUiModel>() {
        override fun areItemsTheSame(oldItem: CategoryStreakUiModel, newItem: CategoryStreakUiModel): Boolean {
            return oldItem.category == newItem.category
        }

        override fun areContentsTheSame(oldItem: CategoryStreakUiModel, newItem: CategoryStreakUiModel): Boolean {
            return oldItem == newItem
        }
    }
}
