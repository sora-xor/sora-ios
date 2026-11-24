import UIKit

public extension LayoutCanvas {
    /// The space between the side of a phone's window and what a screen shows: its cards, its fields
    /// and its main button all start here.
    static let pageMargin: CGFloat = 16
    /// How tall a screen's main button is, on every screen.
    static let primaryButtonHeight: CGFloat = 56
    /// The narrowest an amount or a line of text being typed may be squeezed to.
    static let minimumFieldWidth: CGFloat = 96

    /// How far the content column stands in from each side of a container `width` wide: the page margin
    /// on a phone, and in a wider window the same margin inside the readable width, centred.
    static func columnInset(forWidth width: CGFloat, margin: CGFloat = pageMargin) -> CGFloat {
        margin + readableInset(forWidth: width)
    }

    /// The width of the content column in a container `width` wide.
    static func columnWidth(forWidth width: CGFloat, margin: CGFloat = pageMargin) -> CGFloat {
        max(0, width - 2 * columnInset(forWidth: width, margin: margin))
    }
}

/// The content column of a screen, as a vertical stack: everything arranged in it runs from one page
/// margin to the other on a phone, and keeps to the readable width, centred, in a wider window.
///
/// The stack is as wide as its screen and sets its side margins from that width, so the column never
/// depends on what is in it. A column held only by a preference could be pulled in by anything inside it
/// that insisted on its own width: one button as wide as its title once made the whole swap screen a
/// third of the phone wide. What should stay small in the column (a pair of pads) is centred in a row of
/// its own, see `centred(_:)`.
public final class LitColumnStackView: UIStackView {
    /// The margin at each side on a phone.
    public var pageMargin: CGFloat = LayoutCanvas.pageMargin { didSet { applyColumn() } }
    /// Space above the first arranged view and below the last, inside the stack.
    public var topInset: CGFloat = 0 { didSet { applyColumn() } }
    public var bottomInset: CGFloat = 0 { didSet { applyColumn() } }

    private var columnWidth: CGFloat = -1

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        axis = .vertical
        alignment = .fill
        distribution = .fill
        isLayoutMarginsRelativeArrangement = true
        insetsLayoutMarginsFromSafeArea = false
        preservesSuperviewLayoutMargins = false
        applyColumn()
    }

    public override func layoutSubviews() {
        if bounds.width != columnWidth { applyColumn() }
        super.layoutSubviews()
    }

    public override var bounds: CGRect {
        didSet { if bounds.width != oldValue.width { applyColumn() } }
    }

    private func applyColumn() {
        // Before the stack has a width the phone's margin stands; a first pass of layout corrects it.
        columnWidth = bounds.width
        let side = bounds.width > 0 ? LayoutCanvas.columnInset(forWidth: bounds.width, margin: pageMargin) : pageMargin
        let wanted = UIEdgeInsets(top: topInset, left: side, bottom: bottomInset, right: side)
        if layoutMargins != wanted { layoutMargins = wanted }
    }

    /// A row of the column with `view` at its own size in the middle: for what should not stretch.
    public static func centred(_ view: UIView) -> UIView {
        let row = UIView()
        row.backgroundColor = .clear
        row.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: row.topAnchor),
            view.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            view.centerXAnchor.constraint(equalTo: row.centerXAnchor),
            view.leadingAnchor.constraint(greaterThanOrEqualTo: row.leadingAnchor),
            view.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor)
        ])
        return row
    }
}

// MARK: - The column as a guide

/// Keeps a layout guide at the content column of a view, from that view's own width.
private final class LitColumnKeeper {
    let guide = UILayoutGuide()
    private let leading: NSLayoutConstraint
    private let trailing: NSLayoutConstraint
    private var observations: [NSKeyValueObservation] = []
    private var width: CGFloat = -1

    init(view: UIView) {
        guide.identifier = "lit.column"
        view.addLayoutGuide(guide)
        leading = guide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: LayoutCanvas.pageMargin)
        trailing = view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: LayoutCanvas.pageMargin)
        NSLayoutConstraint.activate([
            leading, trailing,
            guide.topAnchor.constraint(equalTo: view.topAnchor),
            guide.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        place(in: view)
        // A view gets its size as a frame (from a container) or as bounds (from Auto Layout): both are watched.
        observations = [
            view.observe(\.bounds, options: .new) { [weak self] view, _ in self?.place(in: view) },
            view.observe(\.frame, options: .new) { [weak self] view, _ in self?.place(in: view) }
        ]
    }

    private func place(in view: UIView) {
        guard view.bounds.width != width else { return }
        width = view.bounds.width
        let inset = width > 0 ? LayoutCanvas.columnInset(forWidth: width) : LayoutCanvas.pageMargin
        leading.constant = inset
        trailing.constant = inset
    }
}

private var litColumnKey: UInt8 = 0

public extension UIView {
    /// The content column of this view, as a guide to pin a screen's cards, fields and main button to:
    /// the page margin in from each side on a phone, and in a wider window the readable width, centred,
    /// with the same margin inside it. The guide is placed from the view's own width whenever that
    /// changes, so nothing pinned to it can move or narrow it. Use it on the view that fills the screen.
    var litColumnGuide: UILayoutGuide {
        if let keeper = objc_getAssociatedObject(self, &litColumnKey) as? LitColumnKeeper { return keeper.guide }
        let keeper = LitColumnKeeper(view: self)
        objc_setAssociatedObject(self, &litColumnKey, keeper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return keeper.guide
    }
}
