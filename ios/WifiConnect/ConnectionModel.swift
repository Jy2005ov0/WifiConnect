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

    func signOut() async {
        guard state != .working else { return }
        state = .working
        do {
            try await SignIn.signOut()
            state = .signedOut
        } catch {
            state = .failed(error.localizedDescription)
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
        do {
            let outcome = try await SignIn.run(automatic ? .automatic : .app)
            switch outcome {
            case .alreadyOnline: state = .connected(String(localized: "You're already online."))
            case .loggedIn: state = .connected(String(localized: "You're signed in and ready to go."))
            }
        } catch LoginError.notOnWiFi where automatic {
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
