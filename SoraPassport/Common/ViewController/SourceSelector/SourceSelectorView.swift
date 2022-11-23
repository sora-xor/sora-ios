/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit
import SoraFoundation
import SoraUI

protocol SourceSelectorViewDelegate: AnyObject {
    func didSelectSourceType(with index: Int)
}

final class SourceSelectorView: RoundedView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var stackView: UIStackView!

    weak var delegate: SourceSelectorViewDelegate?

    var titleText: String = "" {
        didSet {
            setup()
        }
    }
    var sourceTypes: [SourceType] = [] {
        didSet {
            setup()
        }
    }
    var selectedSourceTypeIndex: Int = 0 {
        didSet {
            setup()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        cornerRadius = 40.0
        shadowColor = R.color.neumorphism.base()!
        roundingCorners = [.topLeft, .topRight]

        titleLabel?.font = UIFont.styled(for: .title4).withSize(11.0)
        titleLabel?.textColor = R.color.neumorphism.text()
        descriptionLabel?.font = UIFont.styled(for: .paragraph1)
        descriptionLabel?.textColor = R.color.neumorphism.text()
    }

    func setup() {
        titleLabel.text = titleText
        setupButtons()
        setupDesctiptionLabel()
    }

    fileprivate func setupButtons() {
        stackView.arrangedSubviews.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        for (index, source) in sourceTypes.enumerated() {
            let button = button(for: source, isSelected: index == selectedSourceTypeIndex)
            button.tag = index
            stackView.addArrangedSubview(button)
        }
    }

    fileprivate func setupDesctiptionLabel() {
        guard sourceTypes.count > selectedSourceTypeIndex else { return }
        descriptionLabel.text = sourceTypes[selectedSourceTypeIndex].descriptionText
        descriptionLabel.isHidden = sourceTypes[selectedSourceTypeIndex].descriptionText == nil
    }

    func button(for source: SourceType, isSelected: Bool) -> UIButton {
        let button = UIButton()
        //we add space to color it with chechmark. Otherwise it's hard to do.
        let attributedTitle = NSMutableAttributedString(string: source.titleForLocale(locale) + " ",
                                                        attributes: [.font: UIFont.styled(for: .paragraph1).withSize(24),
                                                                     .foregroundColor: R.color.neumorphism.text()!])
        if isSelected {
            let checkmarkAttachment = NSTextAttachment()
            if #available(iOS 13.0, *) {
                checkmarkAttachment.image = R.image.about.check()?.withTintColor(R.color.neumorphism.borderFocus()!, renderingMode: .alwaysTemplate)
            } else {
                checkmarkAttachment.image = R.image.about.check()?.withRenderingMode(.alwaysTemplate)
            }

            let checkmarkString = NSMutableAttributedString(attachment: checkmarkAttachment)
            attributedTitle.append(checkmarkString)
            let range = NSRange(location: attributedTitle.length - checkmarkString.length - 1,
                                length: checkmarkString.length)
            attributedTitle.addAttributes([.foregroundColor: R.color.neumorphism.borderFocus()!],
                                          range: range)
        }
        button.setAttributedTitle(attributedTitle, for: .normal)
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return button
    }

    @objc func buttonPressed(_ button: UIButton) {
        selectedSourceTypeIndex = button.tag
        delegate?.didSelectSourceType(with: button.tag)
    }
}

extension SourceSelectorView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    private var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    func applyLocalization() {
        setupDesctiptionLabel()
    }
}
