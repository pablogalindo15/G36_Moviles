package com.smartfinance.domain.onboarding

import com.smartfinance.core.model.FinancialSetup
import com.smartfinance.core.model.GeneratedPlan
import java.time.LocalDate
import java.time.temporal.ChronoUnit

class OnboardingApplicationService(
    private val facade: OnboardingFacade
) {

    suspend fun setupPlan(dto: PlanRequestDTO): PlanVO {
        val safeToSpendMonthly = dto.monthlyIncome - dto.fixedMonthlyExpenses - dto.monthlySavingsGoal

        val today = LocalDate.now()
        val daysUntilPayday = ChronoUnit.DAYS.between(today, dto.nextPayday).toInt()
        val daysInCycle = 30

        val isProrated = daysUntilPayday < daysInCycle
        val effectiveDays = if (isProrated) daysUntilPayday else daysInCycle

        val proratedSafeToSpend = safeToSpendMonthly * (effectiveDays.toDouble() / daysInCycle)
        val weeks = effectiveDays / 7.0
        val weeklyCap = if (weeks > 0) proratedSafeToSpend / weeks else 0.0

        val insightMessage = if (isProrated) {
            "Your plan is adjusted for $daysUntilPayday days until your next payday. " +
                "After that, your full monthly safe-to-spend will be \$${String.format("%.2f", safeToSpendMonthly)}."
        } else {
            "You have a full pay cycle ahead. Stay within your weekly cap of " +
                "\$${String.format("%.2f", weeklyCap)} to meet your savings goal."
        }

        // Persist financial setup, get back the generated UUID
        val setup = FinancialSetup(
            userId = dto.userId,
            currency = dto.currency,
            monthlyIncome = dto.monthlyIncome,
            fixedMonthlyExpenses = dto.fixedMonthlyExpenses,
            monthlySavingsGoal = dto.monthlySavingsGoal,
            nextPayday = dto.nextPayday.toString()
        )
        val setupId = facade.saveFinancialSetup(setup)

        // Persist generated plan with the setup fk
        val generatedPlan = GeneratedPlan(
            userId = dto.userId,
            financialSetupId = setupId,
            safeToSpendUntilNextPayday = proratedSafeToSpend,
            weeklyCap = weeklyCap,
            targetSavings = dto.monthlySavingsGoal,
            contextualInsightMessage = insightMessage
        )
        facade.saveGeneratedPlan(generatedPlan)

        return PlanVO(
            currency = dto.currency,
            monthlySavingsGoal = dto.monthlySavingsGoal,
            safeToSpendMonthly = safeToSpendMonthly,
            proratedSafeToSpend = proratedSafeToSpend,
            weeklyCap = weeklyCap,
            isProrated = isProrated,
            contextualInsightMessage = insightMessage
        )
    }
}
