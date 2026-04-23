import Foundation

final class PreferencesAdapter {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Keys {
        static let lastSeenCurrency = "pref.lastSeenCurrency"
        static let lastSyncAt = "pref.lastSyncAt"
        static let setupPlanDraft = "pref.setupPlanDraft"
        static let expenseDraft = "pref.expenseDraft"
        static let pendingUserNotice = "pref.pendingUserNotice"
    }

    func setLastSeenCurrency(_ currency: String) {
        defaults.set(currency, forKey: Keys.lastSeenCurrency)
    }

    func getLastSeenCurrency() -> String? {
        defaults.string(forKey: Keys.lastSeenCurrency)
    }

    // MARK: - Last sync timestamp

    func setLastSyncAt(_ date: Date) {
        defaults.set(date, forKey: Keys.lastSyncAt)
    }

    func getLastSyncAt() -> Date? {
        defaults.object(forKey: Keys.lastSyncAt) as? Date
    }

    func setSetupPlanDraft(_ draft: SetupPlanDraft) {
        setCodable(draft, forKey: Keys.setupPlanDraft)
    }

    func getSetupPlanDraft() -> SetupPlanDraft? {
        getCodable(SetupPlanDraft.self, forKey: Keys.setupPlanDraft)
    }

    func clearSetupPlanDraft() {
        defaults.removeObject(forKey: Keys.setupPlanDraft)
    }

    func setExpenseDraft(_ draft: ExpenseDraft) {
        setCodable(draft, forKey: Keys.expenseDraft)
    }

    func getExpenseDraft() -> ExpenseDraft? {
        getCodable(ExpenseDraft.self, forKey: Keys.expenseDraft)
    }

    func clearExpenseDraft() {
        defaults.removeObject(forKey: Keys.expenseDraft)
    }

    func setPendingUserNotice(_ message: String) {
        defaults.set(message, forKey: Keys.pendingUserNotice)
    }

    func consumePendingUserNotice() -> String? {
        let message = defaults.string(forKey: Keys.pendingUserNotice)
        defaults.removeObject(forKey: Keys.pendingUserNotice)
        return message
    }

    func clearPendingUserNotice() {
        defaults.removeObject(forKey: Keys.pendingUserNotice)
    }

    func clearAll() {
        defaults.removeObject(forKey: Keys.lastSeenCurrency)
        defaults.removeObject(forKey: Keys.lastSyncAt)
        clearSetupPlanDraft()
        clearExpenseDraft()
        clearPendingUserNotice()
    }

    private func setCodable<T: Codable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func getCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
