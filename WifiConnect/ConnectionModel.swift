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
        state = .working
        do {
            let outcome = try await PortalLogin().logIn(
                studentID: Credentials.studentID,
                password: Credentials.password,
                settings: .load()
            )
            switch outcome {
            case .alreadyOnline: state = .connected("You're already online.")
            case .loggedIn: state = .connected("You're signed in and ready to go.")
            }
        } catch LoginError.notOnWiFi where automatic {
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
