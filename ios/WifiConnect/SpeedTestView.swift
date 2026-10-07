import SwiftUI

/// The speed test page: a live gauge, then ping, jitter, download and upload results.
struct SpeedTestView: View {
    let test: SpeedTest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Gauge(test: test)
                    .padding(.top, 12)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ResultTile(symbol: "arrow.down.circle.fill", color: .blue, title: "Download",
                               value: test.download.map(SpeedTest.format), unit: "Mbps",
                               active: test.phase == .download)
                    ResultTile(symbol: "arrow.up.circle.fill", color: .purple, title: "Upload",
                               value: test.upload.map(SpeedTest.format), unit: "Mbps",
                               active: test.phase == .upload)
                    ResultTile(symbol: "stopwatch.fill", color: .orange, title: "Ping",
                               value: test.ping.map { String(format: "%.0f", $0) }, unit: "ms",
                               active: test.phase == .ping)
                    ResultTile(symbol: "waveform.path.ecg", color: .pink, title: "Jitter",
                               value: test.jitter.map { String(format: "%.0f", $0) }, unit: "ms",
                               active: test.phase == .ping)
                }

                if case .failed(let message) = test.phase {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                Button {
                    if test.isRunning { test.stop() } else { test.start() }
                } label: {
                    Text(buttonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(test.isRunning ? .red : .blue)

                Text("Tested over the Wi-Fi only, using Cloudflare's speed test servers. On fast Wi-Fi a test can use over 100 MB of data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .animation(.default, value: test.phase)
        }
        .background {
            // A soft glow in the stage's color, seen through the glass tiles.
            RadialGradient(colors: [glow.opacity(0.28), .clear], center: UnitPoint(x: 0.5, y: 0.22),
                           startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: test.phase)
        }
        .navigationTitle("Speed Test")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    test.stop()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .sensoryFeedback(.success, trigger: test.phase == .done)
    }

    private var glow: Color {
        switch test.phase {
        case .ping: return .orange
        case .upload: return .purple
        case .failed: return .orange
        default: return .blue
        }
    }

    private var buttonTitle: String {
        if test.isRunning { return String(localized: "Stop") }
        if test.phase == .idle { return String(localized: "Start") }
        return String(localized: "Test Again")
    }
}

/// A 270° gauge with the live speed in the middle.
private struct Gauge: View {
    let test: SpeedTest

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color(.tertiarySystemFill), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * fill)
                .stroke(
                    AngularGradient(colors: colors, center: .center, startAngle: .degrees(0), endAngle: .degrees(270)),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .shadow(color: colors.last!.opacity(0.4), radius: 10)
                .animation(.easeOut(duration: 0.3), value: fill)

            VStack(spacing: 4) {
                Label(stageTitle, systemImage: stageSymbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.last!)
                Text(number)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: number)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 260, height: 260)
        .accessibilityElement(children: .combine)
    }

    /// Log scale up to 1 Gbps, so everyday speeds still move the gauge.
    private var fill: Double {
        switch test.phase {
        case .ping: return test.progress
        case .download, .upload: return min(log10(1 + test.liveMbps) / log10(1001), 1)
        case .done: return 1
        default: return 0
        }
    }

    private var number: String {
        switch test.phase {
        case .ping: return test.ping.map { String(format: "%.0f", $0) } ?? "–"
        case .download, .upload: return SpeedTest.format(test.liveMbps)
        case .done: return test.download.map(SpeedTest.format) ?? "–"
        default: return "–"
        }
    }

    private var unit: String {
        test.phase == .ping ? "ms" : "Mbps"
    }

    private var stageTitle: String {
        switch test.phase {
        case .idle: return String(localized: "Ready")
        case .ping: return String(localized: "Ping")
        case .download: return String(localized: "Download")
        case .upload: return String(localized: "Upload")
        case .done: return String(localized: "Download")
        case .failed: return String(localized: "Couldn't Test")
        }
    }

    private var stageSymbol: String {
        switch test.phase {
        case .ping: return "stopwatch.fill"
        case .upload: return "arrow.up.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        default: return "arrow.down.circle.fill"
        }
    }

    private var colors: [Color] {
        switch test.phase {
        case .ping: return [.yellow, .orange]
        case .upload: return [.pink, .purple]
        case .failed: return [.orange, .orange]
        default: return [.cyan, .blue]
        }
    }
}

private struct ResultTile: View {
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let value: String?
    let unit: String
    let active: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value ?? "–")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(color.opacity(active ? 0.8 : 0), lineWidth: 2)
        }
        .animation(.default, value: active)
    }
}
