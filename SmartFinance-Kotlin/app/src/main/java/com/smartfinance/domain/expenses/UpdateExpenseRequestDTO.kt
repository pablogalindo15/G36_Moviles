package com.smartfinance.domain.expenses

data class UpdateExpenseRequestDTO(
    val expenseId: String,
    val category: String,
    val note: String,
    val amount: Double,
    val occurredAt: String,
    val receiptImageBytes: ByteArray? = null,
    val receiptLocalUri: String? = null,
    val receiptImageUrl: String? = null
)
