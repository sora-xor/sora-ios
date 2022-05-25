import Foundation
import UIKit
import SoraFoundation
import CommonWallet

protocol PolkaswapSlippageSelectorViewProtocol: Localizable {
    var amountInputViewModel: AmountInputViewModel? { get }
    var slippage: Double { get set }
    var warning: PolkaswapSlippageSelectorView.Warning { get set }
    func didReceive(viewModel: PolkaswapSlippageSelectorViewModel)
}

protocol PolkaswapSlippageSelectorViewDelegate: AnyObject {
    func didSelect(slippage: Double)
}

class PolkaswapSlippageSelectorView: UIView & PolkaswapSlippageSelectorViewProtocol {
    var presenter: PolkaswapSlippageSelectorPresenterProtocol?

    enum Warning {
        case none
        case mayFail
        case mayBeFrontrun
    }

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var amountField: NeuTextField!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var warningImageView: UIImageView!

    private var viewModel: PolkaswapSlippageSelectorViewModel?
    var amountInputViewModel: AmountInputViewModel?
    var amountFormatter: NumberFormatter {
        return AmountFormatterFactory().createPercentageFormatter().value(for: localizationManager?.selectedLocale ?? Locale.current)
    }

    var amountPostfix: String {
        let empty = amountFormatter.string(from: 0)
        return String(empty!.dropFirst())
    }

    weak var parentField: UITextField?
    var slippage: Double = 0.5 {
        didSet {
            amountInputViewModel?.didUpdateAmount(to: Decimal(slippage))
        }
    }
    weak var delegate: PolkaswapSlippageSelectorViewDelegate?
    var warning: Warning = .none {
        didSet {
            updateWarningText()
            updateWarningImage()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        roundCorners(corners: [.topLeft, .topRight], radius: 40.0)
    }

    // TODO: better use RoundedView instead. Unfortunately, it creates visual bug on early iOS if used as keyboard input accessory view
    func roundCorners(corners: UIRectCorner, radius: CGFloat) {
         let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
         let mask = CAShapeLayer()
         mask.path = path.cgPath
         layer.mask = mask
     }


    override func awakeFromNib() {
        super.awakeFromNib()

        setupLabels()
        setupTextField()
        setupWarningImage()

        presenter?.setup(preferredLocalizations: languages)
    }

    func didReceive(viewModel: PolkaswapSlippageSelectorViewModel) {
        self.viewModel = viewModel
        self.amountInputViewModel = viewModel.amountInputViewModel
        amountInputViewModel?.observable.add(observer: self)

        setup()
    }

    fileprivate func setup() {
        guard let viewModel = viewModel else { return }

        titleLabel.text = viewModel.title
        warningLabel.text = viewModel.warning
        warningImageView.isHidden = viewModel.warning != nil
        descriptionLabel.text = viewModel.description

        setupButtons()
    }

    fileprivate func setupLabels() {
        titleLabel?.font = UIFont.styled(for: .title4).withSize(11.0)
        titleLabel?.textColor = R.color.neumorphism.text()

        warningLabel?.font = UIFont.styled(for: .paragraph2)
        warningLabel?.textColor = R.color.neumorphism.blueCuracau()

        descriptionLabel?.font = UIFont.styled(for: .paragraph2)
        descriptionLabel?.textColor = R.color.neumorphism.text()
    }

    fileprivate func setupButtons() {
        stackView.arrangedSubviews.forEach { button in
            stackView.removeArrangedSubview(button)
            button.removeFromSuperview()
        }

        guard let buttonTitles = viewModel?.buttons else { return }
        for (index, buttonTitle) in buttonTitles.enumerated() {
            let button = slippageButton(index: index, title: buttonTitle)
            stackView.addArrangedSubview(button)
        }
        stackView.addArrangedSubview(doneButton())
    }

    fileprivate func setupTextField() {
        amountField.postfixLength = amountPostfix.count
        amountField.isChangeColorOnEdit = false
        amountField.delegate = self
    }

    fileprivate func setupWarningImage() {
        warningImageView.image = R.image.iconWarningBlue()
    }

    fileprivate func slippageButton(index: Int, title buttonTitle: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(buttonTitle, for: .normal)
        button.titleLabel?.font = UIFont.styled(for: .paragraph1).withSize(18.0)
        button.setTitleColor(R.color.brandPolkaswapPink(), for: .normal)
        button.tag = index
        button.addTarget(self, action: #selector(slippagePressed), for: .touchUpInside)
        return button
    }

    func doneButton() -> UIButton {
        let button = UIButton(type: .custom)
        let title = R.string.localizable.commonOk(preferredLanguages: languages).uppercased()
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.styled(for: .uppercase1, isBold: true).withSize(18.0)
        button.setTitleColor(R.color.brandPolkaswapPink(), for: .normal)
        button.addTarget(self, action: #selector(donePressed), for: .touchUpInside)
        return button
    }

    @objc func slippagePressed(_ button: UIButton) {
        presenter?.didSelectPredefinedSlippage(atIndex: button.tag)
    }

    @objc func donePressed(_ button: UIButton) {
        updateSlippage()
        delegate?.didSelect(slippage: slippage)
        dismiss()
    }

    func dismiss() {
        amountField.resignFirstResponder()
        parentField?.resignFirstResponder()
    }
}

extension PolkaswapSlippageSelectorView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        amountField.text = amountInputViewModel?.displayAmount
        updateSlippage()
        presenter?.didSelectSlippage(slippage)
    }
}

extension PolkaswapSlippageSelectorView: SoraTextDelegate {
    func correctedForPostfix(range: NSRange, string: String) -> NSRange {
        // deal with postfix
        guard let model = amountInputViewModel else { return range }

        var rangeWithoutPostfix = range
        if rangeWithoutPostfix.location == model.displayAmount.count + amountPostfix.count && string.count > 0 {
            // cursor after postfix, adding something
            rangeWithoutPostfix = NSRange(location: max(range.location, amountPostfix.count) - amountPostfix.count, length: range.length)
        }
        if string.count == 0 && rangeWithoutPostfix.location == model.displayAmount.count {
            // cursor after postfix, removing something,
            rangeWithoutPostfix = NSRange(location: max(range.location, amountPostfix.count) - amountPostfix.count, length: range.length)
        }
        if rangeWithoutPostfix.location + rangeWithoutPostfix.length > model.displayAmount.count {
            // cursor selected
            rangeWithoutPostfix.length = model.displayAmount.count - rangeWithoutPostfix.location
        }
        return rangeWithoutPostfix
    }

