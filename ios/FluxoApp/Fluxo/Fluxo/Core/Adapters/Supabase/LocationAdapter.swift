import Foundation

final class LocationAdapter {
    private let httpClient: SupabaseHTTPClient

    init(httpClient: SupabaseHTTPClient) {
        self.httpClient = httpClient
    }

    func detectLocationContext(
        latitude: Double,
        longitude: Double,
        countryCode: String?,
        accessToken: String
    ) async throws -> LocationContextDTO {
        let body = DetectLocationRequestDTO(latitude: latitude, longitude: longitude, country_code: countryCode)
        let (data, response) = try await httpClient.requestJSON(
            path: "/functions/v1/detect-location-context",
            method: "POST",
            body: body,
            authToken: accessToken
        )
        guard (200...299).contains(response.statusCode) else {
            throw LocationAdapterError.backend(statusCode: response.statusCode)
        }
        return try JSONDecoder().decode(LocationContextDTO.self, from: data)
    }
}

struct DetectLocationRequestDTO: Encodable {
    let latitude: Double
    let longitude: Double
    let country_code: String?
}

struct LocationContextDTO: Decodable {
    let country_code: String
    let currency: String
    let inflation_rate: Double?
    let inflation_warning: String?
}

enum LocationAdapterError: LocalizedError {
    case backend(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .backend(let code):
            return "Location context error (\(code))"
        }
    }
}
