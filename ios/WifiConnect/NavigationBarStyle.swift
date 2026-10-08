import UIKit

/// The top bar's look, from Apple's design guidance (Emil Kowalski's apple-design skill):
/// big titles a little heavier and tighter, and when the page scrolls, thick frosted glass that
/// fades softly into the content instead of ending in a hard line.
enum NavigationBarStyle {
    static func apply() {
        // Heavier and slightly tighter, still growing with the text size setting.
        let largeTitle = UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: .systemFont(ofSize: 34, weight: .heavy))
        let title = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: 17, weight: .bold))
        let largeAttributes: [NSAttributedString.Key: Any] = [.font: largeTitle, .kern: -0.68]
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: title, .kern: -0.17]

        // Scrolled: thick glass, and a soft shadow fading into the content in place of the hairline.
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.backgroundEffect = UIBlurEffect(style: .systemThickMaterial)
        scrolled.shadowColor = nil
        scrolled.shadowImage = softEdge
        scrolled.largeTitleTextAttributes = largeAttributes
        scrolled.titleTextAttributes = titleAttributes

        // At rest (nothing underneath yet): no bar at all, as before.
        let atRest = UINavigationBarAppearance()
        atRest.configureWithTransparentBackground()
        atRest.largeTitleTextAttributes = largeAttributes
        atRest.titleTextAttributes = titleAttributes

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = scrolled
        bar.compactAppearance = scrolled
        bar.scrollEdgeAppearance = atRest
        bar.compactScrollEdgeAppearance = atRest
    }

    /// A 10-point fade from a faint shadow to nothing, stretched across the bar's width.
    private static let softEdge: UIImage = {
        let size = CGSize(width: 1, height: 10)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor.black.withAlphaComponent(0.07).cgColor, UIColor.black.withAlphaComponent(0).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
        return image.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
    }()
}
