import Foundation
import WidgetKit

/// What started a sign-in, for the history.
enum SignInTrigger: String, Codable {
    case app, automatic, shortcut, widget, background
}

/// The one place every sign-in goes through.
enum SignIn {
    /// Sign-ins and sign-outs run one at a time, in order, so a background sign-in can't
    /// cross a sign-out, and a second request just finds you already online.
    @discardableResult
    static func run(_ trigger: SignInTrigger) async throws -> LoginOutcome {
        try await queue.run { try await signIn(trigger) }
    }

    private static let queue = Queue()

    private actor Queue {
        private var last: Task<Void, Never>?

        func run<T>(_ body: @escaping @Sendable () async throws -> T) async throws -> T {
            let previous = last
            let task = Task<T, Error> {
                await previous?.value
                return try await body()
            }
            last = Task { _ = try? await task.value }
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
                trace: trace,
                allowPortal: portalRule(for: trigger)
            )
            record(outcome == .loggedIn ? .signedIn : .alreadyOnline, nil)
            UserDefaults.standard.set(false, forKey: SettingsKey.signedOutByUser)
            WidgetCenter.shared.reloadAllTimelines()
            return outcome
        } catch LoginError.notSchoolPortal {
            throw LoginError.notSchoolPortal // Not a failure worth recording.
        } catch {
            record(.failed, error.localizedDescription)
            throw error
        }
    }

    /// Sign-ins you didn't start yourself only fill in a login page that looks like the school's,
    /// never a hotel's or a café's. (The Shortcuts automation is already limited to the school Wi-Fi.)
    private static func portalRule(for trigger: SignInTrigger) -> ((URL) -> Bool)? {
        let last = UserDefaults.standard.string(forKey: SettingsKey.lastPortalURL)
            .flatMap(URL.init(string:))?.host
        switch trigger {
        case .background, .automatic:
            // A campus-style private address (each building has its own), or the last login page you used.
            return { url in PortalTrust.isPrivateAddress(url.host ?? "") || (last != nil && url.host == last) }
        case .app, .shortcut, .widget:
            return nil
        }
    }

    static func signOut() async throws {
        try await queue.run { try await signOutNow() }
    }

    private static func signOutNow() async throws {
        let started = Date()
        do {
            try await PortalLogin().signOut()
            UserDefaults.standard.set(true, forKey: SettingsKey.signedOutByUser)
            WidgetCenter.shared.reloadAllTimelines()
            History.add(HistoryEntry(date: started, trigger: .app, result: .signedOut,
                                     duration: Date().timeIntervalSince(started)))
        } catch {
            History.add(HistoryEntry(date: started, trigger: .app, result: .signOutFailed,
                                     message: error.localizedDescription,
                                     duration: Date().timeIntervalSince(started)))
            throw error
        }
    }
}
