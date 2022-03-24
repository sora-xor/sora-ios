/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI
import SoraFoundation
import Anchorage
import Then

private extension OnboardingMainViewController {
    struct Constants {
        static let logoWidth: CGFloat = 148
        static let logoHeight: CGFloat = 33
        static let logoFriction: CGFloat = 0.9
    }
}

final class OnboardingMainViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    var presenter: OnboardingMainPresenterProtocol!

    var termDecorator: AttributedStringDecoratorProtocol?

    var locale: Locale?

    private var logoWidthConstraint: NSLayoutConstraint!
    private var logoHeightConstraint: NSLayoutConstraint!

    private lazy var logoImageView: UIImageView = {
        UIImageView(image: R.image.adarMainLogo()).then {
            logoWidthConstraint = ($0.widthAnchor == Constants.logoWidth)
            logoHeightConstraint = ($0.heightAnchor == Constants.logoHeight)
        }
    }()

    private lazy var titleLabel: UILabel = {
        UILabel().then {
            $0.numberOfLines = 3
            $0.textAlignment = .center
            $0.font = UIFont.styled(for: .display1)
            $0.textColor = R.color.baseContentPrimary()
            $0.text = titleTitle
        }
    }()

    private lazy var signUpButton: SoraButton = {
        SoraButton().then {
            $0.heightAnchor == 48
            $0.tintColor = R.color.brandWhite()
            $0.roundedBackgroundView?.fillColor = R.color.themeAccent()!
            $0.roundedBackgroundView?.highlightedFillColor = R.color.themeAccentPressed()!
            $0.roundedBackgroundView?.shadowColor = .clear
            $0.changesContentOpacityWhenHighlighted = true
            $0.title = signUpTitle
            $0.imageWithTitleView?.titleColor = R.color.brandWhite()
            $0.imageWithTitleView?.displacementBetweenLabelAndIcon = 1
            $0.addTarget(self, action: #selector(actionSignup), for: .touchUpInside)
        }
    }()

    private lazy var restoreButton: SoraButton = {
        SoraButton().then {
            $0.heightAnchor == 48
            $0.tintColor = R.color.baseContentPrimary()
            $0.roundedBackgroundView?.fillColor = R.color.brandWhite()!
            $0.roundedBackgroundView?.highlightedFillColor = R.color.baseBackgroundHover()!
            $0.roundedBackgroundView?.shadowColor = .clear
            $0.changesContentOpacityWhenHighlighted = true
            $0.title = restoreTitle
            $0.imageWithTitleView?.titleColor = R.color.themeAccent()
            $0.imageWithTitleView?.displacementBetweenLabelAndIcon = 1
            $0.addTarget(self, action: #selector(actionRestoreAccess), for: .touchUpInside)
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        adjustLayout()

        presenter.setup()
    }
}

// MARK: - Texts

private extension OnboardingMainViewController {
    var languages: [String]? {
        return locale?.rLanguages
    }

    var titleTitle: String {
        return R.string.localizable
            .tutorialOneWorld(preferredLanguages: languages)
    }

    var detailTitle: String {
        return R.string.localizable
            .tutorialOneWorldDesc(preferredLanguages: languages)
    }

    var signUpTitle: String {
        return R.string.localizable
            .create_account_title(preferredLanguages: languages)
    }

    var restoreTitle: String {
        return R.string.localizable
            .recoveryTitleV2(preferredLanguages: languages)
    }
}

// MARK: - Configure

private extension OnboardingMainViewController {
    func configure() {
        createContainerView().do {
            view.addSubview($0)
            $0.edgeAnchors.verticalAnchors == view.safeAreaLayoutGuide.edgeAnchors.verticalAnchors + 8
            $0.edgeAnchors.horizontalAnchors == view.safeAreaLayoutGuide.edgeAnchors.horizontalAnchors
        }
    }

    func createContainerView() -> UIView {
        UIStackView(arrangedSubviews: [
            createContentContainerView(),
            createButtonsContainerView()
        ]).then {
            $0.axis = .vertical
            $0.spacing = 16
        }
    }

    func createContentContainerView() -> UIView {
        let container = UIView().then {
            $0.addSubview(logoImageView)
            logoImageView.topAnchor == $0.topAnchor
            logoImageView.centerXAnchor == $0.centerXAnchor
            logoImageView.bottomAnchor == $0.centerYAnchor

            $0.addSubview(titleLabel)
            titleLabel.topAnchor == logoImageView.bottomAnchor + 24
            titleLabel.horizontalAnchors == $0.horizontalAnchors
        }

        return UIView().then {
            $0.addSubview(container)
            container.centerAnchors == $0.centerAnchors
            container.horizontalAnchors == $0.horizontalAnchors + 16
        }
    }

    func createButtonsContainerView() -> UIView {
        let container = UIStackView(arrangedSubviews: [
            signUpButton,
            restoreButton
        ]).then {
            $0.axis = .vertical
            $0.spacing = 8
        }

        return UIView().then {
            $0.addSubview(container)
            container.verticalAnchors == $0.verticalAnchors
            container.horizontalAnchors == $0.horizontalAnchors + 8
        }
    }

    func adjustLayout() {
        logoWidthConstraint.constant *= designScaleRatio.height * Constants.logoFriction
        logoHeightConstraint.constant *= designScaleRatio.height * Constants.logoFriction
    }
}

// MARK: - Actions

private extension OnboardingMainViewController {
    @IBAction func actionSignup(sender: AnyObject) {
        presenter.activateSignup()
    }

    @IBAction func actionRestoreAccess(sender: AnyObject) {
        presenter.activateAccountRestore()
    }

}

extension OnboardingMainViewController: OnboardingMainViewProtocol {

}

extension UIView {
    func padding(vertical: CGFloat = 0, horizontal: CGFloat = 0) -> UIView {
        UIView().then {
            $0.backgroundColor = .clear

            $0.addSubview(self)
            $0.edgeAnchors.verticalAnchors == edgeAnchors.verticalAnchors + vertical
            $0.edgeAnchors.horizontalAnchors == edgeAnchors.horizontalAnchors + horizontal
        }
    }

    func colored(_ color: UIColor?) -> UIView {
        backgroundColor = color
        return self
    }
}
