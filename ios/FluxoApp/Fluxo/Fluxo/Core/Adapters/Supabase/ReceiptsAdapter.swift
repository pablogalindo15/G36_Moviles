import Foundation

final class ReceiptsAdapter {
    private let httpClient: SupabaseHTTPClient

    init(httpClient: SupabaseHTTPClient) {
        self.httpClient = httpClient
    }

    func uploadReceipt(
        accessToken: String,
        userId: UUID,
        expenseId: UUID,
        imageData: Data
    ) async throws -> String {
        let objectPath = Self.objectPath(userId: userId, expenseId: expenseId)
        let encodedPath = Self.encodedPath(from: objectPath)

        let (data, response) = try await httpClient.requestRaw(
            path: "/storage/v1/object/receipts/\(encodedPath)",
            method: "POST",
            body: imageData,
            contentType: "image/jpeg",
            authToken: accessToken,
            additionalHeaders: [
                "x-upsert": "true",
                "cache-control": "2592000",
            ]
        )
        guard (200...299).contains(response.statusCode) else {
            throw ReceiptStorageError.uploadFailed(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        return objectPath
    }

    func downloadReceipt(
        accessToken: String,
        userId: UUID,
        expenseId: UUID
    ) async throws -> Data? {
        let objectPath = Self.objectPath(userId: userId, expenseId: expenseId)
        let encodedPath = Self.encodedPath(from: objectPath)

        let (data, response) = try await httpClient.requestRaw(
            path: "/storage/v1/object/authenticated/receipts/\(encodedPath)",
            method: "GET",
            authToken: accessToken
        )

        if response.statusCode == 404 {
            return nil
        }

        guard (200...299).contains(response.statusCode) else {
            throw ReceiptStorageError.downloadFailed(
                statusCode: response.statusCode,
                body: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        return data
    }

    static func objectPath(userId: UUID, expenseId: UUID) -> String {
        "\(userId.uuidString.lowercased())/\(expenseId.uuidString.lowercased())/receipt.jpg"
    }

    private static func encodedPath(from objectPath: String) -> String {
        objectPath
            .split(separator: "/")
            .map { segment in
                String(segment).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(segment)
            }
            .joined(separator: "/")
    }
}

enum ReceiptStorageError: LocalizedError {
    case uploadFailed(statusCode: Int, body: String)
    case downloadFailed(statusCode: Int, body: String)

    var statusCode: Int {
        switch self {
        case .uploadFailed(let statusCode, _), .downloadFailed(let statusCode, _):
            return statusCode
        }
    }

    var errorDescription: String? {
        switch self {
        case .uploadFailed(let statusCode, let body):
            return "Receipt upload failed (\(statusCode)): \(body)"
        case .downloadFailed(let statusCode, let body):
            return "Receipt download failed (\(statusCode)): \(body)"
        }
    }
}
