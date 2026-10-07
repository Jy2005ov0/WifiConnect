import Foundation

/// What started a sign-in, for the history.
enum SignInTrigger: String, Codable {
    case app, automatic, shortcut, widget, background
}

/// The one place every sign-in goes through.
enum SignIn {
    @discardableResult
    static func run(_ trigger: SignInTrigger) async throws -> LoginOutcome {
        let started = Date()
        let trace = LoginTrace()
        func record(_ result: HistoryEntry.Result, _ message: String?) {
            History.add(HistoryEntry(
                date: started,
                trigger: trigger,
                result: result,
                message: message,
                portal: History.describe(trace.portalURL),
                formAction: History.describe(trace.formAction),
                method: trace.method,
                fields: trace.fieldNames.isEmpty ? nil : trace.fieldNames,
                duration: Date().timeIntervalSince(started)
            ))
        }
        do {
            let outcome = try await PortalLogin().logIn(
                studentID: Credentials.studentID,
                password: Credentials.password,
                settings: .load(),
                trace: trace
            )
            record(outcome == .loggedIn ? .signedIn : .alreadyOnline, nil)
            return outcome
        } catch {
            record(.failed, error.localizedDescription)
            throw error
        }
    }
}
