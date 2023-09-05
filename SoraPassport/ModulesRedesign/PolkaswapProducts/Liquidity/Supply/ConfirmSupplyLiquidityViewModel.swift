import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation

protocol ConfirmViewModelProtocol {
    var title: String? { get }
    var imageName: String? { get }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func viewDidLoad()
}

final class ConfirmSupplyLiquidityViewModel {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    weak var view: ConfirmViewProtocol?
    var wireframe: ConfirmWireframeProtocol?
    let assetManager: AssetManagerProtocol
    let debouncer = Debouncer(interval: 0.8)
    
    var baseAssetId: String
    var targetAssetId: String
    var firstAssetAmount: Decimal
    var secondAssetAmount: Decimal
    var slippageTolerance: Float
    var details: [DetailViewModel]
    let transactionType: TransactionType
    let fee: Decimal
    let walletService: WalletServiceProtocol
    
    var title: String? {
        return R.string.localizable.addLiquidityConfirmationTitle(preferredLanguages: .currentLocale)
    }
    
    var imageName: String? {
        return nil
    }
    
    init(
        wireframe: ConfirmWireframeProtocol?,
        baseAssetId: String,
        targetAssetId: String,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: Float,
        details: [DetailViewModel],
        transactionType: TransactionType,
        fee: Decimal,
        walletService: WalletServiceProtocol
    ) {
        self.baseAssetId = baseAssetId
        self.targetAssetId = targetAssetId
        self.wireframe = wireframe
        self.assetManager = assetManager
        self.firstAssetAmount = firstAssetAmount
        self.secondAssetAmount = secondAssetAmount
        self.slippageTolerance = slippageTolerance
        self.details = details
        self.transactionType = transactionType
        self.fee = fee
        self.walletService = walletService
    }
}

extension ConfirmSupplyLiquidityViewModel: ConfirmViewModelProtocol {
    func viewDidLoad() {
        updateContent()
    }
}

extension ConfirmSupplyLiquidityViewModel {
    func updateContent() {
        var items: [SoramitsuTableViewItemProtocol] = []

        let firstAsset = assetManager.assetInfo(for: baseAssetId)
        let firstAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: 8)
        
        let secondAsset = assetManager.assetInfo(for: targetAssetId)
        let secondAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: 8)
        
        let firstAssetImageModel = ConfirmAssetViewModel(imageViewModel: WalletSvgImageViewModel(svgString: firstAsset?.icon ?? ""),
                                                         amountText: firstAssetFormatter.stringFromDecimal(self.firstAssetAmount) ?? "",
                                                         symbol: firstAsset?.symbol ?? "")
        
        let secondAssetImageModel = ConfirmAssetViewModel(imageViewModel: WalletSvgImageViewModel(svgString: secondAsset?.icon ?? ""),
                                                          amountText: secondAssetFormatter.stringFromDecimal(self.secondAssetAmount) ?? "",
                                                          symbol: secondAsset?.symbol ?? "")
        
        let confirmAssetsItem = ConfirmAssetsItem(firstAssetImageModel: firstAssetImageModel,
                                                  secondAssetImageModel: secondAssetImageModel,
                                                  operationImageName: "roundPlus")
        items.append(confirmAssetsItem)
        items.append(SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)))

        let text = R.string.localizable.addLiquidityPoolShareDescription("\(slippageTolerance)", preferredLanguages: .currentLocale)
        let textItem = SoramitsuTextItem(text: text, fontData: FontType.paragraphS, textColor: .fgPrimary, alignment: .center)
        let slippageTextItem = SoraTextItem(text: textItem.attributedString)
        items.append(slippageTextItem)
        items.append(SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)))
        
        let detailItem = ConfirmDetailsItem(detailViewModels: details)
        items.append(detailItem)
        items.append(SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)))
        
        let slipageItem = ConfirmOptionsItem(toleranceText: "\(slippageTolerance)%")
        items.append(slipageItem)
        items.append(SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)))
        
        if transactionType == .liquidityAddNewPool || transactionType == .liquidityAddToExistingPoolFirstTime {
            let warning = WarningItem()
            items.append(warning)
            items.append(SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)))
        }
        
        let buttonText = SoramitsuTextItem(text: R.string.localizable.commonConfirm(preferredLanguages: .currentLocale),
                                           fontData: FontType.buttonM,
                                           textColor: .bgSurface,
                                           alignment: .center)
        let buttonItem = SoramitsuButtonItem(title: buttonText) { [weak self] in
            self?.submit()
        }
        items.append(buttonItem)
        
        setupItems?(items)
    }
    
    
    func submit() {
        let networkFeeDescription = FeeDescription(identifier: WalletAssetId.xor.rawValue,
                                                   assetId: WalletAssetId.xor.rawValue,
                                                   type: "fee",
                                                   parameters: [],
                                                   accountId: nil,
                                                   minValue: nil,
                                                   maxValue: nil,
                                                   context: nil)
        let networkFee = Fee(
            value: AmountDecimal(value: fee),
            feeDescription: networkFeeDescription
        )

        let dexId = (assetManager.assetInfo(for: baseAssetId)?.isFeeAsset ?? false) ? "0" : "1"
        let shareOfPool = details.first(where: { $0.title == Constants.apyTitle })?.assetAmountText.text ?? ""
        let apy = details.first(where: { $0.title == Constants.apyTitle })?.assetAmountText.text ?? ""
        
        let context: [String: String] = [
            TransactionContextKeys.transactionType: transactionType.rawValue,
            TransactionContextKeys.firstAssetAmount: AmountDecimal(value: firstAssetAmount).stringValue,
            TransactionContextKeys.secondAssetAmount: AmountDecimal(value: secondAssetAmount).stringValue,
            TransactionContextKeys.slippage: String(slippageTolerance),
            TransactionContextKeys.dex: dexId,
            TransactionContextKeys.shareOfPool: shareOfPool,
            TransactionContextKeys.sbApy: apy
        ]

        let transferInfo = TransferInfo(
            source: baseAssetId,
            destination: targetAssetId,
            amount: AmountDecimal(value: firstAssetAmount),
            asset: baseAssetId,
            details: "",
            fees: [networkFee],
            context: context
        )
        
        wireframe?.showActivityIndicator()
        walletService.transfer(info: transferInfo, runCompletionIn: .main) { [weak self] (optionalResult) in
            self?.wireframe?.hideActivityIndicator()

            if let result = optionalResult {
                self?.handleTransfer(result: result)
            }
        }
    }
    
    private func handleTransfer(result: Result<Data, Error>) {
        var status: TransactionBase.Status = .pending
        var txHash = ""
        if case let .failure = result {
            status = .failed
        }
        if case let .success(hex) = result {
            txHash = hex.toHex(includePrefix: true)
        }
        let base = TransactionBase(txHash: txHash,
                                   blockHash: "",
                                   fee: Amount(value: fee),
                                   status: status,
                                   timestamp: "\(Date().timeIntervalSince1970)")
        let swapTransaction = Liquidity(base: base,
                                        firstTokenId: targetAssetId,
                                        secondTokenId: baseAssetId,
                                        firstAmount: Amount(value: firstAssetAmount),
                                        secondAmount: Amount(value: secondAssetAmount),
                                        type: .add)
        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: swapTransaction))
        wireframe?.showActivityDetails(on: view?.controller, model: swapTransaction, assetManager: assetManager) { [weak self] in
            self?.view?.dissmiss(competion: {})
        }
    }
}
