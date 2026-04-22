import Foundation

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
}
