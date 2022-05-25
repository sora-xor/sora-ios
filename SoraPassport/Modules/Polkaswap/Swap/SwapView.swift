import Foundation
import UIKit
import SoraFoundation
import CommonWallet
import Anchorage

class PolkaswapSwapView: UIViewController & SwapViewProtocol  & KeyboardAdoptable {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var fromSwapView: PolkaswapAssetView! {
        didSet {
            fromSwapView.delegate = self
            fromSwapView.isFrom = true
            fromSwapView.amountField.predefinedValues = [25, 50, 75, 100]
            fromSwapView.localizationManager = localizationManager // should be called after setting of predefinedValues
        }
    }
    @IBOutlet weak var toSwapView: PolkaswapAssetView! {
        didSet {
            toSwapView.delegate = self
            toSwapView.isFrom = false
            toSwapView.localizationManager = localizationManager
        }
    }
    @IBOutlet weak var inverseButton: NeumorphismButton!
    @IBOutlet weak var nextButton: NeumorphismButton!
    @IBOutlet weak var slippageLabel: UILabel!
    @IBOutlet weak var slippageValueLabel: UILabel!
    @IBOutlet weak var slippageButton: NeumorphismButton!
    @IBOutlet weak var detailsLabel: UILabel!
    @IBOutlet weak var detailsButton: NeumorphismButton!
    @IBOutlet weak var detailsView: UIView!
    @IBOutlet weak var detailsConstraint: NSLayoutConstraint?

    @IBOutlet weak var directExchangeRateTitleLabel: UILabel!
    @IBOutlet weak var inversedExchangeRateTitleLabel: UILabel!
    @IBOutlet weak var minReceivedTitleLabel: UILabel!
    @IBOutlet weak var lpFeeTitleLabel: UILabel!
    @IBOutlet weak var networkFeeTitleLabel: UILabel!

    @IBOutlet weak var directExchangeRateValueLabel: UILabel!
    @IBOutlet weak var inversedExchangeRateValueLabel: UILabel!
    @IBOutlet weak var minReceivedValueLabel: UILabel!
    @IBOutlet weak var lpFeeValueLabel: UILabel!
    @IBOutlet weak var networkFeeValueLabel: UILabel!

    @IBOutlet weak var minReceivedButton: UIButton!
    @IBOutlet weak var lpFeeButton: UIButton!
    @IBOutlet weak var networkFeeButton: UIButton!

    @IBOutlet weak var disclaimerView: UIView!
    @IBOutlet weak var disclaimerBackImageView: UIImageView!
    @IBOutlet weak var disclaimerInfoBackView: UIView!
    @IBOutlet weak var disclaimerInfoImageView: UIImageView!
    @IBOutlet weak var disclaimerLabel: UILabel!
    @IBOutlet weak var disclaimerButton: UIButton!
    @IBOutlet weak var disclaimerConstraint: NSLayoutConstraint!

    @IBOutlet var slippageHelperTextField: PolkaswapSlippageHelperTextField!
    @IBOutlet var dimView: UIView!
    var marketLabel: UILabel?
    
    //TODO: DI
    let amountFormatterFactory = AmountFormatterFactory()

    var detailsViewModel: PolkaswapDetailsViewModel?
    var presenter: SwapPresenterProtocol!

