import SwiftUI

struct ContentView: View {
    @State private var model = ConnectionModel()
    @State private var hasCredentials = Credentials.isConfigured
    @State private var studentID = Credentials.studentID
    @AppStorage(SettingsKey.wifiName) private var wifiName = SettingsKey.defaultWifiName
    @State private var showSettings = false
    @State private var showAutomationGuide = false
    @State private var showDemoHistory = false
    @State private var showDemoShare = false
    @State private var pendingSetup: SharedSetup?
    @State private var speedTest = SpeedTest()
    @State private var showSpeedTest = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 8)

                // The big circle is the button: Connect, or Disconnect once connected.
                Button(action: primaryAction) {
                    StatusBadge(state: model.state)
                }
                .buttonStyle(PressableStyle())
                .disabled(model.state == .working)
                .accessibilityLabel(hint ?? title)

                Text(hint ?? " ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(model.state.tint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(model.state.tint.opacity(0.12), in: Capsule())
                    .padding(.top, 6)
                    .opacity(hint == nil ? 0 : 1)
                    .contentTransition(.opacity)
                    .animation(.default, value: hint)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.title.weight(.bold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 14)
                .padding(.horizontal, 32)
                .animation(.default, value: model.state)

                Spacer(minLength: 24)

                DetailsCard {
                    DetailRow(symbol: "wifi", color: .blue, title: "Network",
                              value: wifiName.isEmpty ? String(localized: "Not Set") : wifiName)
                    Divider().padding(.leading, 58)
                    DetailRow(symbol: "person.text.rectangle.fill", color: .indigo, title: "Student ID",
                              value: studentID.isEmpty ? String(localized: "Not Set") : studentID)
                    Divider().padding(.leading, 58)
                    Button {
                        showAutomationGuide = true
                    } label: {
                        DetailRow(symbol: "bolt.fill", color: .green, title: "Auto Sign-In",
                                  value: String(localized: "Set Up"), showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 58)
                    Button {
                        showSpeedTest = true
                    } label: {
                        DetailRow(symbol: "speedometer", color: .orange, title: "Speed",
                                  value: speedTest.summary ?? String(localized: "Test"),
                                  showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .animation(.default, value: isConnected)
            .background {
                // A soft glow in the status color, like the lock screen's wallpaper tint.
                ZStack {
                    Color(.systemGroupedBackground)
                    RadialGradient(
                        colors: [model.state.tint.opacity(0.22), .clear],
                        center: UnitPoint(x: 0.5, y: 0.3),
                        startRadius: 0,
                        endRadius: 420
                    )
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: model.state)
            }
            .navigationTitle("Campus Wi-Fi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppearanceMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openSettings()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                hasCredentials = Credentials.isConfigured
                studentID = Credentials.studentID
            }) {
                SettingsView()
            }
            .sheet(isPresented: $showAutomationGuide) {
                AutomationGuideView()
            }
            .sheet(isPresented: $showDemoHistory) {
                NavigationStack { HistoryView() }
            }
            .sheet(isPresented: $showSpeedTest) {
                NavigationStack { SpeedTestView(test: speedTest) }
            }
            .sheet(isPresented: $showDemoShare) {
                NavigationStack { ShareSetupView() }
            }
            .alert(
                "Use a classmate's setup?",
                isPresented: Binding(get: { pendingSetup != nil }, set: { if !$0 { pendingSetup = nil } }),
                presenting: pendingSetup
            ) { setup in
                Button("Use Setup") {
                    setup.apply()
                    pendingSetup = nil
                }
                Button("Cancel", role: .cancel) { pendingSetup = nil }
            } message: { setup in
                let mode = setup.useCustomPortal ? String(localized: "set manually") : String(localized: "automatic")
                Text("Wi-Fi: \(setup.wifiName). Login page: \(mode). Your own student ID and password stay the same.")
            }
            .sensoryFeedback(trigger: model.state) { _, new in
                switch new {
                case .connected: return .success
                case .failed: return .error
                default: return nil
                }
            }
            .onAppear {
                #if DEBUG
                if applyDemo() { return }
                if UserDefaults.standard.string(forKey: "testStudentID") != nil {
                    // End-to-end test: sign in (or out) straight away with the test account.
                    hasCredentials = true
                    studentID = Credentials.studentID
                    if UserDefaults.standard.string(forKey: "testAction") == "signOut" {
                        Task { await model.signOut() }
                    } else {
                        Task { await model.connect() }
                    }
                    return
                }
                #endif
                if !hasCredentials { showSettings = true }
                Task { await Notifier.requestPermission() }
            }
            .onOpenURL { url in
                guard url.scheme == "wificonnect" else { return }
                if let setup = SharedSetup(url: url) {
                    pendingSetup = setup
                    return
                }
                if url.host == "connect", hasCredentials {
                    Task { await model.connect() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .connectRequested)) { _ in
                // From the widget or the Control Center button.
                if hasCredentials { Task { await model.connect() } }
            }
            .onChange(of: scenePhase) {
                // Opening the app on campus signs you in straight away.
                if scenePhase == .active, hasCredentials, model.state != .working, !isDemo, !isTest {
                    Task { await model.connect(automatic: true) }
                }
            }
        }
    }

    /// Opens Settings, asking for Face ID first when the app lock is on.
    private func openSettings() {
        guard AppLock.isEnabled, hasCredentials else {
            showSettings = true
            return
        }
        Task {
            if await AppLock.authenticate(reason: String(localized: "Unlock to see your student ID and password.")) {
                showSettings = true
            }
        }
    }

    private var isTest: Bool {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "testStudentID") != nil
        #else
        return false
        #endif
    }

    private var isDemo: Bool {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "demoState") != nil
        #else
        return false
        #endif
    }

    #if DEBUG
    /// Launch arguments used to take the README screenshots, e.g. `-demoState connected -demoScreen settings`.
    private func applyDemo() -> Bool {
        let defaults = UserDefaults.standard
        guard let demoState = defaults.string(forKey: "demoState") else { return false }
        if let id = defaults.string(forKey: "demoStudentID") {
            Credentials.studentID = id
            Credentials.password = "password"
        }
        hasCredentials = Credentials.isConfigured
        studentID = Credentials.studentID
        if defaults.string(forKey: "demoSpeed") != nil { speedTest.showDemoResult() }
        switch demoState {
        case "working": model.state = .working
        case "connected": model.state = .connected(String(localized: "You're signed in and ready to go."))
        case "failed": model.state = .failed(LoginError.stillOffline.localizedDescription)
        default: model.state = .idle
        }
        switch defaults.string(forKey: "demoScreen") {
        case "settings": showSettings = true
        case "guide": showAutomationGuide = true
        case "history":
            History.seedDemo()
            showDemoHistory = true
        case "share":
            showDemoShare = true
        case "speed":
            speedTest.showDemoResult()
            showSpeedTest = true
        default: break
        }
        return true
    }
    #endif

    private var title: String {
        switch model.state {
        case .idle: return hasCredentials ? String(localized: "Ready") : String(localized: "Welcome")
        case .working: return String(localized: "Signing In…")
        case .connected: return String(localized: "Connected")
        case .failed: return String(localized: "Couldn't Sign In")
        case .signedOut: return String(localized: "Signed Out")
        }
    }

    private var isConnected: Bool {
        if case .connected = model.state { return true }
        return false
    }

    private var subtitle: String {
        switch model.state {
        case .idle:
            return hasCredentials
                ? String(localized: "Join your school's Wi-Fi, then tap the circle.") : String(localized: "Add your student ID and password to get started.")
        case .working: return String(localized: "Talking to your school's login page.")
        case .connected(let message), .failed(let message): return message
        case .signedOut: return String(localized: "You've signed out of the campus Wi-Fi.")
        }
    }

    /// What tapping the circle does, shown under it.
    private var hint: String? {
        if !hasCredentials { return String(localized: "Add Student ID") }
        switch model.state {
        case .working: return nil
        case .connected: return String(localized: "Tap to Disconnect")
        case .failed: return String(localized: "Tap to Try Again")
        case .idle, .signedOut: return String(localized: "Tap to Connect")
        }
    }

    private func primaryAction() {
        if !hasCredentials {
            showSettings = true
        } else if isConnected {
            Task { await model.signOut() }
        } else {
            Task { await model.connect() }
        }
    }
}

