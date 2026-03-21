import Foundation

final class StorageAdapter {
    private let httpClient: SupabaseHTTPClient

    init(httpClient: SupabaseHTTPClient) {
        self.httpClient = httpClient
    }

    func uploadAvatar(accessToken: String, userId: String, imageData: Data) async throws -> String {
        let objectPath = "\(userId)/avatar.jpg"
        let encodedPath = objectPath
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")

        let (data, response) = try await httpClient.requestRaw(
            path: "/storage/v1/object/avatars/\(encodedPath)",
            method: "POST",
            body: imageData,
            contentType: "image/jpeg",
            authToken: accessToken,
            additionalHeaders: [
                "x-upsert": "true",
                "cache-control": "3600"
            ]
        )
        guard (200...299).contains(response.statusCode) else {
            throw StorageAdapterError.uploadFailed(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        return objectPath
    }
}

enum StorageAdapterError: LocalizedError {
    case uploadFailed(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .uploadFailed(let statusCode, let body):
            return "Avatar upload failed (\(statusCode)): \(body)"
        }
    }
}
