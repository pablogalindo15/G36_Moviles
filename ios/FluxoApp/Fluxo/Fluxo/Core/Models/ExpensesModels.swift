import Foundation

enum ExpenseCategory: String, CaseIterable, Codable {
    case food
    case transport
    case entertainment
    case shopping
    case bills
    case health
    case other

    var displayName: String {
        switch self {
        case .food:          return "Food"
        case .transport:     return "Transport"
        case .entertainment: return "Entertainment"
        case .shopping:      return "Shopping"
        case .bills:         return "Bills"
        case .health:        return "Health"
        case .other:         return "Other"
        }
    }

    var icon: String {
        switch self {
        case .food:          return "fork.knife"
        case .transport:     return "car.fill"
        case .entertainment: return "gamecontroller.fill"
        case .shopping:      return "bag.fill"
        case .bills:         return "doc.text.fill"
        case .health:        return "heart.fill"
        case .other:         return "ellipsis.circle.fill"
        }
    }
}

struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let amount: Decimal
    let currency: String
    let category: ExpenseCategory
    let note: String?
    let occurredAt: Date
    let createdAt: Date
    let clientUuid: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case amount
        case currency
        case category
        case note
        case occurredAt  = "occurred_at"
        case createdAt   = "created_at"
        case clientUuid  = "client_uuid"
    }
}

struct ExpenseCreateRequest: Codable {
    let userId: UUID
    let amount: Decimal
    let currency: String
    let category: ExpenseCategory
    let note: String?
    let occurredAt: Date
    let clientUuid: UUID

    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case amount
        case currency
        case category
        case note
        case occurredAt = "occurred_at"
        case clientUuid = "client_uuid"
    }
}

struct ExpenseSummary: Equatable {
    let spentThisWeek: Decimal
    let spentSinceLastPaycheck: Decimal
    let weekStart: Date
    let lastPaycheckDate: Date
    let currency: String
}
