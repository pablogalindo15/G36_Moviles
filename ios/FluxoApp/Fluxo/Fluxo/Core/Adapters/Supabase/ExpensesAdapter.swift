import Foundation

struct ExpenseUpdatePatch: Encodable {
    var amount: Decimal?
    var category: ExpenseCategory?
    var note: String?
    var occurredAt: Date?

    enum CodingKeys: String, CodingKey {
        case amount
        case category
        case note
        case occurredAt = "occurred_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(amount, forKey: .amount)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(occurredAt, forKey: .occurredAt)
    }
}

final class ExpensesAdapter {
    private let httpClient: SupabaseHTTPClient

    init(httpClient: SupabaseHTTPClient) {
        self.httpClient = httpClient
    }

    func insertExpense(_ request: ExpenseCreateRequest, accessToken: String) async throws -> Expense {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let body = try encoder.encode(request)
        let (data, response) = try await httpClient.requestRaw(
            path: "/rest/v1/expenses",
            method: "POST",
            body: body,
            contentType: "application/json",
            authToken: accessToken,
            additionalHeaders: ["Prefer": "return=representation"]
        )
        guard (200...299).contains(response.statusCode) else {
            throw PostgrestAdapterError.backend(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows = try decoder.decode([Expense].self, from: data)
        guard let expense = rows.first else {
            throw PostgrestAdapterError.backend(
                statusCode: response.statusCode,
                body: "Insert returned empty array"
            )
        }
        return expense
    }

    func fetchExpenses(userId: UUID, accessToken: String) async throws -> [Expense] {
        let (data, response) = try await httpClient.requestRaw(
            path: "/rest/v1/expenses",
            method: "GET",
            authToken: accessToken,
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString.lowercased())"),
                URLQueryItem(name: "order", value: "occurred_at.desc"),
            ]
        )
        guard (200...299).contains(response.statusCode) else {
            throw PostgrestAdapterError.backend(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Expense].self, from: data)
    }

    func updateExpense(id: UUID, patch: ExpenseUpdatePatch, accessToken: String) async throws -> Expense {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let body = try encoder.encode(patch)
        let (data, response) = try await httpClient.requestRaw(
            path: "/rest/v1/expenses",
            method: "PATCH",
            body: body,
            contentType: "application/json",
            authToken: accessToken,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())")
            ],
            additionalHeaders: ["Prefer": "return=representation"]
        )
        guard (200...299).contains(response.statusCode) else {
            throw PostgrestAdapterError.backend(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows = try decoder.decode([Expense].self, from: data)
        guard let expense = rows.first else {
            throw PostgrestAdapterError.backend(
                statusCode: response.statusCode,
                body: "Update returned empty array"
            )
        }
        return expense
    }

    func deleteExpense(id: UUID, accessToken: String) async throws {
        let (data, response) = try await httpClient.requestRaw(
            path: "/rest/v1/expenses",
            method: "DELETE",
            authToken: accessToken,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())")
            ]
        )
        guard response.statusCode == 204 || response.statusCode == 200 else {
            throw PostgrestAdapterError.backend(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
    }
}
