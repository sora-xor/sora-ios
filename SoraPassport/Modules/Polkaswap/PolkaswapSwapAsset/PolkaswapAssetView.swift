import Foundation
import UIKit
import SoraFoundation
import CommonWallet

protocol PolkaswapAssetViewDelegate: AnyObject {
    func didPressAsset(_: PolkaswapAssetView)
    func didChangeAmount(_: Decimal?, view: PolkaswapAssetView)
    func didChangePredefinedPercentage(_: Decimal, view: PolkaswapAssetView)
}

struct PolkaswapAssetViewModel {
    let isEmpty: Bool
    let assetImageViewModel: WalletImageViewModelProtocol?
    let amountInputViewModel: PolkaswapAmountInputViewModelProtocol?
    let assetName: String?
}

class PolkaswapAssetView: UIView {

    weak var delegate: PolkaswapAssetViewDelegate?

    @IBOutlet var containerView: UIView!
    @IBOutlet weak var fromToLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var balanceValueLabel: UILabel!
    @IBOutlet weak var amountField: PolkaswapAmountField!
    @IBOutlet weak var assetButton: PswapButton!
    
    var viewModel: PolkaswapAssetViewModel?

    var isFirstAsset: Bool = true

    var isAssetChangeable: Bool = true {
        didSet {
            if !isAssetChangeable {
                assetButton.isUserInteractionEnabled = false
                assetButton.rightImageView.isHidden = true
            }
        }
    }

    var isAmountChangeable: Bool = true

    var isBalanceHidden: Bool = false {
        didSet {
            if isBalanceHidden {
                balanceLabel.isHidden = true
                balanceValueLabel.isHidden = true
            }
        }
    }

    var isFrom: Bool = true {
        didSet {
            applyLocalization()
        }
    }

    func setBalance(_ string: String?) {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        self.balanceValueLabel.attributedText = string?.prettyCurrency(baseFont: self.balanceValueLabel.font, locale: locale)
    }

    func setAmount(_ amount: Decimal, formatter: NumberFormatter) {
        if let replacement = formatter.stringFromDecimal(amount) {
            let oldToAmountText = amountField.text ?? ""
            let replacementRange = NSRange(location: 0, length: oldToAmountText.count)
            _ = viewModel?.amountInputViewModel?.didReceiveReplacement(replacement, for: replacementRange, isNotificationEnabled: false)
        }
        amountField.text = viewModel?.amountInputViewModel?.displayAmount ?? "0"
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initNib()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initNib()
    }

    func initNib() {
        let bundle = Bundle(for: PolkaswapAssetView.self)
        bundle.loadNibNamed("PolkaswapAssetView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        containerView.backgroundColor = R.color.neumorphism.base()
        setup()
    }
    
    func didReceive(viewModel: PolkaswapAssetViewModel) {
        self.viewModel = viewModel
        guard !viewModel.isEmpty else {
            setEmpty()
            return
        }
        gestureRecognizers?.removeAll()
        amountField.isUserInteractionEnabled = isAmountChangeable
        assetButton.shortCustomLabel.text = viewModel.assetName
        viewModel.assetImageViewModel?.loadImage { [weak self] (icon, _) in
            self?.assetButton.leftImageView.image = icon
        }
        viewModel.amountInputViewModel?.observable.add(observer: self)

        balanceLabel.text = R.string.localizable.commonBalance(preferredLanguages: languages).uppercased()
        assetButton.isFlat = false
        assetButton.color = R.color.neumorphism.base()!
        assetButton.rightImageView.image = R.image.pswapDisclosureGrey()
        assetButton.customLabel.isHidden = true

        amountField.text = viewModel.amountInputViewModel?.displayAmount ?? "0"
    }

    func setEmpty() {
        balanceLabel.text = ""
        balanceValueLabel.attributedText = NSAttributedString(string: "")
        assetButton.isFlat = true
        assetButton.color = R.color.brandPolkaswapPink()!
        assetButton.leftImageView.image = nil
        assetButton.rightImageView.image = R.image.pswapDisclosureWhite()
        assetButton.setTitle("", for: .normal)
        assetButton.customLabel.isHidden = false
        assetButton.customLabel.font = assetButton.font?.withSize(15.0)
        assetButton.shortCustomLabel.text = ""
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(assetPressed))
        addGestureRecognizer(tapGestureRecognizer)
        amountField.isUserInteractionEnabled = false
    }
    
    func setup() {
        fromToLabel.font = UIFont.styled(for: .paragraph1)
        fromToLabel.textColor = R.color.neumorphism.text()
        balanceLabel.font = UIFont.styled(for: .paragraph2)
        balanceLabel.textColor = R.color.neumorphism.text()
        balanceValueLabel.font = UIFont.styled(for: .uppercase1)
        balanceValueLabel.textColor = R.color.neumorphism.textDark()
        amountField.textAlignment = .left
        amountField.font = UIFont.styled(for: .display2).withSize(20.0)
        amountField.isChangeColorOnEdit = false
        amountField.delegate = self
        amountField.accessoryDelegate = self
        assetButton.setTitleColor(R.color.neumorphism.textDark(), for: .normal)
        assetButton.shortCustomLabel.textColor = R.color.neumorphism.textDark()
        assetButton.addTarget(self, action: #selector(assetPressed), for: .touchUpInside)
        assetButton.shortCustomLabel.font = assetButton.font
    }

    @objc func assetPressed() {
        delegate?.didPressAsset(self)
    }
}

extension PolkaswapAssetView: SoraTextDelegate {
    func soraTextField(_ textField: NeuTextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
        _ = viewModel?.amountInputViewModel?.didReceiveReplacement(string, for: range, isNotificationEnabled: true)
        return false
    }
}

extension PolkaswapAssetView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        amountField.text = viewModel?.amountInputViewModel?.displayAmount ?? "0"
        delegate?.didChangeAmount(viewModel?.amountInputViewModel?.decimalAmount, view: self)
    }
}

extension PolkaswapAssetView: PolkaswapAmountFieldAccessoryDelegate {
    func donePressed(amountField: PolkaswapAmountField) {
        amountField.resignFirstResponder()
    }

    func predefinedPressed(amountField: PolkaswapAmountField, value: Int) {
        delegate?.didChangePredefinedPercentage(Decimal(value), view: self)
    }
}

extension PolkaswapAssetView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        if isFrom {
            fromToLabel.text = R.string.localizable.commonFrom(preferredLanguages: languages).uppercased()
        } else {
            fromToLabel.text = R.string.localizable.commonTo(preferredLanguages: languages).uppercased()
        }
        assetButton.customLabel.text = R.string.localizable.chooseToken(preferredLanguages: languages).uppercased()

        balanceLabel.text = R.string.localizable.commonBalance(preferredLanguages: languages).uppercased()
        amountField.localizationManager = localizationManager
    }
}
