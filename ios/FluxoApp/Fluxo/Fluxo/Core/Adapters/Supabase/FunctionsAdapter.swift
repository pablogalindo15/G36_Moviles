import Foundation

final class FunctionsAdapter {
    private let httpClient: SupabaseHTTPClient

    init(httpClient: SupabaseHTTPClient) {
        self.httpClient = httpClient
    }

    func getComparativeSpending(weekEnd: Date?, accessToken: String) async throws -> Data {
        let body = ComparativeSpendingRequestBody(week_end: weekEnd.map { Self.iso8601.string(from: $0) })
        return try await requestData(
            path: "/functions/v1/get-bq-comparative-spending",
            body: body,
            accessToken: accessToken
        )
    }

    func getTopCategories(accessToken: String) async throws -> Data {
        return try await requestData(
            path: "/functions/v1/get-bq-top-categories",
            accessToken: accessToken
        )
    }

    func getSavingsProjection(currentDate: Date?, accessToken: String) async throws -> Data {
        let body = SavingsProjectionRequestBody(current_date: currentDate.map { Self.iso8601.string(from: $0) })
        return try await requestData(
            path: "/functions/v1/get-bq-savings-projection",
            body: body,
            accessToken: accessToken
        )
    }

    func generateFirstPlan(
        request: GenerateFirstPlanRequestDTO,
        accessToken: String
    ) async throws -> GenerateFirstPlanResponseDTO {
        let data = try await requestData(
            path: "/functions/v1/generate-first-plan",
            body: request,
            accessToken: accessToken
        )
        return try JSONDecoder().decode(GenerateFirstPlanResponseDTO.self, from: data)
    }
}

private extension FunctionsAdapter {
    func requestData(path: String, accessToken: String) async throws -> Data {
        let (data, response) = try await httpClient.requestJSON(
            path: path,
            method: "POST",
            authToken: accessToken
        )
        return try validatedData(data, response: response)
    }

    func requestData<Body: Encodable>(
        path: String,
        body: Body,
        accessToken: String
    ) async throws -> Data {
        let (data, response) = try await httpClient.requestJSON(
            path: path,
            method: "POST",
            body: body,
            authToken: accessToken
        )
        return try validatedData(data, response: response)
    }

    func validatedData(_ data: Data, response: HTTPURLResponse) throws -> Data {
        guard (200...299).contains(response.statusCode) else {
            throw backendError(from: data, statusCode: response.statusCode)
        }
        return data
    }

    func backendError(from data: Data, statusCode: Int) -> FunctionsAdapterError {
        let payload = try? JSONDecoder().decode(FunctionErrorPayload.self, from: data)
        let rawBody = String(data: data, encoding: .utf8)
        return .backend(
            statusCode: statusCode,
            message: payload?.error ?? payload?.message ?? rawBody ?? "Unknown backend error",
            details: payload?.details
        )
    }

    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

/// Body for get-bq-comparative-spending.
/// Encodes `week_end` only when present so the server receives {} when nil.
private struct ComparativeSpendingRequestBody: Encodable {
    let week_end: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let week_end {
            try container.encode(week_end, forKey: .week_end)
        }
    }

    enum CodingKeys: String, CodingKey {
        case week_end
    }
}

/// Body for get-bq-savings-projection.
/// Encodes `current_date` only when present so the server receives {} when nil.
private struct SavingsProjectionRequestBody: Encodable {
    let current_date: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let current_date {
            try container.encode(current_date, forKey: .current_date)
        }
    }

    enum CodingKeys: String, CodingKey {
        case current_date
    }
}

private struct FunctionErrorPayload: Decodable {
    let error: String?
    let message: String?
    let details: String?
}

enum FunctionsAdapterError: LocalizedError {
    case backend(statusCode: Int, message: String, details: String?)

    var errorDescription: String? {
        switch self {
        case .backend(let statusCode, let message, let details):
            if statusCode == 401 {
                return "Session expired or invalid. Please sign out and sign in again."
            }
            if let details, !details.isEmpty {
                return "Function error (\(statusCode)): \(message). \(details)"
            }
            return "Function error (\(statusCode)): \(message)"
        }
    }
}
