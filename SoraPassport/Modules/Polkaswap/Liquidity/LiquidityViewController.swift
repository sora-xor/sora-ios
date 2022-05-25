import CommonWallet
import SoraUI
import UIKit
import SoraFoundation

final class LiquidityViewController: UIViewController {
    private enum Style {
        static let expandedDetailsBottomConstraint: CGFloat = 340
        static let collapsedDetailsBottomConstraint: CGFloat = 0
        static let dimViewAnimationDuration: CGFloat = 0.6
    }

    var presenter: LiquidityPresenterProtocol!

    var amountFormatterFactory: AmountFormatterFactoryProtocol?

    @IBOutlet var dimView: UIView!
    @IBOutlet var amountLabel: UILabel!
    @IBOutlet var amountValueLabel: UILabel!

    @IBOutlet var sliderContainer: UIView!
    @IBOutlet var slider: LiquiditySlider!
    @IBOutlet var firstAssetView: PolkaswapAssetView!
    @IBOutlet var secondAssetView: PolkaswapAssetView!
    @IBOutlet var proceedButton: NeumorphismButton!

    @IBOutlet var slippageLabel: UILabel!
    @IBOutlet var slippageValueLabel: UILabel!
    @IBOutlet var slippageButton: NeumorphismButton!
    @IBOutlet var slippageHelperTextField: PolkaswapSlippageHelperTextField!

    @IBOutlet var detailsView: UIView!
    @IBOutlet var detailsLabel: UILabel!
    @IBOutlet var detailsButton: NeumorphismButton!

    @IBOutlet var yourPositionLabel: UILabel!
    @IBOutlet var firstAssetTitleLabel: UILabel!
    @IBOutlet var firstAssetValueLabel: UILabel!
    @IBOutlet var secondAssetTitleLabel: UILabel!
    @IBOutlet var secondAssetValueLabel: UILabel!
    @IBOutlet var shareOfPoolTitleLabel: UILabel!
    @IBOutlet var shareOfPoolValueLabel: UILabel!

    @IBOutlet var pricesAndFeesLabel: UILabel!
    @IBOutlet var directExchangeRateTitleLabel: UILabel!
    @IBOutlet var directExchangeRateValueLabel: UILabel!
    @IBOutlet var inversedExchangeRateTitleLabel: UILabel!
    @IBOutlet var inversedExchangeRateValueLabel: UILabel!
    @IBOutlet var sbApyTitleLabel: UILabel!
    @IBOutlet var sbApyValueLabel: UILabel!
    @IBOutlet var networkFeeTitleLabel: UILabel!
    @IBOutlet var networkFeeValueLabel: UILabel!

