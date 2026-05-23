import Foundation

extension Error {
    var isCancelledRequest: Bool {
        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain,
           URLError.Code(rawValue: nsError.code) == .cancelled {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSURLErrorDomain,
           URLError.Code(rawValue: underlying.code) == .cancelled {
            return true
        }
        return false
    }
}

enum ExpenseEvCMessages {
    static func updateRequiresInternet() -> String {
        "Editing this expense requires internet connection. Reconnect and try again."
    }

    static func deleteRequiresInternet(fromList: Bool) -> String {
        fromList
            ? "Deleting this expense from the list requires internet connection. Reconnect and try again."
            : "Deleting this expense requires internet connection. Reconnect and try again."
    }

    static func receiptNeedsInternetUntilCached() -> String {
        "This receipt needs internet until it has been opened at least once on this device."
    }

    static func receiptSavedLocallyForRetry() -> String {
        "The expense was saved and the receipt is stored on this device. Open this expense again when you're online to finish syncing the image."
    }

    static func receiptUploadRequiresInternet() -> String {
        "Uploading this receipt requires internet connection. Reconnect and try again."
    }
}
