import SwiftUI

struct CreateAccountView: View {
    private let onAccountCreated: (AuthenticatedUser) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateAccountViewModel

    init(
        authService: AuthApplicationService,
        cameraFacade: CameraFacade,
        onAccountCreated: @escaping (AuthenticatedUser) -> Void
    ) {
        self.onAccountCreated = onAccountCreated
        _viewModel = StateObject(
            wrappedValue: CreateAccountViewModel(
                authService: authService,
                cameraFacade: cameraFacade
            )
        )
    }

    var body: some View {
        ZStack {
            FluxoTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    photoCaptureArea
                    fieldArea
                    termsArea
                    actionArea
                }
                .padding(20)
            }

            if viewModel.isLoading {
                LoadingOverlay(title: "Creating your account...")
            }
        }
        .navigationTitle("Create your account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isShowingImagePicker) {
            SystemImagePicker(sourceType: viewModel.pickerSourceType) { image in
                viewModel.savePickedImage(image)
            }
        }
    }

    private var photoCaptureArea: some View {
        VStack(alignment: .center, spacing: 12) {
            Group {
                if let selectedImage = viewModel.selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                        .foregroundColor(FluxoTheme.secondaryText.opacity(0.55))
                }
            }
            .frame(width: 110, height: 110)
            .background(FluxoTheme.cardBackground)
            .clipShape(Circle())
            .overlay(Circle().stroke(FluxoTheme.border, lineWidth: 1))

            Button("Capture profile photo") {
                viewModel.openPhotoCapture()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(FluxoTheme.primary)

            if let fallback = viewModel.sensorFallbackMessage {
                Text(fallback)
                    .font(.caption)
                    .foregroundColor(FluxoTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .fluxoCardContainer()
    }

    private var fieldArea: some View {
        VStack(spacing: 14) {
            FluxoInputField(title: "Full name") {
                TextField("Jane Doe", text: $viewModel.fullName)
                    .textInputAutocapitalization(.words)
            }

            FluxoInputField(title: "Email") {
                TextField("name@university.edu", text: $viewModel.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
            }

            FluxoInputField(title: "Password") {
                SecureField("At least 6 characters", text: $viewModel.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            FluxoInputField(title: "Confirm password") {
                SecureField("Repeat your password", text: $viewModel.confirmPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }

    private var termsArea: some View {
        Toggle(isOn: $viewModel.acceptedTerms) {
            Text("I accept Terms & Privacy")
                .font(.footnote)
                .foregroundColor(FluxoTheme.titleText)
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 4)
    }

    private var actionArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(FluxoTheme.error)
            }

            Button("Create account") {
                Task {
                    if let user = await viewModel.createAccount() {
                        onAccountCreated(user)
                    }
                }
            }
            .buttonStyle(FluxoPrimaryButtonStyle(isDisabled: viewModel.isLoading))
            .disabled(viewModel.isLoading)

            Button("Back to Sign In") {
                dismiss()
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(FluxoTheme.primary)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? FluxoTheme.primary : FluxoTheme.secondaryText)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

private extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}
