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
    val currency: String,
    val category: String,
    val note: String?,
    val occurredAt: String,
    val createdAt: String,
    val clientUuid: String
)

@Entity(tableName = "local_savings_projection")
data class LocalSavingsProjectionCache(
    @PrimaryKey val userId: String,
    val isOnTrack: Boolean,
    val projectedSavings: Double,
    val savingsGoal: Double,
    val message: String,
    val computedAt: Long,
    val cachedAt: Long
)

@Entity(tableName = "local_comparative_insight")
data class LocalComparativeInsightCache(
    @PrimaryKey val userId: String,
    val type: String,
    val myWeeklySpending: Double?,
    val cohortAverageWeeklySpending: Double?,
    val cohortSize: Int,
    val percentile: Double?,
    val currency: String?,
    val weekStart: String?,
    val weekEnd: String?,
    val reason: String?,
    val cachedAt: Long
)
