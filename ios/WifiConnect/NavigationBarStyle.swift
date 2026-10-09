import UIKit

/// The top bar's titles, from Apple's design guidance (Emil Kowalski's apple-design skill): big
/// titles a little heavier and tighter. The bar itself keeps the system's behavior (clear at the
/// top, frosted glass once the page scrolls), which SwiftUI only gets right with its own
/// backgrounds: replacing them with custom ones left the frosted bar showing at rest.
enum NavigationBarStyle {
    static func apply() {
        // Heavier and slightly tighter, still growing with the text size setting, but capped so
        // the titles fit their bars at the largest accessibility sizes.
        let traits = UITraitCollection(preferredContentSizeCategory: UIApplication.shared.preferredContentSizeCategory)
        let largeTitle = UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: .systemFont(ofSize: 34, weight: .heavy), maximumPointSize: 44, compatibleWith: traits)
        let title = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: 17, weight: .bold), maximumPointSize: 22, compatibleWith: traits)

        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: largeTitle, .kern: -0.68]
        bar.titleTextAttributes = [.font: title, .kern: -0.17]
    }

    /// Applies the style now and again whenever the text size setting changes.
    static func applyAndFollowTextSize() {
        apply()
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main
        ) { _ in apply() }
    }
}
