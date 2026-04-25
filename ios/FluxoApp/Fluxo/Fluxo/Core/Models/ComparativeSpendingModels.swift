import Foundation

struct ComparativeSpending: Codable, Equatable {
    let myWeeklySpending: Decimal
    let cohortAvgWeeklySpending: Decimal
    let cohortSize: Int
    let myPercentile: Double
    let currency: String
    let weekStart: Date
    let weekEnd: Date

    enum CodingKeys: String, CodingKey {
        case myWeeklySpending        = "my_weekly_spending"
        case cohortAvgWeeklySpending = "cohort_avg_weekly_spending"
        case cohortSize              = "cohort_size"
        case myPercentile            = "my_percentile"
        case currency
        case weekStart               = "week_start"
        case weekEnd                 = "week_end"
    }
}

enum ComparativeSpendingResult: Equatable {
    case ready(ComparativeSpending)
    case cohortTooSmall(cohortSize: Int)
}
