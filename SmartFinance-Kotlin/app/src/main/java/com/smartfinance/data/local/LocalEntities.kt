package com.smartfinance.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "local_financial_setup")
data class LocalFinancialSetup(
    @PrimaryKey val id: String,
    val userId: String,
    val currency: String,
    val monthlyIncome: Double,
    val fixedMonthlyExpenses: Double,
    val monthlySavingsGoal: Double,
    val nextPayday: String
)

@Entity(tableName = "local_plan")
data class LocalPlan(
    @PrimaryKey val id: String,
    val userId: String,
    val financialSetupId: String,
    val safeToSpend: Double,
    val weeklyCap: Double,
    val targetSavings: Double,
    val insightMessage: String,
    val generatedAt: String
)

@Entity(tableName = "local_expense")
data class LocalExpense(
    @PrimaryKey val id: String,
    val userId: String,
    val amount: Double,
    val category: String,
    val description: String,
    val date: String
)
