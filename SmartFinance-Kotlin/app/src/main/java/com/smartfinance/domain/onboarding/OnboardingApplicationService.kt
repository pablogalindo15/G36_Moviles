package com.smartfinance.domain.onboarding


import com.smartfinance.data.onboarding.GenerateFirstPlanRequest
import java.time.LocalDate
import java.time.temporal.ChronoUnit

class OnboardingApplicationService(
    private val facade: OnboardingFacade
) {

    suspend fun setupPlan(dto: PlanRequestDTO): PlanVO {
        val request = GenerateFirstPlanRequest(
            userId = dto.userId,
            currentDate = LocalDate.now().toString(),
            currency = dto.currency,
            monthlyIncome = dto.monthlyIncome,
            fixedMonthlyExpenses = dto.fixedMonthlyExpenses,
            monthlySavingsGoal = dto.monthlySavingsGoal,
            nextPayday = dto.nextPayday.toString()
        )

        val generatedPlan = facade.generateFirstPlan(request)

        return PlanVO(
            currency = dto.currency,
            monthlySavingsGoal = generatedPlan.targetSavings,
            safeToSpendMonthly = dto.monthlyIncome - dto.fixedMonthlyExpenses - dto.monthlySavingsGoal,
            proratedSafeToSpend = generatedPlan.safeToSpend,
            weeklyCap = generatedPlan.weeklyCap,
            isProrated = ChronoUnit.DAYS.between(LocalDate.now(), dto.nextPayday) < 30,
            contextualInsightMessage = generatedPlan.insightMessage
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
            proratedSafeToSpend = plan.safeToSpend,
            weeklyCap = plan.weeklyCap,
            isProrated = isProrated,
            contextualInsightMessage = plan.insightMessage
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
