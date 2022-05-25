import Foundation
import UIKit
import SoraFoundation
import SoraUI

protocol PolkaswapLiquiditySourceSelectorViewDelegate: AnyObject {
    func didSelectLiquiditySourceType(_ : LiquiditySourceType)
}

final class PolkaswapLiquiditySourceSelectorView: RoundedView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var stackView: UIStackView!

    weak var delegate: PolkaswapLiquiditySourceSelectorViewDelegate?

    var liquiditySourceTypes: [LiquiditySourceType] = [] {
        didSet {
            setup()
        }
    }
    var selectedLiquiditySourceType: LiquiditySourceType = .smart {
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
        setupButtons()
        setupDesctiptionLabel()
    }

    fileprivate func setupButtons() {
        stackView.arrangedSubviews.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        for (index, source) in liquiditySourceTypes.enumerated() {
            let button = button(for: source)
            button.tag = index
            stackView.addArrangedSubview(button)
        }
    }

    fileprivate func setupDesctiptionLabel() {
        switch selectedLiquiditySourceType {
        case .smart:
            descriptionLabel.text = R.string.localizable.polkaswapMarketSmartDescription(preferredLanguages: languages)
        case .xyk:
            descriptionLabel.text = R.string.localizable.polkaswapMarketXykDescription(preferredLanguages: languages)
        case .tbc:
            descriptionLabel.text = R.string.localizable.polkaswapMarketTbcDescription(preferredLanguages: languages)
        }
    }

    func button(for source: LiquiditySourceType) -> UIButton {
        let button = UIButton()
        //we add space to color it with chechmark. Otherwise it's hard to do.
        let attributedTitle = NSMutableAttributedString(string: source.titleForLocale(locale) + " ",
                                                        attributes: [.font: UIFont.styled(for: .paragraph1).withSize(24),
                                                                     .foregroundColor: R.color.neumorphism.text()!])
        if source == selectedLiquiditySourceType {
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

        return button
    }

    @objc func buttonPressed(_ button: UIButton) {
        selectedLiquiditySourceType = liquiditySourceTypes[button.tag]
        delegate?.didSelectLiquiditySourceType(selectedLiquiditySourceType)
    }
}

extension PolkaswapLiquiditySourceSelectorView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    private var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    func applyLocalization() {
        titleLabel.text = R.string.localizable.polkaswapMarketTitle(preferredLanguages: languages).uppercased()
        setupDesctiptionLabel()
    }
}
