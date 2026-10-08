import SwiftUI

/// The ? button's guide: how to use the app, one step at a time.
struct HowToView: View {
    /// What a step's button asks the main screen to open once the guide has closed.
    enum Destination { case settings, autoSignIn }

    var hasCredentials: Bool
    var open: (Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.wifiName) private var wifiName = SettingsKey.defaultWifiName
    @State private var index = 0

    private struct Step: Identifiable {
        let id: Int
        let symbol: String
        let color: Color
        let title: String
        let text: String
        var button: (title: String, destination: Destination)?
        var done = false
    }

    private var networkName: String {
        wifiName.isEmpty ? String(localized: "your school Wi-Fi") : wifiName
    }

    private var steps: [Step] {
        [
            Step(id: 0, symbol: "person.text.rectangle.fill", color: .indigo,
                 title: String(localized: "Add your student ID"),
                 text: String(localized: "Tap Open Settings and type your student ID and password. They're saved only on this phone."),
                 button: (String(localized: "Open Settings"), .settings), done: hasCredentials),
            Step(id: 1, symbol: "wifi", color: .blue,
                 title: String(localized: "Join the campus Wi-Fi"),
                 text: String(localized: "Open your phone's Wi-Fi settings and join \(networkName). If a login page pops up, you can close it.")),
            Step(id: 2, symbol: "hand.tap.fill", color: .blue,
                 title: String(localized: "Tap the blue circle"),
                 text: String(localized: "Come back to WiFi Connect and tap the big blue circle. The app finds the login page and signs you in.")),
            Step(id: 3, symbol: "checkmark.circle.fill", color: .green,
                 title: String(localized: "Green means you're online"),
                 text: String(localized: "When the circle turns green, the internet works. Tap the green circle when you want to sign out.")),
            Step(id: 4, symbol: "bolt.fill", color: .orange,
                 title: String(localized: "Sign in automatically"),
                 text: String(localized: "Set up a Shortcuts automation once, and your iPhone signs in every time you join \(networkName)."),
                 button: (String(localized: "Set Up Auto Sign-In"), .autoSignIn)),
            Step(id: 5, symbol: "questionmark.circle.fill", color: .pink,
                 title: String(localized: "If something goes wrong"),
                 text: String(localized: "Open Settings › Sign-In History to see what happened, and tap Copy Diagnostics to share the details. Then join the Wi-Fi again and tap the circle.")),
        ]
    }

    var body: some View {
        let steps = steps
        let isLast = index == steps.count - 1
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $index) {
                    ForEach(steps) { step in
                        page(step).tag(step.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Where you are: a dot per step, the current one longer.
                HStack(spacing: 6) {
                    ForEach(steps) { step in
                        Capsule()
                            .fill(step.id == index ? Color.accentColor : Color(.tertiaryLabel))
                            .frame(width: step.id == index ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring(duration: 0.35), value: index)
                .accessibilityHidden(true)
                .padding(.bottom, 18)

                HStack(spacing: 12) {
                    if index > 0 {
                        Button {
                            withAnimation { index -= 1 }
                        } label: {
                            Text("Back").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    Button {
                        if isLast { dismiss() } else { withAnimation { index += 1 } }
                    } label: {
                        Text(isLast ? String(localized: "Got It") : String(localized: "Next"))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .navigationTitle("How to Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.selection, trigger: index)
        }
    }

    private func page(_ step: Step) -> some View {
        let number = step.id + 1
        let total = steps.count
        return ScrollView {
            VStack(spacing: 16) {
                Text("Step \(number) of \(total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)

                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: step.symbol)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(step.color.gradient, in: Circle())
                        .accessibilityHidden(true)
                    if step.done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, .green)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, 8)

                Text(step.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    // VoiceOver hears the tick as part of the step: "Add your student ID, Completed".
                    .accessibilityValue(step.done ? Text("Completed") : Text(""))
                Text(step.text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let button = step.button {
                    Button {
                        dismiss()
                        open(button.destination)
                    } label: {
                        Text(button.title)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
