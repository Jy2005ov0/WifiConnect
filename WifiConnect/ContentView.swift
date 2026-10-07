import SwiftUI

struct ContentView: View {
    @State private var model = ConnectionModel()
    @State private var hasCredentials = Credentials.isConfigured
    @State private var showSettings = false
    @State private var showAutomationGuide = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                StatusBadge(state: model.state)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 28)
                .padding(.horizontal, 32)
                .animation(.default, value: model.state)

                Spacer()

                VStack(spacing: 14) {
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

                    Button("Set Up Auto-Connect") {
                        showAutomationGuide = true
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .navigationTitle("Campus Wi-Fi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                hasCredentials = Credentials.isConfigured
            }) {
                SettingsView()
            }
            .sheet(isPresented: $showAutomationGuide) {
                AutomationGuideView()
            }
            .sensoryFeedback(trigger: model.state) { _, new in
                switch new {
                case .connected: return .success
                case .failed: return .error
                default: return nil
                }
            }
            .onAppear {
                if !hasCredentials { showSettings = true }
            }
            .onChange(of: scenePhase) {
                // Opening the app on campus signs you in straight away.
                if scenePhase == .active, hasCredentials, model.state != .working {
                    Task { await model.connect(automatic: true) }
                }
            }
        }
    }

    private var title: String {
        switch model.state {
        case .idle: return hasCredentials ? "Ready" : "Welcome"
        case .working: return "Signing In…"
        case .connected: return "Connected"
        case .failed: return "Couldn't Sign In"
        }
    }

    private var subtitle: String {
        switch model.state {
        case .idle:
            return hasCredentials
                ? "Join your school's Wi-Fi, then tap Connect."
                : "Add your student ID and password to get started."
        case .working: return "Talking to your school's login page."
        case .connected(let message), .failed(let message): return message
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

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 168, height: 168)
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 124, height: 124)
            Image(systemName: symbol)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.variableColor.iterative, isActive: state == .working)
        }
        .animation(.spring(duration: 0.4), value: state)
        .accessibilityHidden(true)
    }

    private var symbol: String {
        switch state {
        case .idle, .working: return "wifi"
        case .connected: return "checkmark"
        case .failed: return "wifi.exclamationmark"
        }
    }

    private var tint: Color {
        switch state {
        case .idle, .working: return .accentColor
        case .connected: return .green
        case .failed: return .orange
        }
    }
}

#Preview {
    ContentView()
}
