import UIKit

private struct CompactNavigationBarFloatingConstants {
    static var compactBarKey: String = "compactBarViewKey"
    static let defaultCompactBarHeight: CGFloat = 44.0
}

final class CompactBarView: UIView {
    var topInset: CGFloat = 0.0 {
        didSet {
            titleLabelCenter.constant = topInset / 2.0
            setNeedsLayout()
        }
    }

    var backgroundImage: UIImage? {
        get {
            return backgroundImageView.image
        }

        set {
            backgroundImageView.image = newValue
        }
    }

    var shadowImage: UIImage? {
        get {
            return shadowImageView.image
        }

        set {
            shadowImageView.image = newValue
        }
    }

    private(set) var titleLabel: UILabel!
    private var backgroundImageView: UIImageView!
    private var shadowImageView: UIImageView!
    private var titleLabelCenter: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    private func configure() {
        configureShadowImageView()
        configureBackgroundImageView()
        configureTitleLabel()
    }

    private func configureBackgroundImageView() {
        backgroundImageView = UIImageView()
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundImageView)

        backgroundImageView.topAnchor
            .constraint(equalTo: topAnchor).isActive = true
        backgroundImageView.bottomAnchor
            .constraint(equalTo: shadowImageView.topAnchor).isActive = true
        backgroundImageView.leftAnchor
            .constraint(equalTo: leftAnchor).isActive = true
        backgroundImageView.rightAnchor
            .constraint(equalTo: rightAnchor).isActive = true
    }

    private func configureShadowImageView() {
        shadowImageView = UIImageView()
        shadowImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shadowImageView)

        shadowImageView.bottomAnchor
            .constraint(equalTo: bottomAnchor).isActive = true
        shadowImageView.leftAnchor
            .constraint(equalTo: leftAnchor).isActive = true
        shadowImageView.rightAnchor
            .constraint(equalTo: rightAnchor).isActive = true
    }

    private func configureTitleLabel() {
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true

        titleLabelCenter = titleLabel.centerYAnchor
            .constraint(equalTo: centerYAnchor, constant: topInset)
        titleLabelCenter.isActive = true
    }
}

public protocol CompactNavigationBarFloating: CompactBarFloating {
    var compactBarTitle: String? { get }
    var compactBarTitleAttributes: [NSAttributedString.Key: Any]? { get }
    var compactBarBackground: UIImage? { get }
    var compactBarShadow: UIImage? { get }

    func reloadCompactBar()
}

extension CompactNavigationBarFloating where Self: UIViewController {
    public var compactBar: UIView {
        get {
            let optionalBarView = objc_getAssociatedObject(self,
                                                           &CompactNavigationBarFloatingConstants.compactBarKey)

            if let barView = optionalBarView as? UIView {
                return barView
            }

            let statusBarHeight = UIApplication.shared.statusBarFrame.height
            let compactBarHeight = statusBarHeight + CompactNavigationBarFloatingConstants.defaultCompactBarHeight
            let barFrame = CGRect(origin: .zero, size: CGSize(width: view.bounds.width,
                                                              height: compactBarHeight))

            let navigationBar = createDefaultBarView(with: barFrame,
                                                     verticalInset: statusBarHeight)
            view.addSubview(navigationBar)

            navigationBar.autoresizingMask = UIView.AutoresizingMask.flexibleWidth

            self.compactBar = navigationBar

            return navigationBar
        }

        set {
            objc_setAssociatedObject(self,
                                     &CompactNavigationBarFloatingConstants.compactBarKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var compactBarTitle: String? {
        return nil
    }

    func reloadCompactBar() {
        applyStyle(to: compactBar)
    }

    // MARK: Private Default Bar View

    private var currentCompactBarTitle: String {
        return (self.compactBarTitle ?? self.title) ?? ""
    }

    private func createDefaultBarView(with frame: CGRect, verticalInset: CGFloat) -> UIView {
        let navigationBar = CompactBarView(frame: frame)
        navigationBar.topInset = verticalInset

        applyStyle(to: navigationBar)

        return navigationBar
    }

    private func applyStyle(to compactBarView: UIView) {
        if let compactBarView = compactBarView as? CompactBarView {
            compactBarView.titleLabel.text = currentCompactBarTitle
            compactBarView.backgroundImage = compactBarBackground
            compactBarView.shadowImage = compactBarShadow

            if let titleAttributes = compactBarTitleAttributes {
                compactBarView.titleLabel.textColor = titleAttributes[.foregroundColor] as? UIColor
                compactBarView.titleLabel.font = titleAttributes[.font] as? UIFont
            }
        }
    }
}
