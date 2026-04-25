import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        Group {
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
                        authAdapter: container.authAdapter,
                        preferencesAdapter: container.preferencesAdapter,
                        onPlanGenerated: {
                            container.router.goToDashboard()
                        },
                        onSignOut: handleSignOut
                    )
                } else {
                    loadingView
                }
            case .dashboard:
                DashboardView(
                    viewModel: DashboardViewModel(
                        planService: container.planService,
                        expensesService: container.expensesService,
                        comparativeSpendingService: container.comparativeSpendingService,
                        topCategoriesService: container.topCategoriesService,
                        savingsProjectionService: container.savingsProjectionService,
                        preferencesAdapter: container.preferencesAdapter,
                        expensesFileAdapter: container.expensesFileAdapter,
                        onSignOut: handleSignOut
                    )
                )
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

    private func handleSignOut() {
        container.planSnapshotCache.clear()
        container.preferencesAdapter.clearPendingUserNotice()
        container.preferencesAdapter.clearSetupPlanDraft()
        container.preferencesAdapter.clearExpenseDraft()
        Task { await container.router.signOut() }
    }
}
