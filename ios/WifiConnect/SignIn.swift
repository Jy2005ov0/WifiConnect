import Foundation
import WidgetKit

/// What started a sign-in, for the history.
enum SignInTrigger: String, Codable {
    case app, automatic, shortcut, widget, background
}

/// The one place every sign-in goes through.
enum SignIn {
    /// Runs one sign-in at a time: a second request while one is going waits for its result
    /// instead of submitting the login form twice.
    @discardableResult
    static func run(_ trigger: SignInTrigger) async throws -> LoginOutcome {
        try await gate.run { try await signIn(trigger) }
    }

    private static let gate = Gate()

    private actor Gate {
        private var current: Task<LoginOutcome, Error>?

        func run(_ body: @escaping @Sendable () async throws -> LoginOutcome) async throws -> LoginOutcome {
            if let current { return try await current.value }
            let task = Task { try await body() }
            current = task
            defer { current = nil }
            return try await task.value
        }
    }

    private static func signIn(_ trigger: SignInTrigger) async throws -> LoginOutcome {
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
            UserDefaults.standard.set(false, forKey: SettingsKey.signedOutByUser)
            WidgetCenter.shared.reloadAllTimelines()
            return outcome
        } catch {
            record(.failed, error.localizedDescription)
            throw error
        }
    }

    static func signOut() async throws {
        let started = Date()
        do {
            try await PortalLogin().signOut()
            UserDefaults.standard.set(true, forKey: SettingsKey.signedOutByUser)
            WidgetCenter.shared.reloadAllTimelines()
            History.add(HistoryEntry(date: started, trigger: .app, result: .signedOut,
                                     duration: Date().timeIntervalSince(started)))
        } catch {
            History.add(HistoryEntry(date: started, trigger: .app, result: .failed,
                                     message: error.localizedDescription,
                                     duration: Date().timeIntervalSince(started)))
            throw error
        }
    }
}
