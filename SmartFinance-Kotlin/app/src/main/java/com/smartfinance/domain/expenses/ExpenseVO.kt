package com.smartfinance.domain.expenses

data class ExpenseVO(
    val id: String,
    val userId: String,
    val amount: Double,
    val currency: String,
    val category: String,
    val note: String?,
    val occurredAt: String,
    val createdAt: String,
    val clientUuid: String
)
