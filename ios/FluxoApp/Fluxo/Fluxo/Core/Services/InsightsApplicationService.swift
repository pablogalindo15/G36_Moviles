import Foundation

/// `InsightsApplicationService` orquesta la carga de los 3
/// insights (BQs D, E, F) aplicando:
///
/// - **Local Storage**: Database mechanism (SwiftData / `InsightSnapshot`)
///   con patrón de Cache.
/// - **Eventual Connectivity**: "Cache, falling back to network"
///   con "Expiration policy" (TTL = 1 h).
/// - **Multi-threading**: ejecución concurrente de las 3 BQs
///   con `async let` (Swift Concurrency sobre GCD).
final class InsightsApplicationService {

    private let functionsAdapter: FunctionsAdapter
    private let authAdapter: AuthAdapter
    private let localStore: LocalStore

    init(functionsAdapter: FunctionsAdapter, authAdapter: AuthAdapter, localStore: LocalStore) {
        self.functionsAdapter = functionsAdapter
        self.authAdapter = authAdapter
        self.localStore = localStore
    }

    // MARK: - Static constants

    /// Expiration policy: cache válido durante 1 hora.
    private static let ttl: TimeInterval = 3_600

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Public — individual loaders

    /// Carga la comparación de ciclos por categoría.
    /// Aplica "Cache, falling back to network" con Expiration policy.
    func loadCategoryCycleComparison(forceRefresh: Bool = false) async throws -> InsightResult<CategoryCycleComparison> {
        let session = try await currentSession()
        return try await loadBQ(bqType: BQType.categoryCycleComparison, userId: session.userId, forceRefresh: forceRefresh) {
            try await self.functionsAdapter.fetchCategoryCycleComparison(accessToken: $0)
        }
    }

    /// Carga los streaks de categorías sin gastos recientes.
    /// Aplica "Cache, falling back to network" con Expiration policy.
    func loadCategoryStreaks(forceRefresh: Bool = false) async throws -> InsightResult<CategoryStreaks> {
        let session = try await currentSession()
        return try await loadBQ(bqType: BQType.categoryStreaks, userId: session.userId, forceRefresh: forceRefresh) {
            try await self.functionsAdapter.fetchCategoryStreaks(accessToken: $0)
        }
    }

    /// Carga el gasto más alto del ciclo actual.
    /// Aplica "Cache, falling back to network" con Expiration policy.
    func loadBiggestExpenseOfCycle(forceRefresh: Bool = false) async throws -> InsightResult<BiggestExpenseOfCycle> {
        let session = try await currentSession()
        return try await loadBQ(bqType: BQType.biggestExpenseOfCycle, userId: session.userId, forceRefresh: forceRefresh) {
            try await self.functionsAdapter.fetchBiggestExpenseOfCycle(accessToken: $0)
        }
    }

    // MARK: - Public — parallel loader

    /// Carga las 3 BQs EN PARALELO usando `async let`.
    ///
    /// **Multi-threading**: Swift Concurrency sobre GCD — las 3 tareas
    /// se despachan de forma concurrente sin bloquear el hilo principal.
    ///
    /// No throws: errores parciales quedan como `nil` en el bundle.
    /// La View decide qué mostrar según qué campos llegaron.
    func loadAllInsights(forceRefresh: Bool = false) async -> InsightsBundle {
        async let resultD = try? loadCategoryCycleComparison(forceRefresh: forceRefresh)
        async let resultE = try? loadCategoryStreaks(forceRefresh: forceRefresh)
        async let resultF = try? loadBiggestExpenseOfCycle(forceRefresh: forceRefresh)

        let (d, e, f) = await (resultD, resultE, resultF)

        let staleFlags    = [d?.wasStale,   e?.wasStale,   f?.wasStale  ].compactMap { $0 }
        let computedDates = [d?.computedAt, e?.computedAt, f?.computedAt].compactMap { $0 }

        // Cleanup fire-and-forget — snapshots > 7 días
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3_600)
        Task.detached(priority: .background) { [localStore = self.localStore] in
            await MainActor.run {
                localStore.deleteExpiredInsightSnapshots(olderThan: cutoff)
            }
        }

