import Foundation

final class FunctionsAdapter {
    private let httpClient: SupabaseHTTPClient

    init(httpClient: SupabaseHTTPClient) {
        self.httpClient = httpClient
    }

    func generateFirstPlan(
        request: GenerateFirstPlanRequestDTO,
        accessToken: String
    ) async throws -> GenerateFirstPlanResponseDTO {
        let (data, response) = try await httpClient.requestJSON(
            path: "/functions/v1/generate-first-plan",
            method: "POST",
            body: request,
            authToken: accessToken
        )

        guard (200...299).contains(response.statusCode) else {
            let backendError = try? JSONDecoder().decode(FunctionErrorPayload.self, from: data)
            let rawBody = String(data: data, encoding: .utf8)
            let message = backendError?.error
                ?? backendError?.message
                ?? rawBody
                ?? "Unknown backend error"
            throw FunctionsAdapterError.backend(
                statusCode: response.statusCode,
                message: message,
                details: backendError?.details
            )
        }

        return try JSONDecoder().decode(GenerateFirstPlanResponseDTO.self, from: data)
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
