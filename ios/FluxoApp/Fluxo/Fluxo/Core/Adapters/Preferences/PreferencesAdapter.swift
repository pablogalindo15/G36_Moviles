import Foundation

/// Typed wrapper over UserDefaults for non-sensitive user preferences.
/// Centralises all keys and access patterns to avoid raw UserDefaults usage elsewhere.
///
/// Legitimate uses:
/// - lastSeenCurrency: pre-fill currency in LogExpense next time the sheet opens
/// - lastSyncAt: timestamp of last remote sync (debugging + future Fase 5 offline queue)
/// - hasCompletedOnboarding: flag to distinguish first launch
///
/// Do NOT use for sensitive credentials (use KeychainAdapter).
/// Do NOT use for structured relational data (use LocalStore / SwiftData).
final class PreferencesAdapter {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    private enum Keys {
        static let lastSeenCurrency       = "pref.lastSeenCurrency"
        static let lastSyncAt             = "pref.lastSyncAt"
        static let hasCompletedOnboarding = "pref.hasCompletedOnboarding"
    }

    // MARK: - Last seen currency

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

    // MARK: - Onboarding flag

    func setHasCompletedOnboarding(_ value: Bool) {
        defaults.set(value, forKey: Keys.hasCompletedOnboarding)
    }

    func getHasCompletedOnboarding() -> Bool {
        defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    // MARK: - Cleanup

    /// Clears all preferences. Not called automatically on sign out — kept
    /// so the next sign-in benefits from saved currency preference.
    func clearAll() {
        defaults.removeObject(forKey: Keys.lastSeenCurrency)
        defaults.removeObject(forKey: Keys.lastSyncAt)
        defaults.removeObject(forKey: Keys.hasCompletedOnboarding)
    }
}
