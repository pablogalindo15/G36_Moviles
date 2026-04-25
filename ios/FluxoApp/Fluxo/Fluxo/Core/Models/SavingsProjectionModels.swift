import Foundation

struct SavingsProjection: Codable, Equatable {
    let onTrack: Bool
    let currency: String
    let savingsGoal: Decimal
    let projectedSavings: Decimal
    let delta: Decimal
    let weeklySpendingRate: Decimal
    let cycleDaysRemaining: Int
    let projectionBasisWeeks: Int
    let expensesCountBasis: Int

    enum CodingKeys: String, CodingKey {
        case onTrack              = "on_track"
        case currency
        case savingsGoal          = "savings_goal"
        case projectedSavings     = "projected_savings"
        case delta
        case weeklySpendingRate   = "weekly_spending_rate"
        case cycleDaysRemaining   = "cycle_days_remaining"
        case projectionBasisWeeks = "projection_basis_weeks"
        case expensesCountBasis   = "expenses_count_basis"
    }
}

enum SavingsProjectionResult: Equatable {
    case ready(SavingsProjection)
    case insufficientData(expensesCount: Int)
}
