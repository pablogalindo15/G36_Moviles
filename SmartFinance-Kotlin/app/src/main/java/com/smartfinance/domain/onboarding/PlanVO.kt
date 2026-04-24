package com.smartfinance.domain.onboarding

import android.os.Parcelable
import androidx.versionedparcelable.VersionedParcelize

data class PlanVO(
    val currency: String,
    val monthlySavingsGoal: Double,
    val safeToSpendMonthly: Double,
    val proratedSafeToSpend: Double,
    val weeklyCap: Double,
    val isProrated: Boolean,
    val contextualInsightMessage: String
)


data class ExistingPlanVO(
    val currency: String,
    val monthlyIncome: Double,
    val fixedMonthlyExpenses: Double,
    val monthlySavingsGoal: Double,
    val nextPayday: String,
    val plan: PlanVO
)
