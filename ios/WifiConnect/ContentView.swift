import SwiftUI

struct ContentView: View {
    @State private var model = ConnectionModel()
    @State private var hasCredentials = Credentials.isConfigured
    @State private var studentID = Credentials.studentID
    @AppStorage(SettingsKey.wifiName) private var wifiName = SettingsKey.defaultWifiName
    @State private var showSettings = false
    @State private var showAutomationGuide = false
    @State private var showDemoHistory = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 8)

                StatusBadge(state: model.state)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.title.weight(.bold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 26)
                .padding(.horizontal, 32)
                .animation(.default, value: model.state)

                Spacer(minLength: 24)

                DetailsCard {
                    DetailRow(symbol: "wifi", color: .blue, title: "Network",
                              value: wifiName.isEmpty ? "Not Set" : wifiName)
                    Divider().padding(.leading, 58)
                    DetailRow(symbol: "person.text.rectangle.fill", color: .indigo, title: "Student ID",
                              value: studentID.isEmpty ? "Not Set" : studentID)
                    Divider().padding(.leading, 58)
                    Button {
                        showAutomationGuide = true
                    } label: {
                        DetailRow(symbol: "bolt.fill", color: .green, title: "Auto Sign-In",
                                  value: "Set Up", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                Button {
                    if hasCredentials {
                        Task { await model.connect() }
                    } else {
                        showSettings = true
                    }
                } label: {
                    Text(buttonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .disabled(model.state == .working)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, isConnected ? 4 : 12)

                if isConnected {
                    Button("Sign Out") {
                        Task { await model.signOut() }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }
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
        switch demoState {
        case "working": model.state = .working
        case "connected": model.state = .connected("You're signed in and ready to go.")
        case "failed": model.state = .failed(LoginError.stillOffline.localizedDescription)
        default: model.state = .idle
        }
        switch defaults.string(forKey: "demoScreen") {
        case "settings": showSettings = true
        case "guide": showAutomationGuide = true
        case "history":
            History.seedDemo()
            showDemoHistory = true
        default: break
        }
        return true
    }
    #endif

    private var title: String {
        switch model.state {
        case .idle: return hasCredentials ? "Ready" : "Welcome"
        case .working: return "Signing In…"
        case .connected: return "Connected"
        case .failed: return "Couldn't Sign In"
        case .signedOut: return "Signed Out"
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
                ? "Join your school's Wi-Fi, then tap Connect."
                : "Add your student ID and password to get started."
        case .working: return "Talking to your school's login page."
        case .connected(let message), .failed(let message): return message
        case .signedOut: return "You've signed out of the campus Wi-Fi."
        }
    }

    private var buttonTitle: String {
        if !hasCredentials { return "Add Student ID" }
        if case .failed = model.state { return "Try Again" }
        return "Connect"
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
        .accessibilityHidden(true)
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
    let title: String
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
