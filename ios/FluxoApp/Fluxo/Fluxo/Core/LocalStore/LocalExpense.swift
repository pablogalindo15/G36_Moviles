import Foundation
import SwiftData

@Model
final class LocalExpense {
    @Attribute(.unique) var clientUuid: UUID
    var id: UUID
    var userId: UUID
    var amount: Decimal
    var currency: String
    var categoryRaw: String       // ExpenseCategory.rawValue — SwiftData doesn't support enums directly
    var note: String?
    var occurredAt: Date
    var createdAt: Date

    init(
        id: UUID,
        userId: UUID,
        amount: Decimal,
        currency: String,
        categoryRaw: String,
        note: String?,
        occurredAt: Date,
        createdAt: Date,
        clientUuid: UUID
    ) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.currency = currency
        self.categoryRaw = categoryRaw
        self.note = note
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.clientUuid = clientUuid
    }

    convenience init(from dto: Expense) {
        self.init(
            id: dto.id,
            userId: dto.userId,
            amount: dto.amount,
            currency: dto.currency,
            categoryRaw: dto.category.rawValue,
            note: dto.note,
            occurredAt: dto.occurredAt,
            createdAt: dto.createdAt,
            clientUuid: dto.clientUuid
        )
    }

    func toDTO() -> Expense {
        Expense(
            id: id,
            userId: userId,
            amount: amount,
            currency: currency,
            category: ExpenseCategory(rawValue: categoryRaw) ?? .other,
            note: note,
            occurredAt: occurredAt,
            createdAt: createdAt,
            clientUuid: clientUuid
        )
    }
}
