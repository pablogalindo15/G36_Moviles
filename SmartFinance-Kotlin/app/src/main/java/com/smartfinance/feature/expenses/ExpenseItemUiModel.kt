package com.smartfinance.feature.expenses

data class ExpenseItemUiModel(
    val id: String,
    val category: String,
    val note: String,
    val dateText: String,
    val amountText: String,
    val icon: String,
    val occurredAt: String
)