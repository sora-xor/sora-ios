import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation

final class ConfirmRemoveLiquidityViewModel {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var completionHandler: (() -> Void)?
    
    weak var view: ConfirmViewProtocol?
    var wireframe: ConfirmWireframeProtocol?
    var poolInfo: PoolInfo
    let assetManager: AssetManagerProtocol
    
    var firstAssetAmount: Decimal
    var secondAssetAmount: Decimal
    var slippageTolerance: Float
    var details: [DetailViewModel]
    let fee: Decimal
    let walletService: WalletServiceProtocol
    
    var title: String? {
        return R.string.localizable.removePoolConfirmationTitle(preferredLanguages: .currentLocale)
    }
    
    var imageName: String? {
        return nil
    }
    
    init(
        wireframe: ConfirmWireframeProtocol?,
        poolInfo: PoolInfo,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: Float,
        details: [DetailViewModel],
        walletService: WalletServiceProtocol,
        fee: Decimal
    ) {
        self.poolInfo = poolInfo
        self.wireframe = wireframe
        self.assetManager = assetManager
        self.firstAssetAmount = firstAssetAmount
        self.secondAssetAmount = secondAssetAmount
        self.slippageTolerance = slippageTolerance
        self.details = details
        self.fee = fee
        self.walletService = walletService
        self.slippageTolerance = slippageTolerance
    }
}

extension ConfirmRemoveLiquidityViewModel: ConfirmViewModelProtocol {
    func viewDidLoad() {
        updateContent()
    }
}

extension ConfirmRemoveLiquidityViewModel {
    func updateContent() {
        let firstAsset = assetManager.assetInfo(for: poolInfo.baseAssetId)
        let firstAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: 8)
        
        let secondAsset = self.assetManager.assetInfo(for: self.poolInfo.targetAssetId)
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
        
        let text = R.string.localizable.polkaswapOutputEstimated("\(slippageTolerance)%", preferredLanguages: .currentLocale)
        let textItem = SoramitsuTextItem(text: text, fontData: FontType.paragraphS, textColor: .fgPrimary, alignment: .center)
        let slippageTextItem = SoraTextItem(text: textItem.attributedString)
        
        let detailItem = ConfirmDetailsItem(detailViewModels: self.details)
        
        let slipageItem = ConfirmOptionsItem(toleranceText: "\(self.slippageTolerance)%")
        
        let buttonText = SoramitsuTextItem(text: R.string.localizable.commonConfirm(preferredLanguages: .currentLocale),
                                           fontData: FontType.buttonM,
                                           textColor: .bgSurface,
                                           alignment: .center)
        let buttonItem = SoramitsuButtonItem(title: buttonText) { [weak self] in
            self?.submit()
        }
        
        self.setupItems?([confirmAssetsItem,
                          SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                          slippageTextItem,
                          SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                          detailItem,
                          SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                          slipageItem,
                          SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                          buttonItem])
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

        let shareOfPool = details.first(where: { $0.title == Constants.apyTitle })?.assetAmountText.text
        let apy = details.first(where: { $0.title == Constants.apyTitle })?.assetAmountText.text
        let dexId = (assetManager.assetInfo(for: poolInfo.baseAssetId)?.isFeeAsset ?? false) ? "0" : "1"
        let context: [String: String] = [
            TransactionContextKeys.transactionType: TransactionType.liquidityRemoval.rawValue,
            TransactionContextKeys.firstAssetAmount: AmountDecimal(value: firstAssetAmount).stringValue,
            TransactionContextKeys.secondAssetAmount: AmountDecimal(value: secondAssetAmount).stringValue,
            TransactionContextKeys.firstReserves: poolInfo.baseAssetReserves?.description ?? "",
            TransactionContextKeys.totalIssuances: poolInfo.totalIssuances?.description ?? "",
            TransactionContextKeys.shareOfPool: shareOfPool ?? "",
            TransactionContextKeys.slippage: String(slippageTolerance),
            TransactionContextKeys.sbApy: apy ?? "",
            TransactionContextKeys.dex: dexId
        ]

        let transferInfo = TransferInfo(
            source: poolInfo.baseAssetId,
            destination: poolInfo.targetAssetId,
            amount: AmountDecimal(value: firstAssetAmount),
            asset: poolInfo.baseAssetId,
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
                                        firstTokenId: poolInfo.targetAssetId,
                                        secondTokenId: poolInfo.baseAssetId,
                                        firstAmount: Amount(value: firstAssetAmount),
                                        secondAmount: Amount(value: secondAssetAmount),
                                        type: .withdraw)
        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: swapTransaction))
        wireframe?.showActivityDetails(on: view?.controller, model: swapTransaction, assetManager: assetManager) { [weak self] in
            self?.view?.dissmiss(competion: self?.completionHandler)
        }
    }
}
