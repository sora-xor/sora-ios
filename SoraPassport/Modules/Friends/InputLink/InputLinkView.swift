/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit
import SoraFoundation
import SoraUI
import Anchorage

protocol InputLinkViewDelegate: AnyObject {
    func userChangeTextField(with text: String)
    func userTappedonActivete(with text: String)
}

enum InputLinkActivateButtonState {
    case enabled
    case disabled
    
    var textColor: UIColor? {
        switch self {
        case .enabled: return R.color.brandWhite() ?? .white
        case .disabled: return R.color.neumorphism.buttonTextDisabled() ?? .white
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .enabled: return R.color.neumorphism.tint() ?? .red
        case .disabled: return R.color.neumorphism.shareButtonGrey() ?? .gray
        }
    }

    var isEnabled: Bool {
        return self == .enabled
    }
}

final class InputLinkView: RoundedView {

    private struct Constants {
        static let titleLabelTopOffset = CGFloat(20)
        static let titleHeight = CGFloat(11)
        static let descriptionTopOffset = CGFloat(16)
        static let textFieldTopOffset = CGFloat(16)
        static let textFieldHeigt = CGFloat(56)
        static let activateButtonTopOffset = CGFloat(16)
        static let activateButtonHeight = CGFloat(56)
        static let activateButtonBottomOffset = CGFloat(24)
    }

    weak var delegate: InputLinkViewDelegate?

    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4).withSize(11.0)
            $0.textColor = R.color.neumorphism.text()
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var descriptionLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title1)
            $0.textColor = R.color.brandUltraBlack()
            $0.numberOfLines = 0
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.setContentHuggingPriority(.required, for: .vertical)
        }
    }()

    lazy var textField: RoundTextField = {
        RoundTextField().then {
            $0.font = UIFont.styled(for: .title1)
            $0.textColor = R.color.neumorphism.textDark()
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
            $0.placeholder = R.string.localizable.referralReferralLink(preferredLanguages: .currentLocale)
        }
    }()

    var activateButton: NeumorphismButton = {
        NeumorphismButton().then {
            $0.forceUppercase = false
            $0.heightAnchor == 56
            $0.color = R.color.neumorphism.shareButtonGrey() ?? .white
            $0.setTitleColor(R.color.neumorphism.buttonTextDisabled() ?? .gray, for: .normal) 
            $0.font = UIFont.styled(for: .button)
            $0.isEnabled = false
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(nil, action: #selector(activeLinkTapped), for: .touchUpInside)
        }
    }()

    lazy var gradient: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.type = .radial
        gradient.colors = [
            R.color.neumorphism.shadowLightGray()!.cgColor,
            R.color.neumorphism.shadowSuperLightGray()!.cgColor
        ]
        gradient.cornerRadius = 24
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.locations = [ 0.5, 1 ]
        return gradient
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        cornerRadius = 40.0
        shadowColor = R.color.neumorphism.base()!
        roundingCorners = [.topLeft, .topRight]

        textField.layer.addSublayer(gradient)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(textField)
        addSubview(activateButton)

        titleLabel.do {
            $0.centerXAnchor == centerXAnchor
            $0.topAnchor == topAnchor + Constants.titleLabelTopOffset
            $0.heightAnchor == Constants.titleHeight
        }

        descriptionLabel.do {
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor + 24
            $0.topAnchor == titleLabel.bottomAnchor + Constants.descriptionTopOffset
        }

        textField.do {
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor + 24
            $0.topAnchor == descriptionLabel.bottomAnchor + Constants.textFieldTopOffset
            $0.heightAnchor == Constants.textFieldHeigt
        }

        activateButton.do {
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor + 24
            $0.topAnchor == textField.bottomAnchor + Constants.activateButtonTopOffset
            $0.heightAnchor == Constants.activateButtonHeight
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        var height: CGFloat = [ Constants.titleLabelTopOffset,
                                Constants.titleHeight,
                                Constants.descriptionTopOffset,
                                Constants.textFieldTopOffset,
                                Constants.textFieldHeigt,
                                Constants.activateButtonHeight ].reduce(0, +)
        height += descriptionLabel.intrinsicContentSize.height 
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }


    override func layoutSubviews() {
        super.layoutSubviews()

        let endX = 1 + textField.bounds.size.height / textField.bounds.size.width
        gradient.endPoint = CGPoint(x: endX, y: 1)

        gradient.frame = textField.bounds
    }

    @objc
    func textFieldDidChange() {
        delegate?.userChangeTextField(with: textField.text ?? "")
    }

    @objc
    private func activeLinkTapped() {
        delegate?.userTappedonActivete(with: textField.text ?? "")
    }
}

extension InputLinkView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        titleLabel.text = R.string.localizable.referralEnterLinkTitle(preferredLanguages: languages).uppercased()
        descriptionLabel.text = R.string.localizable.referralReferrerDescription(preferredLanguages: languages)
        activateButton.buttonTitle = R.string.localizable.referralActivateButtonTitle(preferredLanguages: languages)
    }
}