    var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }
    
    var keyboardHandler: KeyboardHandler?

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        presenter.setup(preferredLocalizations: languages)
        applyLocalization()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setDisclaimer(isHidden: presenter.isDisclaimerHidden)
        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    override func resignFirstResponder() -> Bool {
        fromSwapView.amountField.resignFirstResponder()
        toSwapView.amountField.resignFirstResponder()
        slippageLabel.resignFirstResponder()
        hideSlippageController()

        return super.resignFirstResponder()
    }

    fileprivate func setup() {
        dimView.backgroundColor = R.color.neumorphism.polkaswapDim()
        let tapGR = UITapGestureRecognizer()
        tapGR.addTarget(self, action: #selector(didTapDimView))
        dimView.addGestureRecognizer(tapGR)

        view.backgroundColor = R.color.neumorphism.base()
        topView.backgroundColor = R.color.neumorphism.base()
        detailsView.backgroundColor = R.color.neumorphism.base()

        inverseButton.setImage(R.image.polkaswapInverseIcon()!, for: .normal)
        inverseButton.addTarget(self, action: #selector(didPressInverse), for: .touchUpInside)

        slippageButton?.addTarget(self, action: #selector(didPressSlippage), for: .touchUpInside)

        nextButton.color = R.color.brandPolkaswapPink()!
        nextButton.setTitleColor(R.color.brandWhite()!, for: .normal)
        nextButton?.isFlat = true
        nextButton.addTarget(self, action: #selector(didPressNext), for: .touchUpInside)

        detailsButton.addTarget(self, action: #selector(didPressDetails), for: .touchUpInside)

        [directExchangeRateTitleLabel,
         inversedExchangeRateTitleLabel,
         minReceivedTitleLabel,
         lpFeeTitleLabel,
         networkFeeTitleLabel].forEach { label in
            label?.font = UIFont.styled(for: .paragraph1)
            label?.textColor = R.color.neumorphism.text()
        }

        [directExchangeRateValueLabel,
         inversedExchangeRateValueLabel,
         minReceivedValueLabel,
         lpFeeValueLabel,
         networkFeeValueLabel].forEach { label in
            label?.font = UIFont.styled(for: .uppercase1)
            label?.textColor = R.color.neumorphism.text()
            label?.text = "0"
        }

        minReceivedButton.addTarget(self, action: #selector(minMaxButtonPressed), for: .touchUpInside)
        lpFeeButton.addTarget(self, action: #selector(lpFeeButtonPressed), for: .touchUpInside)
        networkFeeButton.addTarget(self, action: #selector(networkFeeButtonPressed), for: .touchUpInside)

        [minReceivedButton, lpFeeButton, networkFeeButton].forEach { button in
            button?.setTitle("", for: .normal)
        }

        setupDisclaimerView()
    }

    func setupDisclaimerView() {
        disclaimerInfoBackView.backgroundColor = R.color.neumorphism.polkaswapLightPink()
        disclaimerInfoImageView.image = R.image.polkaswapDisclaimerInfo()
        disclaimerLabel.font = UIFont.styled(for: .paragraph1)
        disclaimerLabel.textColor = R.color.neumorphism.text()
        disclaimerButton.setTitle("", for: .normal)
        disclaimerButton.addTarget(self, action: #selector(didPressDisclaimer), for: .touchUpInside)
    }

    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let offset = UIScreen.main.bounds.size.height - frame.origin.y
        scrollView?.contentInset.bottom = offset
    }

    @objc func didPressInverse() {
        presenter.didPressInverse()
    }

    @objc func didPressSlippage() {
        showSlippageController()
    }

    func didPressMarket() {
        hideSlippageController()
        presenter.didPressMarket()
    }

    func setMarket(type: LiquiditySourceType) {
        marketLabel?.text = type.titleForLocale(locale)
    }

    @objc func didTapDimView() {
        slippageHelperTextField.dismissSlippageView()
        dismiss(animated: true)
        changeDimView(isHidden: true, animated: true)
    }

    func showSlippageController() {
        changeDimView(isHidden: false, animated: false)

        slippageHelperTextField.becomeFirstResponder()
        slippageHelperTextField.slippageView?.parentField = slippageHelperTextField
        slippageHelperTextField.slippageView?.delegate = self
        slippageHelperTextField.slippageView?.amountField.becomeFirstResponder()

        slippageHelperTextField.slippageView?.slippage = presenter.slippage
    }

    func hideSlippageController() {
        changeDimView(isHidden: true, animated: false)
        slippageHelperTextField.dismissSlippageView()
    }

    fileprivate func changeDimView(isHidden: Bool, animated: Bool) {
        let newAlpha = isHidden ? 0.0 : 1.0
        if animated {
            UIView.animate(withDuration: 0.6,
                           animations: {
                               self.dimView.alpha = newAlpha
                           },
                           completion: { [weak self] _ in
                               self?.dimView.isHidden = isHidden
                           })
        } else {
            dimView.alpha = newAlpha
            dimView.isHidden = isHidden
        }
    }

    func setSlippage(_ newSlippage: String) {
        slippageValueLabel.text = newSlippage
    }

    func setSwapButton(isEnabled: Bool, isLoading: Bool, title: String) {
        view.isUserInteractionEnabled = !isLoading
        nextButton.isEnabled = isEnabled
        nextButton.setTitle(title, for: .normal)
        isLoading ? nextButton.startProgress() : nextButton.stopProgress()
    }

    func selectAsset(_ selectedAsset: WalletAsset?, amount: Decimal? = nil, isFrom: Bool) {
        guard let assetView = isFrom ? fromSwapView : toSwapView else { return }

        //TODO: move to presenter

        guard selectedAsset != nil else {
            let viewModel = PolkaswapAssetViewModel(isEmpty: true, assetImageViewModel: nil, amountInputViewModel: nil, assetName: nil)
            assetView.didReceive(viewModel: viewModel)
            return
        }

        let assetManager: AssetManagerProtocol = AssetManager.shared
        let assetName = selectedAsset?.name.value(for: locale)
        guard let identifier = selectedAsset?.identifier else { return }
        let assetInfo = assetManager.assetInfo(for: identifier)

        var assetImageViewModel: WalletImageViewModelProtocol
        if let iconString = assetInfo?.icon {
            assetImageViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            assetImageViewModel = WalletStaticImageViewModel(staticImage: R.image.assetUnkown()!)
        }
        let formatter = amountFormatterFactory.createInputFormatter(for: selectedAsset).value(for: locale)
        var amountInputViewModel = PolkaswapAmountInputViewModel(symbol: "", amount: amount, limit: Decimal(Int.max),  formatter: formatter, precision: 18)
//            amountInputViewModel?.observable.add(observer: self)
        
        let assetViewModel = PolkaswapAssetViewModel(isEmpty: false,
                                                         assetImageViewModel: assetImageViewModel,
                                                         amountInputViewModel: amountInputViewModel,
                                                         assetName: assetName)
        assetView.didReceive(viewModel: assetViewModel)
    }

    func setBalance(_ balance: Decimal, asset: WalletAsset, isFrom: Bool) {
        let assetView = isFrom ? fromSwapView : toSwapView
        let formatter = amountFormatterFactory.createTokenFormatter(for: asset, maxPrecision: 8).value(for: locale)
        let formattedString = formatter.stringFromDecimal(balance)
        assetView?.setBalance(formattedString)
    }

    func setFromAsset(_ asset: WalletAsset?, amount: Decimal? = nil) {
        selectAsset(asset, amount: amount, isFrom: true)
    }

    func setToAsset(_ asset: WalletAsset?, amount: Decimal? = nil) {
        selectAsset(asset, amount: amount, isFrom: false)
    }

    func setFromAmount(_ amount: Decimal) {
        let formatter = amountFormatterFactory.createPolkaswapAmountFormatter().value(for: locale)
        fromSwapView?.setAmount(amount, formatter: formatter)
    }

    func setToAmount(_ amount: Decimal) {
        let formatter = amountFormatterFactory.createPolkaswapAmountFormatter().value(for: locale)
        toSwapView?.setAmount(amount, formatter: formatter)
    }

    @objc func didPressDetails() {
        presenter.didPressDetails()
    }

    @objc func didPressNext() {
        presenter.didPressNext()
    }

    func setDetailsExpanded(_ isExpanded: Bool) {
        detailsConstraint?.isActive = false
        if isExpanded {
            detailsConstraint = topView.bottomAnchor == detailsView.topAnchor
            detailsButton.setImage(R.image.arrowUp(), for: .normal)
        } else {
            detailsConstraint = topView.bottomAnchor == detailsView.bottomAnchor
            detailsButton.setImage(R.image.arrowDown(), for: .normal)
        }
    }

    func didReceiveDetails(viewModel detailsViewModel: PolkaswapDetailsViewModel) {
        self.detailsViewModel = detailsViewModel
        setupDetailLabels()
    }

    func setupDetailLabels() {
        directExchangeRateTitleLabel?.text = detailsViewModel?.directExchangeRateTitle
        inversedExchangeRateTitleLabel?.text = detailsViewModel?.inversedExchangeRateTitle
        minReceivedTitleLabel?.text = detailsViewModel?.minReceivedTitle
        lpFeeTitleLabel?.text = detailsViewModel?.lpFeeTitle
        networkFeeTitleLabel?.text = detailsViewModel?.networkFeeTitle
        let formatter = amountFormatterFactory.createPolkaswapAmountFormatter().value(for: locale)
        if let directRate = detailsViewModel?.directExchangeRateValue {
            directExchangeRateValueLabel?.text = formatter.stringFromDecimal(directRate)
        } else {
            directExchangeRateValueLabel?.text = ""
        }
        if let inversedRate = detailsViewModel?.inversedExchangeRateValue {
            inversedExchangeRateValueLabel?.text = formatter.stringFromDecimal(inversedRate)
        } else {
            inversedExchangeRateValueLabel?.text = ""
        }
        if let minReceived = detailsViewModel?.minReceivedValue, let minString = formatter.stringFromDecimal(minReceived) {
            minReceivedValueLabel?.text = minString + " " + ( detailsViewModel?.minMaxToken ?? "" )
        } else {
            minReceivedValueLabel?.text = ""
        }
        if let lpFee = detailsViewModel?.lpFeeValue, let feeString = formatter.stringFromDecimal(lpFee) {
            lpFeeValueLabel?.text = feeString + " XOR"
        } else {
            lpFeeValueLabel?.text = ""
        }
        if let networkFee = detailsViewModel?.networkFeeValue, let feeString = formatter.stringFromDecimal(networkFee) {
            networkFeeValueLabel?.text = feeString + " XOR"
        } else {
            networkFeeValueLabel?.text = ""
        }
    }

    @objc func minMaxButtonPressed() {
        let alert = UIAlertController(title: detailsViewModel?.minMaxAlertTitle,
                                      message: detailsViewModel?.minMaxAlertText,
                                      preferredStyle: .alert)
        let closeTitle = R.string.localizable.commonOk(preferredLanguages: languages)
        let closeAction = UIAlertAction(title: closeTitle, style: .cancel, handler: nil)
        alert.addAction(closeAction)
        present(alert, animated: true, completion: nil)
    }

    @objc func lpFeeButtonPressed() {
        let alert = UIAlertController(title: R.string.localizable.polkaswapLiqudityFee(preferredLanguages: languages),
                                      message: R.string.localizable.polkaswapLiqudityFeeInfo(preferredLanguages: languages),
                                      preferredStyle: .alert)
        let closeTitle = R.string.localizable.commonOk(preferredLanguages: languages)
        let closeAction = UIAlertAction(title: closeTitle, style: .cancel, handler: nil)
        alert.addAction(closeAction)
        present(alert, animated: true, completion: nil)
    }

    @objc func networkFeeButtonPressed() {
        let alert = UIAlertController(title: R.string.localizable.polkaswapNetworkFee(preferredLanguages: languages),
                                      message: R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: languages),
                                      preferredStyle: .alert)
        let closeTitle = R.string.localizable.commonOk(preferredLanguages: languages)
        let closeAction = UIAlertAction(title: closeTitle, style: .cancel, handler: nil)
        alert.addAction(closeAction)
        present(alert, animated: true, completion: nil)
    }

    @objc func didPressDisclaimer() {
        presenter.didPressDisclaimer()
    }

    func setDisclaimer(isHidden: Bool) {
        disclaimerConstraint.isActive = false
        if isHidden {
            disclaimerConstraint = (disclaimerView.bottomAnchor == detailsView.bottomAnchor)
        } else {
            disclaimerConstraint = (disclaimerView.topAnchor == detailsView.bottomAnchor)
        }
    }
}

extension PolkaswapSwapView: PolkaswapSlippageSelectorViewDelegate {
    func didSelect(slippage: Double) {
        changeDimView(isHidden: true, animated: true)
        presenter.slippage = slippage
        let percentFormatter = amountFormatterFactory.createPercentageFormatter().value(for: locale)
        let newSlippage = percentFormatter.stringFromDecimal(Decimal(presenter.slippage)) ?? "?"
        setSlippage(newSlippage)
    }
}

extension PolkaswapSwapView: PolkaswapAssetViewDelegate {
    func didPressAsset(_ view: PolkaswapAssetView) {
        let isFrom = view == fromSwapView
        presenter.didPressAsset(isFrom: isFrom)
    }

    func didChangeAmount(_ amount: Decimal?, view: PolkaswapAssetView) {
        presenter.didSelectAmount(amount, isFrom: view.isFrom)
    }

    func didChangePredefinedPercentage(_ amount: Decimal, view: PolkaswapAssetView) {
        presenter.didSelectPredefinedPercentage(amount, isFrom: view.isFrom)
    }
}

extension PolkaswapSwapView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        fromSwapView?.localizationManager = localizationManager
        toSwapView?.localizationManager = localizationManager

        nextButton?.setTitle(presenter.currentButtonTitle, for: .normal)

        slippageLabel?.font = UIFont.styled(for: .paragraph1)
        slippageValueLabel?.font = UIFont.styled(for: .paragraph1)
        detailsLabel?.font = UIFont.styled(for: .button).withSize(15.0)
        detailsLabel?.textColor = R.color.neumorphism.buttonTextDisabled()!

        slippageHelperTextField?.slippageView?.localizationManager = localizationManager

        slippageLabel?.text = R.string.localizable.polkaswapSlippageTolerance(preferredLanguages: languages).uppercased()
        detailsLabel?.text = R.string.localizable.polkaswapDetails(preferredLanguages: languages).uppercased()
        presenter?.needsUpdateDetails()

        disclaimerLabel?.text = R.string.localizable.polkaswapInfoTitleMain(preferredLanguages: languages).uppercased()
    }
}
