import SwiftUI
import UIKit

/// The app's light/dark setting. "System" follows the iPhone's own setting.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    private var style: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Applies the style to every window, so open sheets switch too.
    /// When animated, the old look dissolves into the new one, like switching Dark Mode in Control Center.
    func apply(animated: Bool = false) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.overrideUserInterfaceStyle != style {
                if animated {
                    UIView.transition(
                        with: window,
                        duration: 0.45,
                        options: [.transitionCrossDissolve, .allowUserInteraction]
                    ) {
                        window.overrideUserInterfaceStyle = style
                    }
                } else {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
}

/// A toolbar button that switches between System, Light and Dark.
struct AppearanceMenu: View {
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system

    var body: some View {
        Menu {
            Picker("Appearance", selection: $appearance) {
                ForEach(Appearance.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
        } label: {
            Image(systemName: appearance.symbol)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel("Appearance")
    }
}

/// A fully rounded System / Light / Dark switch. The selected pill slides between options.
struct AppearancePicker: View {
    @Binding var selection: Appearance
    @Namespace private var namespace
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Appearance.allCases) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selection = option
                    }
                } label: {
                    Image(systemName: option.symbol)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(colorScheme == .dark ? Color(.systemGray3) : .white)
                                    .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color(.tertiarySystemFill), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}
