import CommonWallet
import FearlessUtils
import Foundation
import SoraFoundation

enum TransactionHistoryViewModelFactoryError: Error {
    case missingAsset
    case unsupportedType
}

final class TransactionHistoryViewModelFactory: HistoryItemViewModelFactoryProtocol {
    let amountFormatterFactory: AmountFormatterFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let assets: [WalletAsset]
    let assetManager: AssetManagerProtocol

    let iconGenerator: PolkadotIconGenerator = PolkadotIconGenerator()

    init(
        amountFormatterFactory: AmountFormatterFactoryProtocol,
        dateFormatter: LocalizableResource<DateFormatter>,
        assets: [WalletAsset],
        assetManager: AssetManagerProtocol
    ) {
        self.amountFormatterFactory = amountFormatterFactory
        self.dateFormatter = dateFormatter
        self.assets = assets
        self.assetManager = assetManager
    }

    func createItemFromData(
        _ data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) throws -> WalletViewModelProtocol {
        // legacy conversion
        let assetId = data.assetId.count > 5 ? data.assetId : WalletAssetId(rawValue: data.assetId)?.chainId
        guard let asset = assets.first(where: { $0.identifier == assetId }) else {
            throw TransactionHistoryViewModelFactoryError.missingAsset
        }
        let formatter = NumberFormatter.historyAmount
        let color = data.status == .rejected ? R.color.statusError() : R.color.statusSuccess()
        let baseFont = UIFont.styled(for: .paragraph1, isBold: true)!

        var amount = amountFormatterFactory.createTokenFormatter(for: asset, maxPrecision: 8)
            .value(for: locale)
            .stringFromDecimal(data.amount.decimalValue)
            ?? ""

        switch data.transactionType {
        case .incoming:
            amount = "\(String.amountIncrease) \(amount)"
        case .outgoing:
            amount = "\(String.amountDecrease) \(amount)"
        case .reward, .slash, .swap, .extrinsic, .liquidityRemoval, .liquidityAdd:
            _ = amount
        }

        let date = Date(timeIntervalSince1970: TimeInterval(data.timestamp))
        let dateString = dateFormatter.value(for: locale).string(from: date)

        guard let transactionType = TransactionType(rawValue: data.type) else {
            throw TransactionHistoryViewModelFactoryError.unsupportedType
        }

        var imageViewModel: WalletImageViewModelProtocol?
        if let icon = icon(for: transactionType) {
            imageViewModel = WalletStaticImageViewModel(staticImage: icon)
        }

        var assetImageViewModel: WalletImageViewModelProtocol?
        var peerImageViewModel: WalletImageViewModelProtocol?
        var title = ""


        let command = commandFactory.prepareTransactionDetailsCommand(with: data)

        switch data.transactionType {
        case .incoming, .outgoing:
            let assetInfo = assetManager.assetInfo(for: asset.identifier)
            if let iconString = assetInfo?.icon {
                assetImageViewModel = WalletSvgImageViewModel(svgString: iconString)
            } else {
                assetImageViewModel = WalletStaticImageViewModel(staticImage: R.image.assetUnkown()!)
            }
            let sign = data.transactionType == .incoming ? String.amountIncrease : String.amountDecrease
            let am = sign + (formatter.stringFromDecimal(data.amount.decimalValue) ?? "0")
            let attributedAmount = am.prettyCurrency(baseFont: baseFont, smallSize: 11, locale: locale)
            let attributedAsset = NSAttributedString(string: asset.symbol, attributes: [.font: baseFont])
            let result = NSMutableAttributedString(attributedString: attributedAmount)
            result.append(NSAttributedString.space)
            result.append(attributedAsset)
            title = data.peerName?.soraConcat ?? ""
            return HistoryItemViewModel(
                title: title,
                details: dateString,
                amount: result,
                type: transactionType,
                status: data.status,
                imageViewModel: imageViewModel,
                assetImageViewModel: assetImageViewModel,
                peerImageViewModel: peerImageViewModel,
                command: command
            )
        case .swap:
            guard let targetAmount = formatter.stringFromDecimal(data.amount.decimalValue),
                  let sourceAmountDecimal = AmountDecimal(string: data.details),
                  let  sourceAmount = formatter.stringFromDecimal(sourceAmountDecimal.decimalValue) else {
                      throw TransactionHistoryViewModelFactoryError.unsupportedType
                  }
            let sourceAsset = assets.first(where: { $0.identifier == data.peerId })

            let assetInfo = assetManager.assetInfo(for: asset.identifier)
            if let iconString = assetInfo?.icon {
                peerImageViewModel = WalletSvgImageViewModel(svgString: iconString)
            } else {
                peerImageViewModel = WalletStaticImageViewModel(staticImage: R.image.assetUnkown()!)
            }

            if let sourceAsset = sourceAsset, let sourceAssetInfo = assetManager.assetInfo(for: sourceAsset.identifier) {

                if let iconString = sourceAssetInfo.icon {
                    assetImageViewModel = WalletSvgImageViewModel(svgString: iconString)
                } else {
                    assetImageViewModel = WalletStaticImageViewModel(staticImage: R.image.assetUnkown()!)
                }
            }

            
            let attributedSource = NSMutableAttributedString(string: String.amountDecrease, attributes: [.font: baseFont])
            attributedSource.append(sourceAmount.prettyCurrency(baseFont:baseFont, smallSize: 11, locale: locale))
            attributedSource.append(NSAttributedString.space)
            let attributedSourceAsset = NSAttributedString(string: sourceAsset?.symbol ?? "???", attributes: [.font: baseFont])
            attributedSource.append(attributedSourceAsset)

            let attributedTarget = NSMutableAttributedString(string: String.amountIncrease, attributes: [.font: baseFont])
            attributedTarget.append(targetAmount.prettyCurrency(baseFont: baseFont, smallSize: 11, locale: locale))
            attributedTarget.addAttribute(.foregroundColor, value: color, range: attributedTarget.wholeRange)
            attributedTarget.append(NSAttributedString.space)
            let attributedTargetAsset = NSAttributedString(string: asset.symbol, attributes: [.font: baseFont])
            attributedTarget.append(attributedTargetAsset)

            return HistorySwapViewModel(
                title: attributedSource,
                details: dateString,
                amount: attributedTarget,
                type: transactionType,
                status: data.status,
                imageViewModel: imageViewModel,
                assetImageViewModel: assetImageViewModel,
                peerImageViewModel: peerImageViewModel,
                command: command
            )

        case .liquidityRemoval, .liquidityAdd:
            let command = commandFactory.prepareTransactionDetailsCommand(with: data)
            return LiquidityHistoryViewModel(
                assetTransactionData: data,
                asset: asset,
                assetManager: assetManager,
                command: command,
                locale: locale
            )

        case .reward, .slash, .extrinsic:
            break
        }

        return HistoryItemViewModel(
            title: title,
            details: dateString,
            amount: NSAttributedString(string: amount),
            type: transactionType,
            status: data.status,
            imageViewModel: imageViewModel,
            assetImageViewModel: assetImageViewModel,
            peerImageViewModel: peerImageViewModel,
            command: command
        )
    }

    func icon(for transtactionType: TransactionType) -> UIImage? {
        switch transtactionType {
        case .incoming:
            return R.image.historyWalletReceive()
        case .outgoing:
            return R.image.historyWalletSend()
        case .swap:
            return R.image.historyWalletSwap()
        case .liquidityAdd, .liquidityRemoval:
            return R.image.historyWalletLiquidity()
        case .reward, .slash, .extrinsic:
            return nil
        }
    }
}
