import SoraUI
import UIKit
import SoraFoundation
import Anchorage

final class LiquidityViewController: UIViewController & KeyboardAdoptable {
    private enum Style {
        static let dimViewAnimationDuration: CGFloat = 0.6
    }

    var presenter: LiquidityPresenterProtocol!

    let amountFormatterFactory = AmountFormatterFactory()

    @IBOutlet weak var scrollView: UIScrollView?
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

    var detailsState: DetailsState = .collapsed
    @IBOutlet var detailsView: LiquidityDetailsView?
    @IBOutlet var detailsLabel: UILabel!
    @IBOutlet var detailsButton: NeumorphismButton!

    @IBOutlet weak var stack: UIStackView!
    @IBOutlet var firstProviderView: UIView!
    @IBOutlet weak var firstProviderTitleLabel: UILabel!
    @IBOutlet weak var firstProviderDescriptionLabel: UILabel!

    var keyboardHandler: KeyboardHandler?

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        presenter.setup()
        applyLocalization()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func setup() {
        setupDimView()
        setupNavigationBar()
        setupHeaderContainer()
        setupAssetsViews()
        setupNextButton()
        setupSlippageContainer()
        setupDetailsContainer()
        setupFirstProviderView()
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
        sliderContainer.isHidden = presenter.isAddingLiquidity
        if presenter.isAddingLiquidity { return }
        amountLabel.text = R.string.localizable.transactionAmountTitle(preferredLanguages: languages).uppercased()
        amountLabel.font = UIFont.styled(for: .paragraph1)
        amountLabel.textColor = R.color.neumorphism.text()
        amountValueLabel.font = UIFont.styled(for: .display1)
    }

    private func setupAssetsViews() {
        firstAssetView.isAssetChangeable = presenter.isAddingLiquidity
        firstAssetView.isBalanceHidden = true
        firstAssetView.isFirstAsset = true
        secondAssetView.isAssetChangeable = presenter.isAddingLiquidity
        secondAssetView.isBalanceHidden = true
        secondAssetView.isFirstAsset = false
        firstAssetView.delegate = self
        secondAssetView.delegate = self
        firstAssetView.localizationManager = localizationManager
        secondAssetView.localizationManager = localizationManager
        firstAssetView.fromToLabel.text = R.string.localizable.commonDeposit(preferredLanguages: languages).uppercased()
        secondAssetView.fromToLabel.text = R.string.localizable.commonDeposit(preferredLanguages: languages).uppercased()
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
    }

    fileprivate func setupFirstProviderView() {
        firstProviderTitleLabel?.font = UIFont.styled(for: .paragraph1, isBold: true)
        firstProviderDescriptionLabel?.font = UIFont.styled(for: .paragraph1)
        firstProviderTitleLabel?.text = R.string.localizable.liquidityPairCreationTitle(preferredLanguages: languages).uppercased()
        firstProviderDescriptionLabel?.text = R.string.localizable.liquidityPairCreationDescription(preferredLanguages: languages)
    }

    private func setSlippage(_ newSlippage: String) {
        slippageValueLabel.text = newSlippage
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

    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let offset = UIScreen.main.bounds.size.height - frame.origin.y
        scrollView?.contentInset.bottom = offset
    }

    @objc private func proceedButtonPressed() {
        presenter.didPressNextButton()
    }

    @objc private func didPressSlippage() {
        presenter.showSlippageController()
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
    func setSliderAmount(_ amount: Int) {
        slider.value = Float(amount)
    }

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
        firstAssetView.isBalanceHidden = balance == nil
        firstAssetView.setBalance(balance)
    }
    func setSecondAssetBalance(_ balance: String?) {
        secondAssetView.isBalanceHidden = balance == nil
        secondAssetView.setBalance(balance)
    }

    func setFirstAmount(_ amount: Decimal) {
        firstAssetView?.setAmount(amount)
    }

    func setSecondAmount(_ amount: Decimal) {
        secondAssetView?.setAmount(amount)
    }

    func setSlippageAmount(_ amount: Decimal) {
        let percentFormatter = amountFormatterFactory.createPercentageFormatter().value(for: locale)
        let newSlippage = percentFormatter.stringFromDecimal(amount) ?? "?"
        setSlippage(newSlippage)
    }

