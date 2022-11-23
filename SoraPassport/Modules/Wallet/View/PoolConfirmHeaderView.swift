import CommonWallet
import SoraFoundation
import SoraUI
import UIKit

final class PoolConfirmHeaderView: WalletFormItemView {
    var borderType: BorderType = [.top, .bottom]

    var firstAssetImage: UIImage?
    var secondAssetImage: UIImage?
    var viewModel: AddLiquidityViewModel!

    @IBOutlet var shareOfPoolTitleLabel: UILabel!
    @IBOutlet var shareOfPoolValueLabel: UILabel!

    @IBOutlet var firstAssetImageView: UIImageView!
    @IBOutlet var secondAssetImageView: UIImageView!
    @IBOutlet var pairTitle: UILabel!

    @IBOutlet var slippageDescriptionLabel: UILabel!

    @IBOutlet var firstAssetDepositTitleLabel: UILabel!
    @IBOutlet var firstAssetDepositValueLabel: UILabel!
    @IBOutlet var secondAssetDepositTitleLabel: UILabel!
    @IBOutlet var secondAssetDepositValueLabel: UILabel!
    @IBOutlet var firstAssetPriceTitleLabel: UILabel!
    @IBOutlet var firstAssetPriceValueLabel: UILabel!
    @IBOutlet var secondAssetPriceTitleLabel: UILabel!
    @IBOutlet var secondAssetPriceValueLabel: UILabel!
    @IBOutlet var sbApyTitleLabel: UILabel!
    @IBOutlet var sbApyValueLabel: UILabel!

    let amountFormatterFactory = AmountFormatterFactory()
    var formatter: NumberFormatter!

    func bind(viewModel: AddLiquidityViewModel) {
        self.viewModel = viewModel
        setup()
    }

    var preferredLanguages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    private func setup() {
        formatter = amountFormatterFactory.createPolkaswapAmountFormatter().value(for: localizationManager?.selectedLocale ?? Locale.current)
        backgroundColor = R.color.neumorphism.base()
        setupHeaderContainer()
        setupDetailsContainer()
    }

    private func setupHeaderContainer() {
        firstAssetImageView.image = firstAssetImage ?? R.image.assetUnkown()
        secondAssetImageView.image = secondAssetImage ?? R.image.assetUnkown()
        shareOfPoolTitleLabel.font = UIFont.styled(for: .paragraph1, isBold: false).withSize(18)
        shareOfPoolTitleLabel.text = R.string.localizable.addLiquidityPoolShareTitle(preferredLanguages: preferredLanguages)
        shareOfPoolValueLabel.font = UIFont.styled(for: .display1, isBold: true)
        if let shareOfPool = formatter.stringFromDecimal(viewModel.shareOfPoolValue) {
            shareOfPoolValueLabel.text = shareOfPool + "%"
        } else {
            shareOfPoolValueLabel.text = ""
        }
        pairTitle.font = UIFont.styled(for: .title3, isBold: true)
        pairTitle.text = R.string.localizable.addLiquidityPoolTitle(viewModel!.firstAsset.symbol, viewModel!.secondAsset.symbol)
        slippageDescriptionLabel.font = UIFont.styled(for: .paragraph1)
        slippageDescriptionLabel.text = R.string.localizable.polkaswapOutputEstimated(viewModel.slippage, preferredLanguages: preferredLanguages)
    }

    private func setupDetailsContainer() {
        setupFirstAssetDepositLabels()
        setupSecondAssetDepositLabels()
        setupFirstAssetPriceTitleLabel()
        setupSecondAssetPriceTitleLabel()
        setupSbApyLabels()
    }

    private func setupFirstAssetDepositLabels() {
        firstAssetDepositTitleLabel.font = UIFont.styled(for: .paragraph1)
        firstAssetDepositTitleLabel.text = "\(viewModel!.firstAsset.symbol) " + R.string.localizable.commonDeposit(preferredLanguages: preferredLanguages).uppercased()
        firstAssetDepositValueLabel.text = viewModel!.firstAssetValue
    }

    private func setupSecondAssetDepositLabels() {
        secondAssetDepositTitleLabel.font = UIFont.styled(for: .paragraph1)
        secondAssetDepositTitleLabel.text = "\(viewModel!.secondAsset.symbol) " + R.string.localizable.commonDeposit(preferredLanguages: preferredLanguages).uppercased()
        secondAssetDepositValueLabel.text = viewModel!.secondAssetValue
    }

    private func setupFirstAssetPriceTitleLabel() {
        firstAssetPriceTitleLabel.font = UIFont.styled(for: .paragraph1)
        firstAssetPriceTitleLabel.text = R.string.localizable.polkaswapPriceForOne(preferredLanguages: preferredLanguages) + " " + viewModel.firstAsset.symbol
        firstAssetPriceValueLabel.text = viewModel.inversedExchangeRateValue + " " + viewModel!.secondAsset.symbol
    }

    private func setupSecondAssetPriceTitleLabel() {
        secondAssetPriceTitleLabel.font = UIFont.styled(for: .paragraph1)
        secondAssetPriceTitleLabel.text = R.string.localizable.polkaswapPriceForOne(preferredLanguages: preferredLanguages) + " " + viewModel.secondAsset.symbol
        secondAssetPriceValueLabel.text = viewModel.directExchangeRateValue + " " + viewModel!.firstAsset.symbol
    }

    private func setupSbApyLabels() {
        sbApyTitleLabel.font = UIFont.styled(for: .paragraph1)
        sbApyTitleLabel.text = R.string.localizable.poolApyTitle().uppercased()
        if let sbApy = formatter.stringFromDecimal(viewModel.sbApyValue) {
            sbApyValueLabel.text = sbApy + "%"
        } else {
            sbApyValueLabel.text = ""
        }
    }
}

extension PoolConfirmHeaderView: Localizable { }
