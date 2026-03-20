import Foundation

final class PlanAdapter {
    private let httpClient: SupabaseHTTPClient

    init(httpClient: SupabaseHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchLatestFinancialSetup(accessToken: String, userId: String) async throws -> FinancialSetupRow? {
        let (data, response) = try await httpClient.requestJSON(
            path: "/rest/v1/financial_setups",
            method: "GET",
            authToken: accessToken,
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard (200...299).contains(response.statusCode) else {
            throw PostgrestAdapterError.backend(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        let rows = try JSONDecoder().decode([FinancialSetupRow].self, from: data)

        return rows.first
    }

    func fetchLatestGeneratedPlan(accessToken: String, userId: String) async throws -> GeneratedPlanDTO? {
        let (data, response) = try await httpClient.requestJSON(
            path: "/rest/v1/generated_plans",
            method: "GET",
            authToken: accessToken,
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "order", value: "generated_at.desc"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard (200...299).contains(response.statusCode) else {
            throw PostgrestAdapterError.backend(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        let rows = try JSONDecoder().decode([GeneratedPlanDTO].self, from: data)

        return rows.first
    }
}
