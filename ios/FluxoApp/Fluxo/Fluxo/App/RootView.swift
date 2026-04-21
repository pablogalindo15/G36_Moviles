import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        Group {
            // Single router decides which one of the 3 sprint views is visible.
            switch container.router.root {
            case .loading:
                loadingView
            case .signIn:
                SignInView(
                    authService: container.authService,
                    createAccountDestination: {
                        AnyView(
                            CreateAccountView(
                                authService: container.authService,
                                cameraFacade: container.cameraFacade
                            ) { user in
                                container.router.handleSignedIn(user)
                            }
                        )
                    }
                ) { user in
                    container.router.handleSignedIn(user)
                }
            case .setupPlan:
                if let user = container.router.currentUser {
                    SetupPlanView(
                        user: user,
                        planService: container.planService,
                        locationService: container.locationService,
                        locationAdapter: container.locationAdapter,
                        authAdapter: container.authAdapter
                    ) {
                        Task {
                            await container.router.signOut()
                        }
                    }
                } else {
                    loadingView
                }
            }
        }
        .background(FluxoTheme.background.ignoresSafeArea())
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading your Fluxo session...")
                .font(.subheadline)
                .foregroundColor(FluxoTheme.secondaryText)
        }
    }
}
