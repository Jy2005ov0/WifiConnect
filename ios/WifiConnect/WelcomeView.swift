import SwiftUI

/// The first page when the app opens: the time and a welcome.
/// Swipe it up, like the Lock Screen, to get to the app.
struct WelcomeView: View {
    var onFinish: () -> Void

    @State private var drag: CGFloat = 0
    /// With Reduce Motion on, the page fades away instead of sliding.
    @State private var fading = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                // A button too, so VoiceOver offers it and a tap works.
                Button {
                    finish(height: height)
                } label: {
                    TimelineView(.animation(paused: reduceMotion)) { context in
                        let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.up")
                                .font(.subheadline.weight(.bold))
                                .accessibilityHidden(true)
                            Text("Swipe up to start")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .offset(y: reduceMotion ? 0 : -3 + 3 * cos(phase * 2 * .pi))
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            // Frosted glass: the app shows through, blurred, behind the welcome.
            .background(Rectangle().fill(.regularMaterial).ignoresSafeArea())
            .offset(y: drag)
            .opacity(fading ? 0 : 1 - Double(min(max(-drag, 0) / height, 1)) * 0.6)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Up follows the finger 1:1. Down stretches less the further you pull, like
                        // iOS at the edge of a list, instead of stopping dead.
                        let y = value.translation.height
                        drag = y < 0 ? y : Self.rubberBand(y, dimension: height)
                    }
                    .onEnded { value in
                        // Decide by where the flick is heading, not just where the finger let go.
                        let projected = value.predictedEndTranslation.height
                        let velocity = value.velocity.height
                        if velocity < 300, -projected > height * 0.3 || -value.translation.height > height * 0.2 {
                            finish(height: height, velocity: velocity)
                        } else {
                            settle(velocity: velocity)
                        }
                    }
            )
            .accessibilityAction(named: Text("Swipe up to start")) { onFinish() }
        }
    }

    /// Slides the page away, carrying on at the speed of the finger that flicked it.
    private func finish(height: CGFloat, velocity: CGFloat = 0) {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) { fading = true } completion: { onFinish() }
            return
        }
        withAnimation(.interpolatingSpring(duration: 0.4, bounce: 0,
                                           initialVelocity: Self.relative(velocity, from: drag, to: -height))) {
            drag = -height
        } completion: {
            onFinish()
        }
    }

    /// Springs back into place. A little bounce, because a flick put momentum into it.
    private func settle(velocity: CGFloat) {
        withAnimation(.interpolatingSpring(duration: 0.35, bounce: reduceMotion ? 0 : 0.2,
                                           initialVelocity: Self.relative(velocity, from: drag, to: 0))) {
            drag = 0
        }
    }

    /// A spring's starting speed is relative to the distance it still has to go.
    private static func relative(_ velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Double {
        let distance = target - current
        return abs(distance) < 1 ? 0 : Double(velocity / distance)
    }

    /// How far the page follows when pulled past its resting place: less and less, never a hard stop.
    private static func rubberBand(_ overshoot: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
        overshoot * dimension * constant / (dimension + constant * abs(overshoot))
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
