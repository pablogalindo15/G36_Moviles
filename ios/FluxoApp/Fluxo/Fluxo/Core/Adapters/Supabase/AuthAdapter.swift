import Foundation

final class AuthAdapter {
    private let httpClient: SupabaseHTTPClient
    private let keychain: KeychainAdapter
    private let sessionStore: AuthSessionStore

    private enum KeychainKeys {
        static let accessToken  = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
    }

    init(httpClient: SupabaseHTTPClient, keychain: KeychainAdapter) {
        self.httpClient = httpClient
        self.keychain = keychain
        self.sessionStore = AuthSessionStore(keychain: keychain)
        runMigrationIfNeeded()
    }

    /// One-shot migration: moves tokens from the legacy UserDefaults store to Keychain.
    /// Safe to call on every init — the loop is a no-op once UserDefaults keys are gone.
    private func runMigrationIfNeeded() {
        let legacyKeys: [String: String] = [
            "fluxo.auth.accessToken":  KeychainKeys.accessToken,
            "fluxo.auth.refreshToken": KeychainKeys.refreshToken
        ]
        for (legacyKey, keychainKey) in legacyKeys {
            if let legacyValue = UserDefaults.standard.string(forKey: legacyKey) {
                try? keychain.save(legacyValue, forKey: keychainKey)
                UserDefaults.standard.removeObject(forKey: legacyKey)
            }
        }
    }

    func signIn(_ dto: SignInDTO) async throws -> AuthenticatedUser {
        let body = AuthEmailPasswordRequest(email: dto.email, password: dto.password)
        let (data, response) = try await httpClient.requestJSON(
            path: "/auth/v1/token",
            method: "POST",
            body: body,
            queryItems: [URLQueryItem(name: "grant_type", value: "password")]
        )
        guard (200...299).contains(response.statusCode) else {
            throw try parseBackendError(data: data, statusCode: response.statusCode)
        }

        let payload = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        let normalizedAccessToken = normalizeAccessToken(payload.access_token)
        guard isLikelyJWT(normalizedAccessToken) else {
            throw AuthAdapterError.invalidSessionToken
        }
        sessionStore.save(
            accessToken: normalizedAccessToken,
            refreshToken: payload.refresh_token
        )
        return AuthenticatedUser(id: payload.user.id, email: payload.user.email)
    }

    func signUp(_ dto: SignUpDTO) async throws -> AuthenticatedUser {
        let body = AuthSignUpRequest(email: dto.email, password: dto.password)
        let (data, response) = try await httpClient.requestJSON(
            path: "/auth/v1/signup",
            method: "POST",
            body: body
        )
        guard (200...299).contains(response.statusCode) else {
            throw try parseBackendError(data: data, statusCode: response.statusCode)
        }

        let payload = try JSONDecoder().decode(AuthSignUpResponse.self, from: data)

        if
            let rawAccessToken = payload.access_token,
            let rawRefreshToken = payload.refresh_token
        {
            let accessToken = normalizeAccessToken(rawAccessToken)
            let refreshToken = rawRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isLikelyJWT(accessToken), !refreshToken.isEmpty else {
                return try await signIn(SignInDTO(email: dto.email, password: dto.password))
            }

            sessionStore.save(accessToken: accessToken, refreshToken: refreshToken)
            if let user = payload.user {
                return AuthenticatedUser(id: user.id, email: user.email)
            }
        }

        // Fallback for setups where signup does not return an immediate session.
        return try await signIn(SignInDTO(email: dto.email, password: dto.password))
    }

    func restoreAuthenticatedUser() async -> AuthenticatedUser? {
        // Read cached token from local store and validate with Supabase.
        guard
            let storedToken = sessionStore.accessToken
        else { return nil }

        let token = normalizeAccessToken(storedToken)
        guard isLikelyJWT(token) else {
            sessionStore.clear()
            return nil
        }
        do {
            let (data, response) = try await httpClient.requestJSON(
                path: "/auth/v1/user",
                method: "GET",
                authToken: token
            )
            guard (200...299).contains(response.statusCode) else {
                sessionStore.clear()
                return nil
            }
            let user = try JSONDecoder().decode(AuthUserResponse.self, from: data)
            return AuthenticatedUser(id: user.id, email: user.email)
        } catch {
            sessionStore.clear()
            return nil
        }
    }

    func currentUserId() throws -> UUID {
        guard let rawToken = sessionStore.accessToken else {
            throw AuthAdapterError.missingSession
        }
        let token = normalizeAccessToken(rawToken)
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { throw AuthAdapterError.invalidSessionToken }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }

