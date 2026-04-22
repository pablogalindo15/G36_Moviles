import Foundation

/// Wrapper simple sobre FileManager para exportar un snapshot de expenses
/// como archivo JSON en el Documents directory del sandbox.
///
/// Criterios del curso cumplidos:
/// - Criterio 1 (espacio): archivos pequeños en local.
/// - Criterio 2 (privacidad): Documents es app-private sandbox.
/// - Criterio 4 (tipo de dato): structured content → archivos JSON.
/// - Criterio 5 (persistencia): archivo persiste entre sesiones.
///
/// NO usar para credenciales (usar Keychain).
/// NO usar para preferencias simples (usar UserDefaults).
enum ExpensesFileError: Error, LocalizedError {
    case documentsUnavailable
    case writeFailed(Error)
    case readFailed(Error)
    case encodeFailed(Error)
    case decodeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .documentsUnavailable: return "Documents directory not available."
        case .writeFailed(let e):   return "File write failed: \(e.localizedDescription)"
        case .readFailed(let e):    return "File read failed: \(e.localizedDescription)"
        case .encodeFailed(let e):  return "JSON encode failed: \(e.localizedDescription)"
        case .decodeFailed(let e):  return "JSON decode failed: \(e.localizedDescription)"
        }
    }
}

struct ExpensesExportPayload: Codable {
    let exportedAt: Date
    let userId: String?
    let currency: String?
    let expenses: [Expense]
}

final class ExpensesFileAdapter {

    private static let filename = "fluxo_expenses_export.json"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Paths

    private func documentsURL() throws -> URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ExpensesFileError.documentsUnavailable
        }
        return url
    }

    private func exportFileURL() throws -> URL {
        try documentsURL().appendingPathComponent(Self.filename)
    }

    // MARK: - Write

    /// Escribe un snapshot JSON con los expenses proporcionados.
    /// Sobrescribe el archivo previo si existe.
    /// Retorna la URL absoluta del archivo escrito.
    @discardableResult
    func exportExpenses(
        _ expenses: [Expense],
        userId: String? = nil,
        currency: String? = nil
    ) throws -> URL {
        let payload = ExpensesExportPayload(
            exportedAt: Date(),
            userId: userId,
            currency: currency,
            expenses: expenses
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data: Data
        do {
            data = try encoder.encode(payload)
        } catch {
            throw ExpensesFileError.encodeFailed(error)
        }

        let url = try exportFileURL()
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExpensesFileError.writeFailed(error)
        }
        return url
    }

    // MARK: - Read

    /// Carga el último snapshot exportado, si existe.
    func loadLastExport() throws -> ExpensesExportPayload? {
        let url = try exportFileURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ExpensesFileError.readFailed(error)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(ExpensesExportPayload.self, from: data)
        } catch {
            throw ExpensesFileError.decodeFailed(error)
        }
    }

    /// Fecha del último export, leyendo attributes del archivo. Más eficiente que parsear JSON.
    func lastExportDate() -> Date? {
        guard let url = try? exportFileURL(),
              fileManager.fileExists(atPath: url.path),
              let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else {
            return nil
        }
        return date
    }

    /// URL del archivo (útil para debugging o para mostrar al usuario dónde está).
    func lastExportURL() -> URL? {
        guard let url = try? exportFileURL(),
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }
}
