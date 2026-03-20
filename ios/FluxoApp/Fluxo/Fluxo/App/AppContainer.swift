import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    let config: FrontendConfig

    let authService: AuthApplicationService
    let planService: PlanApplicationService
    let cameraFacade: CameraFacade
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
        // 1) Lectura de configuración Supabase.
        let config = try FrontendConfig.load()
        let httpClient = SupabaseHTTPClient(config: config)

        // 2) Construir adapters.
        let authAdapter = AuthAdapter(httpClient: httpClient)
        let profileAdapter = ProfileAdapter(httpClient: httpClient)
        let storageAdapter = StorageAdapter(httpClient: httpClient)
        let planAdapter = PlanAdapter(httpClient: httpClient)
        let functionsAdapter = FunctionsAdapter(httpClient: httpClient)

        // 3) Construir servicios de aplicación.
        let authService = AuthApplicationService(
            authAdapter: authAdapter,
            profileAdapter: profileAdapter,
            storageAdapter: storageAdapter
        )
        let planService = PlanApplicationService(
            authAdapter: authAdapter,
            planAdapter: planAdapter,
            functionsAdapter: functionsAdapter
        )

        self.config = config
        self.authService = authService
        self.planService = planService
        self.cameraFacade = CameraFacade()
        self.router = AppRouter(authService: authService)

        // RootView observa AppContainer, so we forward router updates.
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
    }
}