private struct StatusBadge: View {
    let state: ConnectionModel.State
    @State private var breathing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(state.tint.opacity(0.10))
                .frame(width: 188, height: 188)
                .scaleEffect(breathing ? 1.04 : 0.96)
            Circle()
                .fill(state.tint.opacity(0.14))
                .frame(width: 148, height: 148)
            Circle()
                .fill(state.tint.gradient)
                .overlay {
                    // A gentle highlight so the disc reads like glass.
                    Circle().fill(
                        LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
                    )
                }
                .frame(width: 108, height: 108)
                .shadow(color: state.tint.opacity(0.45), radius: 18, y: 10)
            Image(systemName: state.symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.variableColor.iterative, isActive: state == .working)
        }
        .animation(.spring(duration: 0.5), value: state)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

/// Shrinks a little while pressed, like a physical button.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.3), value: configuration.isPressed)
    }
}

/// An inset, rounded group like the rows in the Settings app.
private struct DetailsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DetailRow: View {
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let value: String
    var showsChevron = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(title)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

private extension ConnectionModel.State {
    var symbol: String {
        switch self {
        case .idle, .working: return "wifi"
        case .connected: return "checkmark"
        case .failed: return "wifi.exclamationmark"
        case .signedOut: return "wifi.slash"
        }
    }

    var tint: Color {
        switch self {
        case .idle, .working: return .blue
        case .connected: return .green
        case .failed: return .orange
        case .signedOut: return .gray
        }
    }
}

#Preview {
    ContentView()
}
