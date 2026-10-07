import SwiftUI

/// The first page when the app opens. Swipe it up, like the Lock Screen, to get to the app.
struct WelcomeView: View {
    var onFinish: () -> Void

    @State private var drag: CGFloat = 0
    @State private var bounce = false

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            VStack(spacing: 0) {
                Spacer()

                Image("Logo")
                    .resizable()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 10)

                Text("Welcome")
                    .font(.largeTitle.weight(.bold))
                    .padding(.top, 28)
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
}
