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
            "Your plan has been adjusted to help you stay balanced until your next payday."
        } else {
            "You have a full pay cycle ahead. Stay within your weekly cap to meet your savings goal."
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

    suspend fun fetchExistingPlan(userId: String): ExistingPlanVO? {
        val setup = facade.fetchFinancialSetup(userId) ?: return null
        val plan = facade.fetchGeneratedPlan(userId) ?: return null

        val safeToSpendMonthly = setup.monthlyIncome - setup.fixedMonthlyExpenses - setup.monthlySavingsGoal
        val nextPayday = LocalDate.parse(setup.nextPayday)
        val today = LocalDate.now()
        val daysUntilPayday = ChronoUnit.DAYS.between(today, nextPayday).toInt()
        val isProrated = daysUntilPayday in 1 until 30

        val planVO = PlanVO(
            currency = setup.currency,
            monthlySavingsGoal = setup.monthlySavingsGoal,
            safeToSpendMonthly = safeToSpendMonthly,
            proratedSafeToSpend = plan.safeToSpendUntilNextPayday,
            weeklyCap = plan.weeklyCap,
            isProrated = isProrated,
            contextualInsightMessage = plan.contextualInsightMessage
        )

        return ExistingPlanVO(
            currency = setup.currency,
            monthlyIncome = setup.monthlyIncome,
            fixedMonthlyExpenses = setup.fixedMonthlyExpenses,
            monthlySavingsGoal = setup.monthlySavingsGoal,
            nextPayday = setup.nextPayday,
            plan = planVO
        )
    }
}
