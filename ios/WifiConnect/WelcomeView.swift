import SwiftUI

/// The first page when the app opens: the time and a welcome.
/// Swipe it up, like the Lock Screen, to get to the app.
struct WelcomeView: View {
    var onFinish: () -> Void

    @State private var drag: CGFloat = 0
    @State private var bounce = false

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
                        Text(now, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                            .font(.system(size: 88, weight: .bold, design: .rounded))
                            .monospacedDigit()
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

                VStack(spacing: 8) {
                    Image(systemName: "chevron.up")
                        .font(.title3.weight(.semibold))
                        .offset(y: bounce ? -6 : 2)
                    Text("Swipe up to start")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
                .contentShape(Rectangle())
                .onTapGesture { finish(height: height) }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bounce = true }
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
