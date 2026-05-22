package com.smartfinance.feature.expenses

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.smartfinance.databinding.ItemMyExpenseBinding

class MyExpensesAdapter(
    private val onExpenseClicked: (ExpenseItemUiModel) -> Unit
) : ListAdapter<ExpenseItemUiModel, MyExpensesAdapter.MyExpenseViewHolder>(DiffCallback) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): MyExpenseViewHolder {
        val binding = ItemMyExpenseBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return MyExpenseViewHolder(
            binding = binding,
            onExpenseClicked = onExpenseClicked
        )
    }

    override fun onBindViewHolder(holder: MyExpenseViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    class MyExpenseViewHolder(
        private val binding: ItemMyExpenseBinding,
        private val onExpenseClicked: (ExpenseItemUiModel) -> Unit
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(expense: ExpenseItemUiModel) {
            binding.expenseIconTextView.text = expense.icon
            binding.expenseCategoryTextView.text = expense.category
            binding.expenseAmountTextView.text = expense.amountText

            binding.expenseItemContainer.setOnClickListener {
                onExpenseClicked(expense)
            }
        }
    }

    private object DiffCallback : DiffUtil.ItemCallback<ExpenseItemUiModel>() {
        override fun areItemsTheSame(
            oldItem: ExpenseItemUiModel,
            newItem: ExpenseItemUiModel
        ): Boolean {
            return oldItem.id == newItem.id
        }

        override fun areContentsTheSame(
            oldItem: ExpenseItemUiModel,
            newItem: ExpenseItemUiModel
        ): Boolean {
            return oldItem == newItem
        }
    }
}