import Foundation
import SwiftData

@Model
final class LocalPlan {
    // Matches GeneratedPlanDTO field types exactly.
    // Amounts are stored as Decimal (converted from DTO's Double) for precision.
    @Attribute(.unique) var id: String
    var userId: String
    var financialSetupId: String
    var safeToSpendUntilNextPayday: Decimal
    var weeklyCap: Decimal
    var targetSavings: Decimal
    var contextualInsightMessage: String
    var generatedAt: String       // "yyyy-MM-dd'T'HH:mm:ss" — stored as-is from DTO

    init(
        id: String,
        userId: String,
        financialSetupId: String,
        safeToSpendUntilNextPayday: Decimal,
        weeklyCap: Decimal,
        targetSavings: Decimal,
        contextualInsightMessage: String,
        generatedAt: String
    ) {
        self.id = id
        self.userId = userId
        self.financialSetupId = financialSetupId
        self.safeToSpendUntilNextPayday = safeToSpendUntilNextPayday
        self.weeklyCap = weeklyCap
        self.targetSavings = targetSavings
        self.contextualInsightMessage = contextualInsightMessage
        self.generatedAt = generatedAt
    }

    convenience init(from dto: GeneratedPlanDTO) {
        self.init(
            id: dto.id,
            userId: dto.user_id.lowercased(),
            financialSetupId: dto.financial_setup_id,
            safeToSpendUntilNextPayday: Decimal(dto.safe_to_spend_until_next_payday),
            weeklyCap: Decimal(dto.weekly_cap),
            targetSavings: Decimal(dto.target_savings),
            contextualInsightMessage: dto.contextual_insight_message,
            generatedAt: dto.generated_at
        )
    }

    func toDTO() -> GeneratedPlanDTO {
        GeneratedPlanDTO(
            id: id,
            user_id: userId,
            financial_setup_id: financialSetupId,
            safe_to_spend_until_next_payday: (safeToSpendUntilNextPayday as NSDecimalNumber).doubleValue,
            weekly_cap: (weeklyCap as NSDecimalNumber).doubleValue,
            target_savings: (targetSavings as NSDecimalNumber).doubleValue,
            contextual_insight_message: contextualInsightMessage,
            generated_at: generatedAt
        )
    }
}
