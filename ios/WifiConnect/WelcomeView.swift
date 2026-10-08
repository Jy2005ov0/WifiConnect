import SwiftUI

/// The first page when the app opens: the time and a welcome.
/// Swipe it up, like the Lock Screen, to get to the app.
struct WelcomeView: View {
    var onFinish: () -> Void

    @State private var drag: CGFloat = 0
    // The big clock grows with the text size setting, like the rest of the page.
    @ScaledMetric(relativeTo: .largeTitle) private var clockSize: CGFloat = 88

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            VStack(spacing: 0) {
                Spacer()

                // Design A, with the time where the logo was.
                TimelineView(.everyMinute) { context in
                    let now = WelcomeView.clockDate(context.date)
                    VStack(spacing: 0) {
                        Text(now, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(now, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                            .font(.system(size: clockSize, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                    }
                }

                Text("Welcome")
                    .font(.largeTitle.weight(.bold))
                    .padding(.top, 20)
                Text("Ready to sign in to campus Wi-Fi.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                Spacer()

                // Just the words, like the hint on the Lock Screen. It bobs up and down with the
                // clock, so it doesn't jump back to the start after Notification Center is pulled down.
                TimelineView(.animation) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.up")
                            .font(.subheadline.weight(.bold))
                        Text("Swipe up to start")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .offset(y: -3 + 3 * cos(phase * 2 * .pi))
                }
                .padding(.bottom, 20)
                .contentShape(Rectangle())
                .onTapGesture { finish(height: height) }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            // Frosted glass: the app shows through, blurred, behind the welcome.
            .background(Rectangle().fill(.regularMaterial).ignoresSafeArea())
            .offset(y: drag)
            .opacity(1 - Double(min(-drag / height, 1)) * 0.6)
            .gesture(
                DragGesture()
                    .onChanged { drag = min(0, $0.translation.height) }
                    .onEnded { value in
                        if -value.predictedEndTranslation.height > height * 0.3 || -value.translation.height > height * 0.2 {
                            finish(height: height)
                        } else {
                            withAnimation(.spring(duration: 0.35)) { drag = 0 }
                        }
                    }
            )
            .accessibilityAction(named: Text("Swipe up to start")) { onFinish() }
        }
    }

    private func finish(height: CGFloat) {
        withAnimation(.spring(duration: 0.45)) {
            drag = -height
        } completion: {
            onFinish()
        }
    }

    /// The README screenshots show 9:41, like Apple's.
    private static func clockDate(_ date: Date) -> Date {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "demoState") != nil {
            return Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: date) ?? date
        }
        #endif
        return date
    }
}