        return InsightsBundle(
            cycleComparison: d?.value,
            streaks:         e?.value,
            biggestExpense:  f?.value,
            isStale:         staleFlags.contains(true),
            lastComputedAt:  computedDates.max()
        )
    }

    // MARK: - Private helpers

    /// Implementa "Cache, falling back to network" + Expiration policy
    /// para una BQ genérica identificada por `bqType`.
    ///
    /// - `fetch`: closure que recibe un access token y devuelve el DTO remoto.
    private func loadBQ<T: Codable>(
        bqType: String,
        userId: UUID,
        forceRefresh: Bool = false,
        fetch: (String) async throws -> T
    ) async throws -> InsightResult<T> {

        // PASO 1 — Leer snapshot existente del LocalStore (Database / SwiftData).
        let snapshot = await MainActor.run {
            localStore.fetchInsightSnapshot(bqType: bqType, userId: userId)
        }

        // PASO 2 — Cache HIT: Expiration policy — cache válido si computedAt dentro del TTL.
        // Se omite si forceRefresh == true (pull-to-refresh bypass).
        if !forceRefresh,
           let snap = snapshot,
           snap.computedAt >= Date().addingTimeInterval(-Self.ttl),
           let cached = try? Self.decoder.decode(T.self, from: snap.payload) {
            return InsightResult(value: cached, wasStale: false, computedAt: snap.computedAt)
        }

        // PASO 3 — Cache MISS o caducado → falling back to network.
        let token: String
        do {
            token = try await authAdapter.currentAccessToken()
        } catch {
            throw InsightLoadError.notAuthenticated
        }

        do {
            let value = try await fetch(token)
            let data  = try Self.encoder.encode(value)
            let now   = Date()
            await MainActor.run {
                localStore.saveInsightSnapshot(bqType: bqType, userId: userId, payload: data)
            }
            return InsightResult(value: value, wasStale: false, computedAt: now)

        } catch let adapterError as FunctionsAdapterError {
            // 401 → refresh token y reintentar una vez.
            guard case .backend(let code, _, _) = adapterError, code == 401 else {
                throw InsightLoadError.underlying(adapterError)
            }
            let newToken = try await authAdapter.refreshSession()
            let value    = try await fetch(newToken)
            let data     = try Self.encoder.encode(value)
            let now      = Date()
            await MainActor.run {
                localStore.saveInsightSnapshot(bqType: bqType, userId: userId, payload: data)
            }
            return InsightResult(value: value, wasStale: false, computedAt: now)

        } catch let urlError as URLError {
            // PASO 4 — OFFLINE FALLBACK: solo errores URLError con códigos offline reales.
            let offlineCodes: [URLError.Code] = [
                .notConnectedToInternet,
                .networkConnectionLost,
                .timedOut,
                .cannotConnectToHost,
                .cannotFindHost,
                .dnsLookupFailed,
                .internationalRoamingOff,
                .dataNotAllowed
            ]
            if offlineCodes.contains(urlError.code) {
                if let snap = snapshot,
                   let stale = try? Self.decoder.decode(T.self, from: snap.payload) {
                    return InsightResult(value: stale, wasStale: true, computedAt: snap.computedAt)
                }
                throw InsightLoadError.noCachedData
            }
            throw InsightLoadError.underlying(urlError)

        } catch {
            // Cualquier otro error (decode, HTTP 5xx, Foundation non-URLError) → throw limpio.
            // NO es offline. NO fallback stale.
            throw InsightLoadError.underlying(error)
        }
    }

    private func currentSession() async throws -> (token: String, userId: UUID) {
        do {
            return (
                token:  try await authAdapter.currentAccessToken(),
                userId: try authAdapter.currentUserId()
            )
        } catch {
            throw InsightLoadError.notAuthenticated
        }
    }
}

// MARK: - Supporting types

/// Resultado de una BQ individual con metadatos de frescura.
struct InsightResult<T: Codable> {
    let value: T
    /// `true` si el valor provino de cache caducado por fallback offline.
    let wasStale: Bool
    /// Timestamp del snapshot (si vino de cache) o `Date()` si vino de red.
    let computedAt: Date
}

/// Resultado agregado de las 3 BQs, construido por `loadAllInsights()`.
struct InsightsBundle {
    let cycleComparison: CategoryCycleComparison?
    let streaks: CategoryStreaks?
    let biggestExpense: BiggestExpenseOfCycle?
    /// `true` si al menos una BQ devolvió datos de cache caducado.
    let isStale: Bool
    /// Timestamp más reciente entre los `computedAt` de las BQs exitosas.
    let lastComputedAt: Date?
}

/// Errores del servicio de insights.
enum InsightLoadError: Error, LocalizedError {
    case notAuthenticated
    /// Red falló y no existe ningún snapshot previo en cache.
    case noCachedData
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Your session expired. Please sign in again."
        case .noCachedData:
            return "No internet connection and no saved data available."
        case .underlying(let e):
            return e.localizedDescription
        }
    }
}

/// Identificadores de BQ usados como clave de cache en `InsightSnapshot`.
private enum BQType {
    static let categoryCycleComparison = "category-cycle-comparison"
    static let categoryStreaks         = "category-streaks"
    static let biggestExpenseOfCycle   = "biggest-expense-of-cycle"
}
