import Foundation

final class AuthApplicationService {
    private let authAdapter: AuthAdapter
    private let profileAdapter: ProfileAdapter
    private let storageAdapter: StorageAdapter
    private let preferencesAdapter: PreferencesAdapter

    init(
        authAdapter: AuthAdapter,
        profileAdapter: ProfileAdapter,
        storageAdapter: StorageAdapter,
        preferencesAdapter: PreferencesAdapter
    ) {
        self.authAdapter = authAdapter
        self.profileAdapter = profileAdapter
        self.storageAdapter = storageAdapter
        self.preferencesAdapter = preferencesAdapter
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
        var pendingNotice: String?

        var avatarPath: String?
        if let avatarJPEGData {
            // 2) Optional avatar upload to Storage bucket "avatars".
            do {
                avatarPath = try await storageAdapter.uploadAvatar(
                    accessToken: accessToken,
                    userId: user.id,
                    imageData: avatarJPEGData
                )
            } catch {
                pendingNotice = "Your account was created, but we couldn't upload your profile photo. You can continue and finish it later."
            }
        }

        // 3) Persist profile row in Postgres.
        // Once the auth user exists, profile sync becomes best-effort so we do not
        // leave the user blocked in a partial-success state.
        do {
            try await profileAdapter.saveProfile(
                accessToken: accessToken,
                userId: user.id,
                dto: SaveProfileDTO(
                    full_name: request.full_name,
                    avatar_url: avatarPath
                )
            )
        } catch {
            pendingNotice = "Your account was created, but we couldn't finish syncing your profile. You can continue and try again later."
        }

        if let pendingNotice {
            preferencesAdapter.setPendingUserNotice(pendingNotice)
        }

        return user
    }

    func restoreSession() async -> AuthenticatedUser? {
        await authAdapter.restoreAuthenticatedUser()
    }

    func signOut() async throws {
        try await authAdapter.signOut()
    }
}
