import Foundation

final class SupabaseHTTPClient {
    private let config: FrontendConfig
    private let urlSession: URLSession
    private let requestTimeoutSeconds: TimeInterval = 6

    init(config: FrontendConfig, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func requestJSON(
        path: String,
        method: String,
        body: Encodable? = nil,
        authToken: String? = nil,
        queryItems: [URLQueryItem] = [],
        additionalHeaders: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        let requestBody = try body.map { try JSONEncoder().encode(AnyEncodable($0)) }
        return try await requestRaw(
            path: path,
            method: method,
            body: requestBody,
            contentType: "application/json",
            authToken: authToken,
            queryItems: queryItems,
            additionalHeaders: additionalHeaders
        )
    }

    func requestRaw(
        path: String,
        method: String,
        body: Data? = nil,
        contentType: String? = nil,
        authToken: String? = nil,
        queryItems: [URLQueryItem] = [],
        additionalHeaders: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(url: config.supabaseURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseHTTPClientError.invalidBaseURL
        }

        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        components.path = normalizedPath
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw SupabaseHTTPClientError.invalidRequestURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = requestTimeoutSeconds
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        for (header, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseHTTPClientError.invalidResponse
        }
        return (data, httpResponse)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

enum SupabaseHTTPClientError: LocalizedError {
    case invalidBaseURL
    case invalidRequestURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid Supabase base URL."
        case .invalidRequestURL:
            return "Could not create a valid request URL."
        case .invalidResponse:
            return "Invalid HTTP response from Supabase."
        }
    }
}
