import SwiftUI

@main
struct WifiConnectApp: App {
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NavigationBarStyle.apply()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { appearance.apply() }
                .onChange(of: appearance) { appearance.apply(animated: true) }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background { KeepAlive.schedule() }
        }
        .backgroundTask(.appRefresh(KeepAlive.identifier)) {
            await KeepAlive.run()
        }
    }
}
