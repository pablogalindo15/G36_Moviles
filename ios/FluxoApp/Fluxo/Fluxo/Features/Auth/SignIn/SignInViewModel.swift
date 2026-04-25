import Foundation
import Combine

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isPasswordVisible = false

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthApplicationService

    init(authService: AuthApplicationService) {
        self.authService = authService
    }

    func signIn() async -> AuthenticatedUser? {
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your email."
            return nil
        }

        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let user = try await authService.signIn(
                request: SignInDTO(
                    email: trimmedEmail,
                    password: password
                )
            )
            return user
        } catch {
            if ConnectivitySupport.isConnectivityIssue(error) {
                errorMessage = ConnectivitySupport.requiresInternetMessage(for: "Sign in")
            } else {
                errorMessage = error.localizedDescription
            }
            return nil
        }
    }
}
