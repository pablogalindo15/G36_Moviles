import Foundation

enum ConnectivitySupport {
    static func isConnectivityIssue(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return true }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSURLErrorDomain {
            return true
        }
        return false
    }

    static func requiresInternetMessage(for feature: String) -> String {
        "\(feature) requires internet connection. Reconnect and try again."
    }

    static func draftPreservedMessage(for action: String) -> String {
        "We couldn't \(action) because you're offline. Your draft is still saved on this device. Reconnect and try again."
    }

    static func cachedContentMessage() -> String {
        "Showing saved data while you're offline. Pull to refresh when connection is back."
    }

    static func refreshFallbackMessage() -> String {
        "Showing saved data because we couldn't refresh the latest data right now. Pull to refresh and try again."
    }

    static func noSavedContentMessage(for feature: String) -> String {
        "You're offline and we don't have saved \(feature) on this device yet. Connect to internet and try again."
    }
}
