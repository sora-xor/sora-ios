import UIKit

/// The room a window gives its screens, read from the window's size alone.
///
/// Every iPhone the wallet ran on before foldables is a tall, narrow window, and those keep the classic
/// layout untouched (`phone`). A folding iPhone adds two windows that are neither: a closed cover that
/// is wider and much shorter (`squat`), and an open inner screen about the size of a small tablet
/// (`wide`), which the scene moves between while the app runs. Nothing here asks which device it is:
/// a window of the same size anywhere gets the same layout.
public struct LayoutCanvas: Equatable {
    public enum Kind: Equatable {
        /// A tall phone window: the layout every iPhone has had.
        case phone
        /// A phone-width window that is short for its width, like a folded cover screen.
        case squat
        /// Roomy both ways, like an unfolded inner screen.
        case wide
    }

    /// Both sides at least this long make a window `wide`.
    public static let wideSide: CGFloat = 600
    /// A wide window at least this wide, and wider than tall, shows two pages side by side.
    public static let twoPageWidth: CGFloat = 840
    /// The widest a column of text, a list or a form grows.
    public static let readableWidth: CGFloat = 560
    /// Height over width below which a phone-width window is `squat`. The shortest iPhone before
    /// foldables is 1.775 (320 × 568, 375 × 667 and 414 × 736), so none of them is.
    public static let squatAspect: CGFloat = 1.6

    public let size: CGSize

    public init(size: CGSize) {
        self.size = size
    }

    /// The canvas of the window a view is in, or of the view itself before it has one.
    public init(view: UIView) {
        self.init(size: view.window?.bounds.size ?? view.bounds.size)
    }

    public var kind: Kind {
        guard size.width > 0, size.height > 0 else { return .phone }
        if min(size.width, size.height) >= Self.wideSide { return .wide }
        if size.width < Self.wideSide, size.height / size.width < Self.squatAspect { return .squat }
        return .phone
    }

    public var isWide: Bool { kind == .wide }

    /// Two pages side by side: the wide window in landscape.
    public var isTwoPage: Bool {
        kind == .wide && size.width >= Self.twoPageWidth && size.width > size.height
    }

    /// How far a row or a column of `width` stands in from each side so that it is no wider than the
    /// readable width. Zero on every phone: none is wider than that.
    public static func readableInset(forWidth width: CGFloat) -> CGFloat {
        guard width > readableWidth else { return 0 }
        return ((width - readableWidth) / 2).rounded(.down)
    }

    /// The two pages of a two-page canvas inside `bounds`: the areas left and right of the fold.
    /// `division` is the strip the system reserves for the fold, in the same coordinates; without one
    /// the pages meet in the middle. Nil when the canvas shows one page.
    public func pages(in bounds: CGRect, division: CGRect? = nil) -> (left: CGRect, right: CGRect)? {
        guard isTwoPage, bounds.width > 0 else { return nil }
        var gapMin = bounds.midX
        var gapMax = bounds.midX
        // Only a strip that runs down the window and sits near its middle splits it into pages.
        if let division, division.height >= bounds.height * 0.5,
           division.minX > bounds.minX + bounds.width * 0.25,
           division.maxX < bounds.maxX - bounds.width * 0.25 {
            gapMin = division.minX
            gapMax = division.maxX
        }
        let left = CGRect(x: bounds.minX, y: bounds.minY, width: gapMin - bounds.minX, height: bounds.height)
        let right = CGRect(x: gapMax, y: bounds.minY, width: bounds.maxX - gapMax, height: bounds.height)
        return (left, right)
    }

    /// The side of a square code (a QR code in its card) in a column of `columnWidth`: as wide as the
    /// column on a phone, as it always was, and no taller than leaves the rest of its card on screen
    /// where the window is short for its width.
    public func codeSide(columnWidth: CGFloat) -> CGFloat {
        switch kind {
        case .phone:
            return columnWidth
        case .squat, .wide:
            return max(160, min(columnWidth, (size.height * 0.5).rounded(.down)))
        }
    }
}
