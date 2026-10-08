import SwiftUI
import UIKit

/// Recent sign-ins, with a button to copy a diagnostics report.
struct HistoryView: View {
    @State private var entries = History.load()
    @State private var copied = false
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                Button {
                    UIPasteboard.general.string = Diagnostics.report()
                    withAnimation { copied = true }
                } label: {
                    Label(copied ? String(localized: "Copied") : String(localized: "Copy Diagnostics"),
                          systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                }
                .sensoryFeedback(.success, trigger: copied)
            } footer: {
                Text("If signing in doesn't work, copy this report and send it to whoever helps you with the app. It includes the login page details but never your password.")
            }

            if entries.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Sign-Ins Yet",
                        systemImage: "clock",
                        description: Text("Sign-ins will appear here, including automatic ones.")
                    )
                }
                .listRowBackground(Color.clear)
            } else {
                Section("Recent") {
                    ForEach(entries) { entry in
                        HistoryRow(entry: entry)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Sign-In History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) { confirmClear = true }
                }
            }
        }
        .confirmationDialog("Clear sign-in history?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) {
                History.clear()
                withAnimation { entries = [] }
            }
        }
        .onAppear { entries = History.load() }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title).font(.body.weight(.medium))
                    Spacer()
                    Text(entry.date, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(triggerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let message = entry.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                if let host = entry.portal.flatMap({ URL(string: $0)?.host }) {
                    Text(host)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        switch entry.result {
        case .signedIn: return String(localized: "Signed In")
        case .alreadyOnline: return String(localized: "Already Online")
        case .failed: return String(localized: "Couldn't Sign In")
        case .signedOut: return String(localized: "Signed Out")
        }
    }

    private var symbol: String {
        switch entry.result {
        case .signedIn: return "checkmark"
        case .alreadyOnline: return "wifi"
        case .failed: return "xmark"
        case .signedOut: return "rectangle.portrait.and.arrow.right"
        }
    }

    private var tint: Color {
        switch entry.result {
        case .signedIn: return .green
        case .alreadyOnline: return .blue
        case .failed: return .orange
        case .signedOut: return .gray
        }
    }

    private var triggerText: String {
        switch entry.trigger {
        case .app: return String(localized: "From the app")
        case .automatic: return String(localized: "When you opened the app")
        case .shortcut: return String(localized: "Shortcuts automation")
        case .widget: return String(localized: "Widget or Control Center")
        case .background: return String(localized: "Stay Signed In")
        }
    }
}

#if DEBUG
extension History {
    /// Sample entries for the README screenshots.
    static func seedDemo() {
        let now = Date()
        save([
            HistoryEntry(date: now.addingTimeInterval(-120), trigger: .shortcut, result: .signedIn,
                         portal: "http://10.1.0.1/login.html", duration: 1.8),
            HistoryEntry(date: now.addingTimeInterval(-3_700), trigger: .background, result: .signedIn,
                         portal: "http://10.2.0.1/login.html", duration: 2.1),
            HistoryEntry(date: now.addingTimeInterval(-7_400), trigger: .app, result: .alreadyOnline, duration: 0.4),
            HistoryEntry(date: now.addingTimeInterval(-90_000), trigger: .shortcut, result: .failed,
                         message: LoginError.stillOffline.localizedDescription,
                         portal: "http://10.1.0.1/login.html", duration: 6.9),
        ])
    }
}
#endif
