package com.smartfinance.domain.expenses

import com.smartfinance.data.expenses.ExpenseRepository

class ExpenseApplicationService(
    private val repository: ExpenseRepository
) {

    suspend fun logExpense(request: LogExpenseRequestDTO): ExpenseVO {
        require(request.userId.isNotBlank()) { "Missing user id" }
        require(request.currency.isNotBlank()) { "Currency is required" }
        require(request.category.isNotBlank()) { "Category is required" }
        require(request.amount > 0.0) { "Amount must be greater than zero" }

        val cleanNote = request.note.trim()

        require(request.amount <= MAX_AMOUNT) { "The amount is too high. Enter a lower amount." }
        require(cleanNote.length <= MAX_NOTE_LENGTH) {
            "The note can be up to $MAX_NOTE_LENGTH characters."
        }
        require(!SQL_LIKE_PATTERN.containsMatchIn(cleanNote)) {
            "Remove SQL-like text from the note."
        }

        return repository.logExpense(
            request.copy(
                currency = request.currency.trim().uppercase(),
                category = request.category.trim(),
                note = cleanNote
            )
        )
    }

    private companion object {
        const val MAX_AMOUNT = 10_000_000.0
        const val MAX_NOTE_LENGTH = 100
        val SQL_LIKE_PATTERN = Regex(
            pattern = "(^|[^A-Za-z0-9_])(select|insert|update|delete|drop|truncate|alter|create|grant|revoke|union|exec|execute)([^A-Za-z0-9_]|$)|--|/\\*|\\*/|;",
            option = RegexOption.IGNORE_CASE
        )
    }
}
