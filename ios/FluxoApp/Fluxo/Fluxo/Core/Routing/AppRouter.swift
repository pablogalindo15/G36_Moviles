import Foundation
import Combine

@MainActor
final class AppRouter: ObservableObject {
    enum RootDestination {
        case loading
        case signIn
        case setupPlan
    }

    @Published private(set) var root: RootDestination = .loading
    @Published private(set) var currentUser: AuthenticatedUser?

    private let authService: AuthApplicationService

    init(authService: AuthApplicationService) {
        self.authService = authService
    }

    func bootstrap() async {
        // Try to restore a previous session.
        root = .loading
        if let user = await authService.restoreSession() {
            currentUser = user
            root = .setupPlan
        } else {
            currentUser = nil
            root = .signIn
        }
    }

    func handleSignedIn(_ user: AuthenticatedUser) {
        currentUser = user
        root = .setupPlan
    }

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            // Keep UX simple: route user out even if remote signout fails.
        }
        currentUser = nil
        root = .signIn
    }
}
