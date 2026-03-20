import SwiftUI

struct SignInView: View {
    private let authService: AuthApplicationService
    private let cameraFacade: CameraFacade
    private let onSignedIn: (AuthenticatedUser) -> Void

    @StateObject private var viewModel: SignInViewModel

    init(
        authService: AuthApplicationService,
        cameraFacade: CameraFacade,
        onSignedIn: @escaping (AuthenticatedUser) -> Void
    ) {
        self.authService = authService
        self.cameraFacade = cameraFacade
        self.onSignedIn = onSignedIn
        _viewModel = StateObject(wrappedValue: SignInViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FluxoTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        brandingHeader
                        credentialFields
                        actionBlock
                        createAccountLink
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }

                if viewModel.isLoading {
                    LoadingOverlay(title: "Signing you in...")
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var brandingHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(FluxoTheme.primary.opacity(0.16))
                    .frame(width: 72, height: 72)
                Text("F")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(FluxoTheme.primary)
            }

            Text("Welcome back")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(FluxoTheme.titleText)

            Text("Sign in to continue building your first smart finance plan.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(FluxoTheme.secondaryText)
        }
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private var credentialFields: some View {
        VStack(spacing: 14) {
            FluxoInputField(title: "Email") {
                TextField("name@university.edu", text: $viewModel.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
            }

            FluxoInputField(title: "Password") {
                HStack(spacing: 8) {
                    if viewModel.isPasswordVisible {
                        TextField("••••••••", text: $viewModel.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("••••••••", text: $viewModel.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Button(viewModel.isPasswordVisible ? "Hide" : "Show") {
                        viewModel.isPasswordVisible.toggle()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(FluxoTheme.primary)
                }
            }
        }
    }

    private var actionBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(FluxoTheme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Sign In") {
                Task {
                    if let user = await viewModel.signIn() {
                        onSignedIn(user)
                    }
                }
            }
            .buttonStyle(FluxoPrimaryButtonStyle(isDisabled: viewModel.isLoading))
            .disabled(viewModel.isLoading)

            Text("Forgot password?")
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var createAccountLink: some View {
        VStack(spacing: 8) {
            Text("New to Fluxo?")
                .font(.footnote)
                .foregroundColor(FluxoTheme.secondaryText)

            NavigationLink {
                CreateAccountView(
                    authService: authService,
                    cameraFacade: cameraFacade
                ) { user in
                    onSignedIn(user)
                }
            } label: {
                Text("Create Account")
                    .font(.headline)
                    .foregroundColor(FluxoTheme.primary)
                    .padding(.vertical, 4)
            }
        }
        .padding(.top, 2)
    }
}
