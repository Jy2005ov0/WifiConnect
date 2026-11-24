import Foundation
import Observation

@MainActor
@Observable
final class ConnectionModel {
    enum State: Equatable {
        case idle
        case working
        case connected(String)
        case failed(String)
        case signedOut
    }

    var state: State = .idle
    /// Whether the app itself signed you in (not just "you're already online").
    private(set) var signedInByApp = false
    /// Whether the last failure was signing out, so the screen says "Couldn't Sign Out".
    private(set) var failedSigningOut = false

    func signOut() async {
        guard state != .working else { return }
        let wasSignedInByApp = signedInByApp
        state = .working
        failedSigningOut = false
        do {
            try await SignIn.signOut()
            state = .signedOut
            signedInByApp = false
        } catch {
            // Already online without the app signing you in (e.g. at home) and no sign-out link is
            // known: there's nothing to sign out of, so just go back to Tap to Connect.
            let nothingToSignOut: Bool
            if case .noSignOutLink? = error as? LoginError {
                nothingToSignOut = !wasSignedInByApp
            } else {
                nothingToSignOut = false
            }
            if nothingToSignOut {
                state = .idle
            } else {
                state = .failed(error.localizedDescription)
                failedSigningOut = true
            }
        }
        #if DEBUG
        let run = UserDefaults.standard.string(forKey: "testRun") ?? ""
        UserDefaults.standard.set("\(run): \(String(describing: state))", forKey: "testResult")
        UserDefaults.standard.synchronize()
        #endif
    }

    /// - Parameter automatic: When the app signs in on its own (e.g. on launch), stay quiet if there's no Wi-Fi.
    func connect(automatic: Bool = false, trigger: SignInTrigger? = nil) async {
        guard state != .working else { return }
        state = .working
        failedSigningOut = false
        do {
            let outcome = try await SignIn.run(trigger ?? (automatic ? .automatic : .app))
            signedInByApp = outcome == .loggedIn
            switch outcome {
            case .alreadyOnline: state = .connected(String(localized: "You're already online."))
            case .loggedIn: state = .connected(String(localized: "You're signed in and ready to go."))
            }
        } catch LoginError.notOnWiFi where automatic {
            state = .idle
        } catch LoginError.notSchoolPortal {
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
        #if DEBUG
        // Read back by the end-to-end test.
        let run = UserDefaults.standard.string(forKey: "testRun") ?? ""
        UserDefaults.standard.set("\(run): \(String(describing: state))", forKey: "testResult")
        UserDefaults.standard.synchronize()
        #endif
    }

    /// Brings the screen up to date when the app opens or comes back: shows Connected when the
    /// Shortcuts automation, a widget or Stay Signed In signed you in meanwhile, and goes back to
    /// Tap to Connect when a Connected screen is out of date (you've left the Wi-Fi).
    func catchUp() async {
        switch state {
        case .idle:
            guard let last = History.load().first, last.result == .signedIn,
                  Date().timeIntervalSince(last.date) < 12 * 60 * 60 else { return }
            guard await WifiStatus.check() == .online, state == .idle else { return }
            signedInByApp = true
            state = .connected(String(localized: "You're signed in and ready to go."))
        case .connected:
            guard await WifiStatus.check() != .online, case .connected = state else { return }
            signedInByApp = false
            state = .idle
        default:
            return
        }
    }
}
