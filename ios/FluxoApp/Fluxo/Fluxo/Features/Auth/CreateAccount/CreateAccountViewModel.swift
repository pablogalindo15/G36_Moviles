import SwiftUI
import UIKit
import Combine

@MainActor
final class CreateAccountViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var acceptedTerms = false

    @Published var selectedImage: UIImage?
    @Published var isShowingImagePicker = false
    @Published var pickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @Published var sensorFallbackMessage: String?

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthApplicationService
    private let cameraFacade: CameraFacade

    init(
        authService: AuthApplicationService,
        cameraFacade: CameraFacade
    ) {
        self.authService = authService
        self.cameraFacade = cameraFacade
    }

    func openPhotoCapture() {
        pickerSourceType = cameraFacade.preferredSourceType()
        sensorFallbackMessage = cameraFacade.fallbackHint
        isShowingImagePicker = true
    }

    func savePickedImage(_ image: UIImage?) {
        selectedImage = image
    }

    func createAccount() async -> AuthenticatedUser? {
        errorMessage = nil
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter your full name."
            return nil
        }
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your email."
            return nil
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return nil
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return nil
        }
        guard acceptedTerms else {
            errorMessage = "Please accept terms and privacy to continue."
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let imageData = cameraFacade.jpegData(from: selectedImage)
            let user = try await authService.createAccount(
                request: SignUpDTO(
                    full_name: trimmedName,
                    email: trimmedEmail,
                    password: password
                ),
                avatarJPEGData: imageData
            )
            return user
        } catch {
            if ConnectivitySupport.isConnectivityIssue(error) {
                errorMessage = ConnectivitySupport.requiresInternetMessage(for: "Create account")
            } else {
                errorMessage = error.localizedDescription
            }
            return nil
        }
    }
}
