import Foundation

final class AuthApplicationService {
    private let authAdapter: AuthAdapter
    private let profileAdapter: ProfileAdapter
    private let storageAdapter: StorageAdapter

    init(
        authAdapter: AuthAdapter,
        profileAdapter: ProfileAdapter,
        storageAdapter: StorageAdapter
    ) {
        self.authAdapter = authAdapter
        self.profileAdapter = profileAdapter
        self.storageAdapter = storageAdapter
    }

    func signIn(request: SignInDTO) async throws -> AuthenticatedUser {
        try await authAdapter.signIn(request)
    }

    func createAccount(
        request: SignUpDTO,
        avatarJPEGData: Data?
    ) async throws -> AuthenticatedUser {
        // 1) Create auth user + session.
        let user = try await authAdapter.signUp(request)
        let accessToken = try await authAdapter.currentAccessToken()

        var avatarPath: String?
        if let avatarJPEGData {
            // 2) Optional avatar upload to Storage bucket "avatars".
            avatarPath = try await storageAdapter.uploadAvatar(
                accessToken: accessToken,
                userId: user.id,
                imageData: avatarJPEGData
            )
        }

        // 3) Persist profile row in Postgres.
        try await profileAdapter.saveProfile(
            accessToken: accessToken,
            userId: user.id,
            dto: SaveProfileDTO(
                full_name: request.full_name,
                avatar_url: avatarPath
            )
        )

        return user
    }

    func restoreSession() async -> AuthenticatedUser? {
        await authAdapter.restoreAuthenticatedUser()
    }

    func signOut() async throws {
        try await authAdapter.signOut()
    }
}
