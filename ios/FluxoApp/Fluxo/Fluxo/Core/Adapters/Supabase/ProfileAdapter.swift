import Foundation

final class ProfileAdapter {
    private let httpClient: SupabaseHTTPClient

    init(httpClient: SupabaseHTTPClient) {
        self.httpClient = httpClient
    }

    func saveProfile(accessToken: String, userId: String, dto: SaveProfileDTO) async throws {
        let payload = ProfileUpsertPayload(
            id: userId,
            full_name: dto.full_name,
            avatar_url: dto.avatar_url
        )

        let (data, response) = try await httpClient.requestJSON(
            path: "/rest/v1/profiles",
            method: "POST",
            body: payload,
            authToken: accessToken,
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            additionalHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )
        guard (200...299).contains(response.statusCode) else {
            throw PostgrestAdapterError.backend(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
    }
}

private struct ProfileUpsertPayload: Encodable {
    let id: String
    let full_name: String
    let avatar_url: String?
}

enum PostgrestAdapterError: LocalizedError {
    case backend(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .backend(let statusCode, let body):
            return "Database request failed (\(statusCode)): \(body)"
        }
    }
}
