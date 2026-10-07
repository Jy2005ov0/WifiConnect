import Foundation

/// What started a sign-in, for the history.
enum SignInTrigger: String, Codable {
    case app, automatic, shortcut, widget, background
}

/// The one place every sign-in goes through.
enum SignIn {
    @discardableResult
    static func run(_ trigger: SignInTrigger) async throws -> LoginOutcome {
        try await PortalLogin().logIn(
            studentID: Credentials.studentID,
            password: Credentials.password,
            settings: .load()
        )
    }
}
