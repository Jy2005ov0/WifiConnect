import SwiftUI

/// Walks through creating a Shortcuts automation that signs in whenever you join the school Wi-Fi.
struct AutomationGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.wifiName) private var wifiName = SettingsKey.defaultWifiName

    private var networkName: String {
        wifiName.isEmpty ? String(localized: "your school Wi-Fi") : "“\(wifiName)”"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.tint)
                        Text("Sign In Automatically")
                            .font(.title2.weight(.bold))
                        Text("Let your iPhone sign in for you every time you arrive on campus.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("In the Shortcuts app") {
                    Step(number: 1, text: "Tap **Automation**, then tap **+** (or **New Automation**).")
                    Step(number: 2, text: "Choose **Wi-Fi**, tap **Network** and pick \(networkName).")
                    Step(number: 3, text: "Select **Run Immediately**, then tap **Next**.")
                    Step(number: 4, text: "Tap **New Blank Automation**, search for **WiFi Connect** and add **Log In to Campus Wi-Fi**.")
                    Step(number: 5, text: "Tap **Done**. That's it!")
                }

                Section {
                    Label {
                        Text("To stop the login page from popping up, open **Settings › Wi-Fi**, tap **ⓘ** next to \(networkName) and turn off **Auto-Login**.")
                    } icon: {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.yellow)
                    }
                    .font(.subheadline)
                } header: {
                    Text("Tip")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    openURL(URL(string: "shortcuts://")!)
                } label: {
                    Text("Open Shortcuts")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct Step: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.tint))
            Text(text)
                .font(.callout)
                .padding(.top, 3)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    AutomationGuideView()
}