    func soraTextField(_ textField: NeuTextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {

        guard let model = amountInputViewModel,
              let keyboardSeparator = Locale.current.decimalSeparator,
              let realSeparator = localizationManager?.selectedLocale.decimalSeparator else { return false }

        let currentValue = textField.text ?? ""
        let newValue = (currentValue as NSString)
            .replacingCharacters(in: range, with: string)
            .replacingOccurrences(of: keyboardSeparator, with: realSeparator)

        if newValue.hasSuffix(realSeparator+amountPostfix) {
            return true
        }

        if newValue == amountPostfix {
            model.didUpdateAmount(to: 0)
            return true
        }

        if let number = amountFormatter.number(from: newValue) {
            model.didUpdateAmount(to: number.decimalValue)
            //dirty hack, we need to create separate input with PercentPresentable
        } else {

            let correctedRange = correctedForPostfix(range: range, string: string)
            _ = model.didReceiveReplacement(string, for: correctedRange)
        }

        updateSlippage()

        return false
    }

    fileprivate func updateSlippage() {
        guard let model = amountInputViewModel, let decimalAmount = model.decimalAmount as NSDecimalNumber? else { return }
        slippage = decimalAmount.doubleValue
    }

    fileprivate func updateWarningText() {
        switch warning {
        case .none:
            warningLabel.text = nil
        case .mayBeFrontrun:
            warningLabel.text = R.string.localizable.polkaswapSlippageFrontrun(preferredLanguages: languages)
        case .mayFail:
            warningLabel.text = R.string.localizable.polkaswapSlippageMayfail(preferredLanguages: languages)
        }
    }

    fileprivate func updateWarningImage() {
        warningImageView.isHidden = warning == .none
    }
}

extension PolkaswapSlippageSelectorView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        presenter?.setup(preferredLocalizations: languages)
    }
}
