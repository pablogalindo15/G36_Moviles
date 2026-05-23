import Foundation
import SwiftData

@Model
final class InsightSnapshot {
    var bqType: String
    var userId: UUID
    var payload: Data
    var computedAt: Date

    init(bqType: String, userId: UUID, payload: Data, computedAt: Date = Date()) {
        self.bqType = bqType
        self.userId = userId
        self.payload = payload
        self.computedAt = computedAt
    }
}
