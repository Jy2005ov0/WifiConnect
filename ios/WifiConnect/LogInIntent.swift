import AppIntents

/// Lets Shortcuts (and Siri) sign in without opening the app,
/// e.g. from an automation that runs when you join the school Wi-Fi.
struct LogInIntent: AppIntent {
    static var title: LocalizedStringResource = "Log In to Campus Wi-Fi"
    static var description = IntentDescription("Signs in to your school's Wi-Fi login page with your saved student ID and password.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = try await PortalLogin().logIn(
            studentID: Credentials.studentID,
            password: Credentials.password,
            settings: .load()
        )
        switch outcome {
        case .alreadyOnline:
            return .result(dialog: "You're already online.")
        case .loggedIn:
            return .result(dialog: "Logged in to campus Wi-Fi.")
        }
    }
}

struct WifiConnectShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogInIntent(),
            phrases: [
                "Log in with \(.applicationName)",
                "Connect to campus Wi-Fi with \(.applicationName)",
            ],
            shortTitle: "Log In",
            systemImageName: "wifi"
        )
    }
}
