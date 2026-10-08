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
    func connect(automatic: Bool = false) async {
        guard state != .working else { return }
        state = .working
        failedSigningOut = false
        do {
            let outcome = try await SignIn.run(automatic ? .automatic : .app)
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
}
