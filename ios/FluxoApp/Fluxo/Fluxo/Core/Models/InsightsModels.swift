import Foundation

// MARK: - BQ D: Category Cycle Comparison

struct CategoryCycleComparison: Codable {
    let currency: String
    let cycleStart: String
    let cycleEnd: String
    let previousCycleStart: String
    let categories: [CategoryCycleItem]

    enum CodingKeys: String, CodingKey {
        case currency
        case cycleStart         = "cycle_start"
        case cycleEnd           = "cycle_end"
        case previousCycleStart = "previous_cycle_start"
        case categories
    }
}

struct CategoryCycleItem: Codable {
    let category: ExpenseCategory
    let currentAmount: Decimal
    let previousAmount: Decimal
    let deltaAmount: Decimal
    let deltaPercent: Double?

    enum CodingKeys: String, CodingKey {
        case category
        case currentAmount  = "current_amount"
        case previousAmount = "previous_amount"
        case deltaAmount    = "delta_amount"
        case deltaPercent   = "delta_percent"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let categoryString = try c.decode(String.self, forKey: .category)
        self.category       = ExpenseCategory(rawValue: categoryString) ?? .other
        self.currentAmount  = try c.decode(Decimal.self, forKey: .currentAmount)
        self.previousAmount = try c.decode(Decimal.self, forKey: .previousAmount)
        self.deltaAmount    = try c.decode(Decimal.self, forKey: .deltaAmount)
        self.deltaPercent   = try c.decodeIfPresent(Double.self, forKey: .deltaPercent)
    }
}

// MARK: - BQ E: Category Streaks

struct CategoryStreaks: Codable {
    let evaluatedAt: Date
    let streaks: [CategoryStreak]

    enum CodingKeys: String, CodingKey {
        case evaluatedAt = "evaluated_at"
        case streaks
    }
}

struct CategoryStreak: Codable {
    let category: ExpenseCategory
    let daysSinceLast: Int
    let capped: Bool

    enum CodingKeys: String, CodingKey {
        case category
        case daysSinceLast = "days_since_last"
        case capped
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let categoryString = try c.decode(String.self, forKey: .category)
        self.category      = ExpenseCategory(rawValue: categoryString) ?? .other
        self.daysSinceLast = try c.decode(Int.self, forKey: .daysSinceLast)
        self.capped        = try c.decode(Bool.self, forKey: .capped)
    }
}

// MARK: - BQ F: Biggest Expense of Cycle

struct BiggestExpenseOfCycle: Codable {
    let currency: String
    let cycleStart: String
    let cycleEnd: String
    let biggest: BiggestExpense?

    enum CodingKeys: String, CodingKey {
        case currency
        case cycleStart = "cycle_start"
        case cycleEnd   = "cycle_end"
        case biggest
    }
}

struct BiggestExpense: Codable {
    let amount: Decimal
    let category: ExpenseCategory
    let occurredAt: Date
    let note: String?
    let percentOfBudget: Double?

    enum CodingKeys: String, CodingKey {
        case amount
        case category
        case occurredAt      = "occurred_at"
        case note
        case percentOfBudget = "percent_of_budget"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.amount          = try c.decode(Decimal.self, forKey: .amount)
        let categoryString   = try c.decode(String.self, forKey: .category)
        self.category        = ExpenseCategory(rawValue: categoryString) ?? .other
        self.occurredAt      = try c.decode(Date.self, forKey: .occurredAt)
        self.note            = try c.decodeIfPresent(String.self, forKey: .note)
        self.percentOfBudget = try c.decodeIfPresent(Double.self, forKey: .percentOfBudget)
    }
}
