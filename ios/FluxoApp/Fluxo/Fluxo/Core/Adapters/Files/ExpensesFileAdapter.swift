import Foundation

enum ExpensesFileError: Error, LocalizedError {
    case documentsUnavailable
    case writeFailed(Error)
    case encodeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .documentsUnavailable: return "Documents directory not available."
        case .writeFailed(let e):   return "File write failed: \(e.localizedDescription)"
        case .encodeFailed(let e):  return "JSON encode failed: \(e.localizedDescription)"
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

    private func documentsURL() throws -> URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ExpensesFileError.documentsUnavailable
        }
        return url
    }

    private func exportFileURL() throws -> URL {
        try documentsURL().appendingPathComponent(Self.filename)
    }

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

    func lastExportDate() -> Date? {
        guard let url = try? exportFileURL(),
              fileManager.fileExists(atPath: url.path),
              let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else {
            return nil
        }
        return date
    }
}
