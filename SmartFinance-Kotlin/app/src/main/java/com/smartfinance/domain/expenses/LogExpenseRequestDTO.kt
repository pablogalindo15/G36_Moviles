package com.smartfinance.domain.expenses

import java.time.LocalDateTime

data class LogExpenseRequestDTO(
    val userId: String,
    val amount: Double,
    val currency: String,
    val category: String,
    val note: String,
    val occurredAt: LocalDateTime
)
