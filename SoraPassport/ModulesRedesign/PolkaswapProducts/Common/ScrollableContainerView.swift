import UIKit
import SoraUIKit

final class ScrollableContainerView: UIView {
    private(set) var scrollView = UIScrollView()
    /// The screen's content column: see `LitColumnStackView`.
    private(set) var stackView = LitColumnStackView()

    private var scrollBottom: NSLayoutConstraint!

    var scrollBottomOffset: CGFloat {
        get {
            -scrollBottom.constant
        }

        set {
            scrollBottom.constant = -newValue

            if superview != nil {
                setNeedsLayout()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureScrollView()
        configureStackView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addArrangedSubview(_ view: UIView) {
        stackView.addArrangedSubview(view)
    }

    func setCustomSpacing(_ spacing: CGFloat, after arrangedSubview: UIView) {
        stackView.setCustomSpacing(spacing, after: arrangedSubview)
    }

    private func configureScrollView() {
        scrollView.backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        scrollView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor).isActive = true

        let bottomConstraint = scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomConstraint.isActive = true

        scrollBottom = bottomConstraint
    }

    private func configureStackView() {
        stackView.backgroundColor = .clear
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(stackView)

        // The stack is as wide as the screen whatever is in it; the column inside it is the stack's own
        // margins: the page margin on a phone, a readable column in the middle of a wider window.
        NSLayoutConstraint.activate([
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])
    }
}
