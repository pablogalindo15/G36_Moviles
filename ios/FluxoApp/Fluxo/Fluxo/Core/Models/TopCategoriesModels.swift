import Foundation

struct TopCategoryItem: Equatable, Identifiable {
    let category: ExpenseCategory
    let count: Int
    let percentage: Double

    var id: ExpenseCategory { category }
}

extension TopCategoryItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case category, count, percentage
    }

    /// Custom init that falls back to `.other` for any category string not in the enum,
    /// so an unknown backend value never crashes the decoder.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let categoryString = try c.decode(String.self, forKey: .category)
        self.category = ExpenseCategory(rawValue: categoryString) ?? .other
        self.count = try c.decode(Int.self, forKey: .count)
        self.percentage = try c.decode(Double.self, forKey: .percentage)
    }
}

struct TopCategoriesPayload: Decodable, Equatable {
    let totalExpenses: Int
    let periodDays: Int
    let topCategories: [TopCategoryItem]

    enum CodingKeys: String, CodingKey {
        case totalExpenses  = "total_expenses"
        case periodDays     = "period_days"
        case topCategories  = "top_categories"
    }
}

enum TopCategoriesResult: Equatable {
    case ready(TopCategoriesPayload)
    case insufficientData(totalExpenses: Int)
}