    @IBOutlet var bottomConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        presenter.setup()
    }

    private func setup() {
        setupDimView()
        setupNavigationBar()
        setupHeaderContainer()
        setupAssetsViews()
        setupNextButton()
        setupSlippageContainer()
        setupDetailsContainer()
    }

    private func setupDimView() {
        dimView.backgroundColor = R.color.neumorphism.polkaswapDim()
    }

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: R.image.linkInfo(),
            style: .plain,
            target: self,
            action: #selector(actionOpenInfo)
        )
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.font: UIFont.styled(for: .paragraph3, isBold: true),
            NSAttributedString.Key.foregroundColor: R.color.neumorphism.text()
        ]
    }

    private func setupHeaderContainer() {
        if presenter.mode == .liquidityAdd {
            sliderContainer.isHidden = true
            return
        }
        amountLabel.text = R.string.localizable.transactionAmountTitle(preferredLanguages: languages).uppercased()
        amountLabel.font = UIFont.styled(for: .paragraph1)
        amountLabel.textColor = R.color.neumorphism.text()
        amountValueLabel.font = UIFont.styled(for: .display1)
    }

    private func setupAssetsViews() {
        firstAssetView.isAssetChangeable = false
        firstAssetView.isBalanceHidden = true
        firstAssetView.isFirstAsset = true
        firstAssetView.fromToLabel.text = R.string.localizable.commonOutput(preferredLanguages: languages).uppercased()
        secondAssetView.isAssetChangeable = false
        secondAssetView.isBalanceHidden = true
        secondAssetView.isFirstAsset = false
        secondAssetView.fromToLabel.text = R.string.localizable.commonOutput(preferredLanguages: languages).uppercased()
        firstAssetView.delegate = self
        secondAssetView.delegate = self
    }

    private func setupNextButton() {
        proceedButton.color = R.color.neumorphism.buttonLightGrey()!
        proceedButton.setTitleColor(R.color.neumorphism.buttonTextDisabled(), for: .normal)
        proceedButton.isFlat = true
        proceedButton.addTarget(self, action: #selector(proceedButtonPressed), for: .touchUpInside)
    }

    private func setupSlippageContainer() {
        slippageLabel.text = R.string.localizable.polkaswapSlippageTolerance(preferredLanguages: languages).uppercased()
        slippageLabel.font = UIFont.styled(for: .paragraph1)
        slippageLabel.textColor = R.color.neumorphism.text()
        slippageValueLabel.text = "\(presenter.slippage)%"
        slippageValueLabel.font = UIFont.styled(for: .paragraph1, isBold: true)
        slippageButton.addTarget(self, action: #selector(didPressSlippage), for: .touchUpInside)
    }

    private func setupDetailsContainer() {
        detailsLabel.textColor = R.color.neumorphism.buttonTextDisabled()!
        detailsLabel.text = R.string.localizable.polkaswapDetails(preferredLanguages: languages).uppercased()
        detailsButton.addTarget(self, action: #selector(detailsButtonPressed), for: .touchUpInside)

        let boldParagraphLabels: [UILabel] = [
            detailsLabel, yourPositionLabel, pricesAndFeesLabel
        ]
        boldParagraphLabels.forEach { $0.font = UIFont.styled(for: .paragraph1, isBold: true) }
        let paragraphLabels: [UILabel] = [
            firstAssetTitleLabel, firstAssetValueLabel,
            secondAssetTitleLabel, secondAssetValueLabel,
            shareOfPoolTitleLabel, shareOfPoolValueLabel,
            directExchangeRateTitleLabel, directExchangeRateValueLabel,
            inversedExchangeRateTitleLabel, inversedExchangeRateValueLabel,
            sbApyTitleLabel, sbApyValueLabel,
            networkFeeTitleLabel, networkFeeValueLabel
        ]
        paragraphLabels.forEach { $0.font = UIFont.styled(for: .paragraph1) }
        yourPositionLabel.text = R.string.localizable.polkaswapYourPosition(preferredLanguages: languages).uppercased()
        shareOfPoolTitleLabel.text = R.string.localizable.poolShareTitle(preferredLanguages: languages).uppercased()
        pricesAndFeesLabel.text = R.string.localizable.polkaswapInfoPricesAndFees(preferredLanguages: languages)
        sbApyTitleLabel.text = R.string.localizable.polkaswapSbapy(preferredLanguages: languages)
        networkFeeTitleLabel.text = R.string.localizable.polkaswapNetworkFee(preferredLanguages: languages).uppercased()
    }

    private func changeDimView(isHidden: Bool, animated: Bool) {
        let newAlpha = isHidden ? 0.0 : 1.0
        if animated {
            UIView.animate(
                withDuration: Style.dimViewAnimationDuration,
                animations: { self.dimView.alpha = newAlpha },
                completion: { [weak self] _ in self?.dimView.isHidden = isHidden }
            )
        } else {
            dimView.alpha = newAlpha
            dimView.isHidden = isHidden
        }
    }

    @objc private func proceedButtonPressed() {
        presenter.didPressNextButton()
    }

    @objc private func didPressSlippage() {
        changeDimView(isHidden: false, animated: false)
        slippageHelperTextField.becomeFirstResponder()
        slippageHelperTextField.slippageView?.parentField = slippageHelperTextField
        slippageHelperTextField.slippageView?.delegate = self
        slippageHelperTextField.slippageView?.amountField.becomeFirstResponder()
    }

    @objc private func actionOpenInfo() {
        presenter.activateInfo()
    }

    @objc private func detailsButtonPressed() {
        presenter.didPressDetails()
    }

    @IBAction func sliderMove(_ sender: Any) {
        presenter.didSliderMove(slider.value)
    }

    @IBAction func sbApyButtonPressed(_ sender: Any) {
        presenter.didPressSbApyButton()
    }

    @IBAction func networkFeeButtonPressed(_ sender: Any) {
        presenter.didPressNetworkFee()
    }
}

extension LiquidityViewController: LiquidityViewProtocol {
    func setPercentage(_ value: Int) {
        amountValueLabel.text = "\(value)%"
    }

    func setFirstAsset(viewModel: PolkaswapAssetViewModel) {
        firstAssetView.didReceive(viewModel: viewModel)
    }

    func setSecondAsset(viewModel: PolkaswapAssetViewModel) {
        secondAssetView.didReceive(viewModel: viewModel)
    }

    func setFirstAssetBalance(_ balance: String?) {
        firstAssetView.setBalance(balance)
    }
    func setSecondAssetBalance(_ balance: String?) {
        secondAssetView.setBalance(balance)
    }

    func setFirstAmount(_ amount: Decimal) {
        let formatter = amountFormatterFactory!.createPolkaswapAmountFormatter().value(for: locale)
        firstAssetView?.setAmount(amount, formatter: formatter)
    }

    func setSecondAmount(_ amount: Decimal) {
        let formatter = amountFormatterFactory!.createPolkaswapAmountFormatter().value(for: locale)
        secondAssetView?.setAmount(amount, formatter: formatter)
    }

    func setDetailsEnabled(_ isEnabled: Bool) {
        [detailsLabel, detailsButton].forEach({$0.isHidden = !isEnabled})
    }

    func setDetails(_ detailsState: DetailsState) {
        switch detailsState {
        case .expanded:
            detailsView.isHidden = false
            detailsButton.setImage(R.image.arrowUp(), for: .normal)
            detailsLabel.textColor = R.color.brandPolkaswapPink()!
            bottomConstraint.constant = Style.expandedDetailsBottomConstraint
        case .collapsed:
            detailsView.isHidden = true
            detailsButton.setImage(R.image.arrowDown(), for: .normal)
            detailsLabel.textColor = R.color.neumorphism.buttonTextDisabled()!
            bottomConstraint.constant = Style.collapsedDetailsBottomConstraint
        default: break
        }
    }

    func setNextButton(isEnabled: Bool, title: String) {
        proceedButton.isEnabled = isEnabled
        if isEnabled {
            proceedButton.color = R.color.brandPolkaswapPink()!
            proceedButton.setTitleColor(.white, for: .normal)
        }
        proceedButton.setTitle(title, for: .normal)
    }

    func didReceiveDetails(viewModel: PoolDetailsViewModel) {
        let formatter = amountFormatterFactory!.createPolkaswapAmountFormatter().value(for: localizationManager?.selectedLocale ?? Locale.current)
        firstAssetTitleLabel.text = viewModel.firstAsset.symbol
        secondAssetTitleLabel.text = viewModel.secondAsset.symbol

        directExchangeRateTitleLabel.text = viewModel.directExchangeRateTitle
        directExchangeRateValueLabel.text = formatter.stringFromDecimal(viewModel.directExchangeRateValue)
        inversedExchangeRateTitleLabel.text = viewModel.inversedExchangeRateTitle
        inversedExchangeRateValueLabel.text = formatter.stringFromDecimal(viewModel.inversedExchangeRateValue)
        if let sbApy = formatter.stringFromDecimal(viewModel.sbApyValue) {
            sbApyValueLabel.text = "\(sbApy)%"
        } else {
            sbApyValueLabel.text = ""
        }
        if let networkFee = formatter.stringFromDecimal(viewModel.networkFeeValue) {
            networkFeeValueLabel.text = "\(networkFee) XOR"
        } else {
            networkFeeValueLabel.text = ""
        }
    }
}

extension LiquidityViewController: PolkaswapAssetViewDelegate {
    func didPressAsset(_ view: PolkaswapAssetView) {
        //asset not changeable, but protocol requires
    }

    func didChangeAmount(_ amount: Decimal?, view: PolkaswapAssetView) {
        presenter.didSelectAmount(amount, isFirstAsset: view.isFirstAsset)
    }

    func didChangePredefinedPercentage(_ percent: Decimal, view: PolkaswapAssetView) {
        presenter.didSelectPredefinedPercentage(percent, isFirstAsset: view.isFirstAsset)
    }
}

extension LiquidityViewController: PolkaswapSlippageSelectorViewDelegate {
    func didSelect(slippage: Double) {
        changeDimView(isHidden: true, animated: true)
        presenter.slippage = slippage
        slippageValueLabel.text = "\(presenter.slippage)%"
    }
}

extension LiquidityViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    private var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    func applyLocalization() {
        if presenter.mode == .liquidityRemoval {
            navigationItem.title = R.string.localizable
                .removeLiquidityTitle(preferredLanguages: languages)
        } else {
            navigationItem.title = R.string.localizable
                .addLiquidityTitle(preferredLanguages: languages)
        }

    }
}