    func setDetailsVisible(_ isEnabled: Bool) {
        [detailsLabel, detailsButton].forEach({$0.isHidden = !isEnabled})
    }

    func setDetails(_ detailsState: DetailsState) {
        self.detailsState = detailsState
        switch detailsState {
        case .expanded:
            detailsView?.isHidden = false
            detailsButton.setImage(R.image.arrowUp(), for: .normal)
            detailsLabel.textColor = R.color.brandPolkaswapPink()!
        case .collapsed:
            detailsView?.isHidden = true
            detailsButton.setImage(R.image.arrowDown(), for: .normal)
            detailsLabel.textColor = R.color.neumorphism.buttonTextDisabled()!

        default: break
        }
    }

    func setNextButton(isEnabled: Bool, isLoading: Bool, title: String) {
        firstAssetView.isUserInteractionEnabled = firstAssetView.isFirstResponder || !isLoading
        secondAssetView.isUserInteractionEnabled = secondAssetView.isFirstResponder || !isLoading
        proceedButton.isEnabled = isEnabled
        slider.isEnabled = !isLoading
        if isEnabled {
            proceedButton.color = R.color.brandPolkaswapPink()!
            proceedButton.setTitleColor(.white, for: .normal)
        }
        proceedButton.setTitle(title, for: .normal)
        isLoading ? proceedButton.startProgress() : proceedButton.stopProgress()
    }

    func didReceiveDetails(viewModel: PoolDetailsViewModel) {
        removeDetailsViewFromStack()
        createDetailsView(viewModel: viewModel)
        addDetailsViewToStack()
        detailsView?.isHidden = detailsState == .collapsed
    }

    func createDetailsView(viewModel: PoolDetailsViewModel) {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let formatter = amountFormatterFactory.createPolkaswapAmountFormatter().value(for: locale)
        let percentageFormatter = amountFormatterFactory.createPercentageFormatter(maxPrecision: 8).value(for: locale)
        detailsView = LiquidityDetailsView(viewModel: viewModel, languages: languages, formatter: formatter, percentageFormatter: percentageFormatter)
        detailsView?.delegate = self
    }

    func removeDetailsViewFromStack() {
        if let detailsView = detailsView, stack.subviews.contains(detailsView) {
            stack.removeArrangedSubview(detailsView)
            detailsView.removeFromSuperview()
            self.detailsView = nil
        }
    }

    func addDetailsViewToStack() {
        if let detailsView = detailsView, !stack.subviews.contains(detailsView) {
            stack.insertArrangedSubview(detailsView, at: 7)
            detailsView.leadingAnchor == stack.leadingAnchor
            detailsView.trailingAnchor == stack.trailingAnchor
            detailsView.widthAnchor == stack.widthAnchor
        }
    }

    func setFirstProviderView(isHidden: Bool) {
        if isHidden {
            stack.removeArrangedSubview(firstProviderView)
            firstProviderView.removeFromSuperview()
        } else {
            stack.addArrangedSubview(firstProviderView)
        }
    }
}

extension LiquidityViewController: PolkaswapAssetViewDelegate {
    func didPressAsset(_ view: PolkaswapAssetView) {

        let isFrom = view == firstAssetView
        presenter.didPressAsset(isFrom: isFrom)
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
        if !presenter.isAddingLiquidity {
            navigationItem.title = R.string.localizable
                .removeLiquidityTitle(preferredLanguages: languages)
            amountLabel?.text = R.string.localizable.transactionAmountTitle(preferredLanguages: languages).uppercased()
        } else {
            navigationItem.title = R.string.localizable
                .addLiquidityTitle(preferredLanguages: languages)
        }
        firstAssetView?.applyLocalization()
        secondAssetView?.applyLocalization()
        firstAssetView?.fromToLabel.text = presenter.isAddingLiquidity ? R.string.localizable.commonDeposit(preferredLanguages: languages).uppercased() :
            R.string.localizable.commonOutput(preferredLanguages: languages).uppercased()
        secondAssetView?.fromToLabel.text = firstAssetView?.fromToLabel.text
        setupFirstProviderView()
    }
}

extension LiquidityViewController: LiquidityDetailsViewDelegate {
    func didTapSbApy() {
        presenter.didPressSbApyButton()
    }

    func didTapFee() {
        presenter.didPressNetworkFee()
    }
}
