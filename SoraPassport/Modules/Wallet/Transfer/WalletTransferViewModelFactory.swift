import Foundation
import CommonWallet

struct WalletTransferViewModelFactory {
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let feeCalculationFactory: FeeCalculationFactoryProtocol
    let xorAsset: WalletAsset

    init(amountFormatterFactory: NumberFormatterFactoryProtocol,
         feeCalculationFactory: FeeCalculationFactoryProtocol,
         xorAsset: WalletAsset) {
        self.amountFormatterFactory = amountFormatterFactory
        self.feeCalculationFactory = feeCalculationFactory
        self.xorAsset = xorAsset
    }

    func calculateTotalXORRequiredForInput(amount: Decimal, feeDescriptions: [FeeDescription]) throws -> Decimal {
        let transferStrategy = try feeCalculationFactory
            .createTransferFeeStrategyForDescriptions(feeDescriptions,
                                                      assetId: xorAsset.identifier,
                                                      precision: xorAsset.precision)

        let results = try transferStrategy.calculate(for: amount)

        return results.total
    }

    func createAssetTransferStateIconFromAmount(_ totalAmount: Decimal,
                                                tokens: TokenBalancesData,
                                                receiver: String,
                                                feeDescriptions: [FeeDescription]) -> UIImage? {
        if feeDescriptions
            .first(where: { $0.context?[WalletOperationContextKey.Receiver.isMine] != nil }) != nil {
            if NSPredicate.ethereumAddress.evaluate(with: receiver) {
                return R.image.iconSoraXor()
            } else {
                return R.image.iconXorErc()
            }
        }

        if NSPredicate.ethereumAddress.evaluate(with: receiver) {
             if totalAmount <= tokens.ethereum {
                return R.image.iconXorErc()
            } else if totalAmount <= tokens.soranet {
                return  R.image.iconSoraXor()
            } else {
                return R.image.iconCrossChain()
            }
        } else {
            if totalAmount <= tokens.soranet {
                return R.image.iconSoraXor()
            } else if tokens.soranet == 0.0 && totalAmount <= tokens.ethereum {
                return R.image.iconXorErc()
            } else {
                return R.image.iconCrossChain()
            }
        }
    }
}

extension WalletTransferViewModelFactory: TransferViewModelFactoryOverriding {
    func createReceiverViewModel(_ inputState: TransferInputState,
                                 payload: TransferPayload,
                                 locale: Locale) throws ->  MultilineTitleIconViewModelProtocol? {
        if NSPredicate.ethereumAddress.evaluate(with: payload.receiveInfo.accountId) {
            return MultilineTitleIconViewModel(text: payload.receiveInfo.accountId,
                                               icon: R.image.iconXorErc())
        } else if payload.receiverName.isEmpty {
            return MultilineTitleIconViewModel(text: payload.receiveInfo.accountId,
                                               icon: R.image.iconSoraXor())
        } else {
            return nil
        }
    }

    func createSelectedAssetViewModel(_ inputState: TransferInputState,
                                      selectedAssetState: SelectedAssetState,
                                      payload: TransferPayload,
                                      locale: Locale) throws -> AssetSelectionViewModelProtocol? {
        let title: String
        let subtitle: String
        let details: String

        let asset = inputState.selectedAsset

        if let platform = asset.platform?.value(for: locale) {
            title = platform
            subtitle = asset.name.value(for: locale)
        } else {
            title = asset.name.value(for: locale)
            subtitle = ""
        }

        let amountFormatter = amountFormatterFactory.createDisplayFormatter(for: asset)

        if let balanceData = inputState.balance,
            let formattedBalance = amountFormatter.value(for: locale)
                .string(from: balanceData.balance.decimalValue as NSNumber) {
            details = "\(asset.symbol)\(formattedBalance)"
        } else {
            details = ""
        }

        var icon: UIImage? = R.image.iconSoraXor()
        let tokens = TokenBalancesData(balanceContext: inputState.balance?.context ?? [:])

        if
            let feeDescriptions = inputState.metadata?.feeDescriptions,
            let totalAmount = try? calculateTotalXORRequiredForInput(amount: inputState.amount ?? 0,
                                                                     feeDescriptions: feeDescriptions) {
            icon = createAssetTransferStateIconFromAmount(totalAmount,
                                                          tokens: tokens,
                                                          receiver: payload.receiveInfo.accountId,
                                                          feeDescriptions: feeDescriptions)
        }

        return AssetSelectionViewModel(title: title,
                                       subtitle: subtitle,
                                       details: details,
                                       icon: icon,
                                       state: selectedAssetState)
    }

    func createAssetSelectionTitle(_ inputState: TransferInputState,
                                   payload: TransferPayload,
                                   locale: Locale) throws -> String? {
        let assetState = SelectedAssetState(isSelecting: false, canSelect: false)

        guard let viewModel = try createSelectedAssetViewModel(inputState,
                                                               selectedAssetState: assetState,
                                                               payload: payload,
                                                               locale: locale) else {
            return nil
        }

        if !viewModel.details.isEmpty {
            return "\(viewModel.title) - \(viewModel.details)"
        } else {
            return viewModel.title
        }
    }

    func createAccessoryViewModel(_ inputState: TransferInputState,
                                  payload: TransferPayload?,
                                  locale: Locale) throws -> AccessoryViewModelProtocol? {
        let action = R.string.localizable.transactionContinue(preferredLanguages: locale.rLanguages)
        return AccessoryViewModel(title: "", action: action)
    }
}
