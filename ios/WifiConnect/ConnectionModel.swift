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
    }

    var state: State = .idle

    /// - Parameter automatic: When the app signs in on its own (e.g. on launch), stay quiet if there's no Wi-Fi.
    func connect(automatic: Bool = false) async {
        guard state != .working else { return }
        state = .working
        do {
            let outcome = try await SignIn.run(automatic ? .automatic : .app)
            switch outcome {
            case .alreadyOnline: state = .connected("You're already online.")
            case .loggedIn: state = .connected("You're signed in and ready to go.")
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
