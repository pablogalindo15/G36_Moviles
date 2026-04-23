import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    let config: FrontendConfig

    let authService: AuthApplicationService
    let planService: PlanApplicationService
    let expensesService: ExpensesApplicationService
    let comparativeSpendingService: ComparativeSpendingService
    let topCategoriesService: TopCategoriesService
    let savingsProjectionService: SavingsProjectionService
    let localStore: LocalStore
    let planSnapshotCache: PlanSnapshotMemoryCache
    let cameraFacade: CameraFacade
    let locationService: LocationService
    let locationAdapter: LocationAdapter
    let keychainAdapter: KeychainAdapter
    let preferencesAdapter: PreferencesAdapter
    let expensesFileAdapter: ExpensesFileAdapter
    let authAdapter: AuthAdapter
    let router: AppRouter

    private var hasStarted = false
    private var cancellables = Set<AnyCancellable>()

    static func bootstrap() -> AppContainer {
        do {
            return try AppContainer()
        } catch {
            fatalError("Fluxo frontend boot failed: \(error.localizedDescription)")
        }
    }

    private init() throws {
        let config = try FrontendConfig.load()
        let httpClient = SupabaseHTTPClient(config: config)

        let keychainAdapter = KeychainAdapter()
        let preferencesAdapter = PreferencesAdapter()
        let expensesFileAdapter = ExpensesFileAdapter()
        let authAdapter = AuthAdapter(httpClient: httpClient, keychain: keychainAdapter)
        let profileAdapter = ProfileAdapter(httpClient: httpClient)
        let storageAdapter = StorageAdapter(httpClient: httpClient)
        let planAdapter = PlanAdapter(httpClient: httpClient)
        let functionsAdapter = FunctionsAdapter(httpClient: httpClient)
        let locationAdapter = LocationAdapter(httpClient: httpClient)
        let expensesAdapter = ExpensesAdapter(httpClient: httpClient)

        let localStore = LocalStore()
        let planSnapshotCache = PlanSnapshotMemoryCache()

        let authService = AuthApplicationService(
            authAdapter: authAdapter,
            profileAdapter: profileAdapter,
            storageAdapter: storageAdapter,
            preferencesAdapter: preferencesAdapter
        )
        let planService = PlanApplicationService(
            authAdapter: authAdapter,
            planAdapter: planAdapter,
            functionsAdapter: functionsAdapter,
            localStore: localStore,
            snapshotCache: planSnapshotCache
        )
        let expensesService = ExpensesApplicationService(
            expensesAdapter: expensesAdapter,
            authAdapter: authAdapter,
            localStore: localStore
        )
        let comparativeSpendingService = ComparativeSpendingService(
            functionsAdapter: functionsAdapter,
            authAdapter: authAdapter
        )
        let topCategoriesService = TopCategoriesService(
            functionsAdapter: functionsAdapter,
            authAdapter: authAdapter
        )
        let savingsProjectionService = SavingsProjectionService(
            functionsAdapter: functionsAdapter,
            authAdapter: authAdapter
        )

        self.config = config
        self.authService = authService
        self.planService = planService
        self.expensesService = expensesService
        self.comparativeSpendingService = comparativeSpendingService
        self.topCategoriesService = topCategoriesService
        self.savingsProjectionService = savingsProjectionService
        self.localStore = localStore
        self.planSnapshotCache = planSnapshotCache
        self.cameraFacade = CameraFacade()
        self.locationService = LocationService()
        self.locationAdapter = locationAdapter
        self.keychainAdapter = keychainAdapter
        self.preferencesAdapter = preferencesAdapter
        self.expensesFileAdapter = expensesFileAdapter
        self.authAdapter = authAdapter
        self.router = AppRouter(authService: authService)

        self.router.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func startIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true
        await router.bootstrap()

        guard router.root == .setupPlan, let user = router.currentUser else { return }

        if let snapshot = try? await planService.loadLatestSnapshot(userId: user.id),
           snapshot.setup != nil || snapshot.plan != nil {
            router.goToDashboard()
        }
    }
}
