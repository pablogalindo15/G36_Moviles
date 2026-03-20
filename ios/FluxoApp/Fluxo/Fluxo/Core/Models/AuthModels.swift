import Foundation

struct SignInDTO {
    let email: String
    let password: String
}

struct SignUpDTO {
    let full_name: String
    let email: String
    let password: String
}

struct SaveProfileDTO: Codable {
    let full_name: String
    let avatar_url: String?
}

struct AuthenticatedUser: Equatable {
    let id: String
    let email: String?
}
