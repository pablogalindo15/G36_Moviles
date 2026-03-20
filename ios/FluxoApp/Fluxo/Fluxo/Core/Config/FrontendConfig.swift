import Foundation

struct FrontendConfig {
    let supabaseURL: URL
    let supabaseAnonKey: String

    static func load(bundle: Bundle = .main) throws -> FrontendConfig {
        // This plist is the single source of Supabase config for iOS frontend.
        guard let url = bundle.url(forResource: "FrontendConfig", withExtension: "plist") else {
            throw FrontendConfigError.missingFile
        }

        guard
            let rawConfig = NSDictionary(contentsOf: url) as? [String: Any]
        else {
            throw FrontendConfigError.invalidFileFormat
        }

        guard let urlString = rawConfig["SUPABASE_URL"] as? String, !urlString.isEmpty else {
            throw FrontendConfigError.missingKey("SUPABASE_URL")
        }
        guard let anonKey = rawConfig["SUPABASE_ANON_KEY"] as? String, !anonKey.isEmpty else {
            throw FrontendConfigError.missingKey("SUPABASE_ANON_KEY")
        }
        guard let parsedURL = URL(string: urlString) else {
            throw FrontendConfigError.invalidURL(urlString)
        }

        return FrontendConfig(
            supabaseURL: parsedURL,
            supabaseAnonKey: anonKey
        )
    }
}

enum FrontendConfigError: LocalizedError {
    case missingFile
    case invalidFileFormat
    case missingKey(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "FrontendConfig.plist was not found in the app bundle."
        case .invalidFileFormat:
            return "FrontendConfig.plist has invalid format."
        case .missingKey(let key):
            return "FrontendConfig.plist is missing key: \(key)"
        case .invalidURL(let value):
            return "SUPABASE_URL is invalid: \(value)"
        }
    }
}
