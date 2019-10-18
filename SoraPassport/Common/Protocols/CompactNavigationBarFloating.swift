/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
        set {
            backgroundImageView.image = newValue
        }

        get {
            return backgroundImageView.image
        }
    }

    var shadowImage: UIImage? {
        set {
            shadowImageView.image = newValue
        }

        get {
            return shadowImageView.image
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
}

extension CompactNavigationBarFloating where Self: UIViewController {
    public var compactBar: UIView {
        set {
            objc_setAssociatedObject(self,
                                     &CompactNavigationBarFloatingConstants.compactBarKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }

        get {
            let optionalBarView = objc_getAssociatedObject(self,
                                                           &CompactNavigationBarFloatingConstants.compactBarKey)

            if let barView = optionalBarView as? UIView {
                return barView
            }

            let currentTitle = (self.compactBarTitle ?? self.title) ?? ""
            let statusBarHeight = UIApplication.shared.statusBarFrame.height
            let compactBarHeight = statusBarHeight + CompactNavigationBarFloatingConstants.defaultCompactBarHeight
            let barFrame = CGRect(origin: .zero, size: CGSize(width: view.bounds.width,
                                                              height: compactBarHeight))

            let navigationBar = createDefaultBarView(with: currentTitle,
                                                     frame: barFrame,
                                                     verticalInset: statusBarHeight)
            view.addSubview(navigationBar)

            navigationBar.autoresizingMask = UIView.AutoresizingMask.flexibleWidth

            self.compactBar = navigationBar

            return navigationBar
        }
    }

    var compactBarTitle: String? {
        return nil
    }

    // MARK: Private

    private func createDefaultBarView(with title: String, frame: CGRect, verticalInset: CGFloat) -> UIView {
        let navigationBar = CompactBarView(frame: frame)
        navigationBar.topInset = verticalInset
        navigationBar.titleLabel.text = title
        navigationBar.backgroundImage = compactBarBackground
        navigationBar.shadowImage = compactBarShadow

        if let titleAttributes = compactBarTitleAttributes {
            navigationBar.titleLabel.textColor = titleAttributes[.foregroundColor] as? UIColor
            navigationBar.titleLabel.font = titleAttributes[.font] as? UIFont
        }

        return navigationBar
    }
}