        guard
            let data = Data(base64Encoded: base64),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sub = json["sub"] as? String,
            let uuid = UUID(uuidString: sub)
        else {
            throw AuthAdapterError.invalidSessionToken
        }
        return uuid
    }

    func currentAccessToken() async throws -> String {
        guard
            let rawToken = sessionStore.accessToken
        else {
            throw AuthAdapterError.missingSession
        }
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedToken = normalizeAccessToken(token)
        guard isLikelyJWT(normalizedToken) else {
            sessionStore.clear()
            throw AuthAdapterError.invalidSessionToken
        }
        return normalizedToken
    }

    func signOut() async throws {
        if let token = sessionStore.accessToken {
            _ = try? await httpClient.requestJSON(
                path: "/auth/v1/logout",
                method: "POST",
                authToken: token
            )
        }
        sessionStore.clear()
    }

    func refreshSession() async throws -> String {
        guard
            let rawRefreshToken = sessionStore.refreshToken
        else {
            throw AuthAdapterError.missingSession
        }

        let refreshToken = rawRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !refreshToken.isEmpty else {
            sessionStore.clear()
            throw AuthAdapterError.missingSession
        }

        let body = AuthRefreshRequest(refresh_token: refreshToken)
        let (data, response) = try await httpClient.requestJSON(
            path: "/auth/v1/token",
            method: "POST",
            body: body,
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")]
        )
        guard (200...299).contains(response.statusCode) else {
            sessionStore.clear()
            throw try parseBackendError(data: data, statusCode: response.statusCode)
        }

        let payload = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        let accessToken = normalizeAccessToken(payload.access_token)
        guard isLikelyJWT(accessToken) else {
            sessionStore.clear()
            throw AuthAdapterError.invalidSessionToken
        }

        sessionStore.save(accessToken: accessToken, refreshToken: payload.refresh_token)
        return accessToken
    }

    private func parseBackendError(data: Data, statusCode: Int) throws -> AuthAdapterError {
        if let payload = try? JSONDecoder().decode(AuthErrorPayload.self, from: data) {
            return AuthAdapterError.backend(
                statusCode: statusCode,
                message: payload.msg ?? payload.error_description ?? payload.error ?? "Unknown auth error"
            )
        }
        return AuthAdapterError.backend(
            statusCode: statusCode,
            message: "Unknown auth error"
        )
    }

    private func isLikelyJWT(_ token: String) -> Bool {
        let pieces = token.split(separator: ".")
        return pieces.count == 3 && token.count > 20
    }

    private func normalizeAccessToken(_ raw: String) -> String {
        // Defensive normalization because tokens can come with "Bearer " or quotes.
        var token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().hasPrefix("bearer ") {
            token = String(token.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if token.hasPrefix("\""), token.hasSuffix("\""), token.count > 2 {
            token = String(token.dropFirst().dropLast())
        }
        return token
    }
}

private struct AuthEmailPasswordRequest: Encodable {
    let email: String
    let password: String
}

private struct AuthSignUpRequest: Encodable {
    let email: String
    let password: String
}

private struct AuthRefreshRequest: Encodable {
    let refresh_token: String
}

private struct AuthTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let user: AuthUserResponse
}

private struct AuthSignUpResponse: Decodable {
    let access_token: String?
    let refresh_token: String?
    let user: AuthUserResponse?
}

private struct AuthUserResponse: Decodable {
    let id: String
    let email: String?
}

private struct AuthErrorPayload: Decodable {
    let error: String?
    let error_description: String?
    let msg: String?
}

private final class AuthSessionStore {
    private let keychain: KeychainAdapter
    private let accessTokenKey  = "auth.accessToken"
    private let refreshTokenKey = "auth.refreshToken"

    init(keychain: KeychainAdapter) {
        self.keychain = keychain
    }

    var accessToken: String? {
        keychain.load(forKey: accessTokenKey)
    }

    var refreshToken: String? {
        keychain.load(forKey: refreshTokenKey)
    }

    func save(accessToken: String, refreshToken: String) {
        try? keychain.save(accessToken,  forKey: accessTokenKey)
        try? keychain.save(refreshToken, forKey: refreshTokenKey)
    }

    func clear() {
        try? keychain.delete(forKey: accessTokenKey)
        try? keychain.delete(forKey: refreshTokenKey)
    }
}

enum AuthAdapterError: LocalizedError {
    case missingSession
    case invalidSessionToken
    case backend(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "No active session found. Please sign in again."
        case .invalidSessionToken:
            return "Invalid local session token. Please sign in again."
        case .backend(let statusCode, let message):
            return "Auth error (\(statusCode)): \(message)"
        }
    }
}
