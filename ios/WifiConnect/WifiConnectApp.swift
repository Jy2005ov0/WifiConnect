import SwiftUI

@main
struct WifiConnectApp: App {
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { appearance.apply() }
                .onChange(of: appearance) { appearance.apply(animated: true) }
        }
    }
}
