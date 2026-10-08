import AppIntents
import SwiftUI
import WidgetKit

@main
struct WifiConnectWidgets: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        if #available(iOS 18.0, *) {
            SignInControl()
        }
    }
}

// MARK: - Home Screen and Lock Screen widget

struct StatusEntry: TimelineEntry {
    let date: Date
    let status: WifiStatus
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: .now, status: .online)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(StatusEntry(date: .now, status: await WifiStatus.check())) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        Task {
            let entry = StatusEntry(date: .now, status: await WifiStatus.check())
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
        }
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WifiConnectStatus", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .widgetURL(URL(string: "wificonnect://connect"))
        }
        .configurationDisplayName("Campus Wi-Fi")
        .description("See if you're signed in, and sign in with one tap.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatusEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: entry.status.symbol)
                    .font(.title3.weight(.semibold))
            }
            .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label(entry.status.title, systemImage: entry.status.symbol)
                    .font(.headline)
                Text(entry.status.detail)
                    .font(.caption)
            }
            .containerBackground(.clear, for: .widget)
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: entry.status.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(entry.status.tint.gradient, in: Circle())
            Spacer(minLength: 4)
            // Fits the smallest widget (iPhone SE) and long translations.
            Text(entry.status.title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(entry.status.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button(intent: OpenAndConnectIntent()) {
                Text("Sign In")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.blue)
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [entry.status.tint.opacity(0.18), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

extension WifiStatus {
    var title: String {
        switch self {
        case .online: return String(localized: "Connected")
        case .loginNeeded: return String(localized: "Sign In Needed")
        case .offline: return String(localized: "No Wi-Fi")
        }
    }

    var detail: String {
        switch self {
        case .online: return String(localized: "You're online.")
        case .loginNeeded: return String(localized: "Tap to sign in to campus Wi-Fi.")
        case .offline: return String(localized: "Join campus Wi-Fi first.")
        }
    }

    var symbol: String {
        switch self {
        case .online: return "checkmark"
        case .loginNeeded: return "wifi"
        case .offline: return "wifi.slash"
        }
    }

    var tint: Color {
        switch self {
        case .online: return .green
        case .loginNeeded: return .blue
        case .offline: return .gray
        }
    }
}

// MARK: - Control Center button (iOS 18)

@available(iOS 18.0, *)
struct SignInControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "WifiConnectSignIn") {
            ControlWidgetButton(action: OpenAndConnectIntent()) {
                Label("Campus Wi-Fi", systemImage: "wifi")
            }
        }
        .displayName("Sign In to Campus Wi-Fi")
        .description("Opens WiFi Connect and signs in.")
    }
}
