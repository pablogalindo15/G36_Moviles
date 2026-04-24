import Foundation

enum ConnectivitySupport {
    static func isConnectivityIssue(_ error: Error) -> Bool {
        return urlErrorCode(from: error) != nil
    }

    static func isConfirmedOfflineIssue(_ error: Error) -> Bool {
        guard let code = urlErrorCode(from: error) else { return false }
        switch code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            return true
        default:
            return false
        }
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

    private static func urlErrorCode(from error: Error) -> URLError.Code? {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return URLError.Code(rawValue: nsError.code)
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSURLErrorDomain {
            return URLError.Code(rawValue: underlying.code)
        }
        return nil
    }
}
