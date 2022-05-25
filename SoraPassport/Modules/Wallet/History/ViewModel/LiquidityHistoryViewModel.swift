import CommonWallet
import UIKit

final class LiquidityHistoryViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String {
        return HistoryConstants.liquidityHistoryCellId
    }

    var itemHeight: CGFloat { HistoryConstants.historyHeight }

    let title: NSAttributedString
    let rightTitle: NSAttributedString
    let rightSubtitle: NSAttributedString
    let image: UIImage
    let baseAssetImage: WalletImageViewModelProtocol
    let targetAssetImage: WalletImageViewModelProtocol
    let command: WalletCommandProtocol?
    let locale: Locale

    convenience init(
        assetTransactionData: AssetTransactionData,
        asset: WalletAsset,
        assetManager: AssetManagerProtocol,
        command: WalletCommandProtocol?,
        locale: Locale
    ) {
        let liquidity = SubqueryLiquidity(
            baseAssetId: assetTransactionData.peerId,
            targetAssetId: assetTransactionData.assetId,
            targetAssetAmount: assetTransactionData.amount.stringValue,
            baseAssetAmount: assetTransactionData.details,
            type: TransactionLiquidityType(rawValue: assetTransactionData.type) ?? .removal
        )

        self.init(
            liquidity: liquidity,
            timestamp: assetTransactionData.timestamp,
            asset: asset,
            status: assetTransactionData.status,
            assetManager: assetManager,
            command: command,
            locale: locale
        )
    }

    init(
        liquidity: SubqueryLiquidity,
        timestamp: Int64,
        asset: WalletAsset,
        status: AssetTransactionStatus,
        assetManager: AssetManagerProtocol,
        command: WalletCommandProtocol?,
        locale: Locale
    ) {
        title = Self.formatedTitle(liquidity: liquidity, timestamp: timestamp)

        let baseAssetSymbol = assetManager.assetInfo(for: liquidity.baseAssetId)?.symbol ?? ""
        let targetAssetSymbol = assetManager.assetInfo(for: liquidity.targetAssetId)?.symbol ?? ""

        if status == .rejected {
            rightTitle = NSAttributedString(
                string: R.string.localizable.commonFailed(),
                attributes: [
                    .font: UIFont.styled(for: .paragraph1, isBold: true)!,
                    .foregroundColor: R.color.statusError()!
                ]
            )
            rightSubtitle = .init()
        } else {
            rightTitle = Self.formatedAmount(
                amout: liquidity.baseAssetAmount,
                liquidityType: liquidity.type,
                assetSymbol: baseAssetSymbol,
                locale: locale
            )

            rightSubtitle = Self.formatedAmount(
                amout: liquidity.targetAssetAmount,
                liquidityType: liquidity.type,
                assetSymbol: targetAssetSymbol,
                locale: locale
            )
        }

        image = R.image.historyWalletLiquidity() ?? UIImage()
        baseAssetImage = Self.imageForAsset(id: liquidity.baseAssetId, assetManager: assetManager)
        targetAssetImage = Self.imageForAsset(id: liquidity.targetAssetId, assetManager: assetManager)
        self.command = command
        self.locale = locale
    }

    static func formatedTitle(liquidity: SubqueryLiquidity, timestamp: Int64) -> NSAttributedString {
        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.styled(for: .paragraph1)!,
            .foregroundColor: R.color.baseContentPrimary()!
        ]

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.styled(for: .uppercase2, isBold: false).withSize(15),
            .foregroundColor: R.color.neumorphism.textDark()!
        ]

        let date = DateFormatter.history.value(for: .current).string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))

        let time = NSAttributedString(string: "\(date) ", attributes: timeAttributes)

        let title = NSAttributedString(string: liquidity.type.localizedString, attributes: titleAttributes)

        let result = NSMutableAttributedString()
        result.append(time)
        result.append(title)

        return result
    }

    static func formatedAmount(
        amout: String,
        liquidityType: TransactionLiquidityType,
        assetSymbol: String,
        locale: Locale
    ) -> NSAttributedString {
        let amountAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.styled(for: .paragraph1, isBold: true)!,
            .foregroundColor: liquidityType == .removal ? R.color.statusSuccess()! : R.color.baseContentPrimary()!
        ]

        let decimalsAmountAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.styled(for: .paragraph1, isBold: true).withSize(10),
            .foregroundColor: liquidityType == .removal ? R.color.statusSuccess()! : R.color.baseContentPrimary()!
        ]

        let assetAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.styled(for: .paragraph1, isBold: true)!,
            .foregroundColor: R.color.baseContentPrimary()!
        ]

        let sign = liquidityType == .removal ? String.amountIncrease : .amountDecrease
        let formatter = NumberFormatter.historyAmount
        let formattedAmount = formatter.stringFromDecimal(Decimal(string: amout) ?? .zero) ?? ""

        let asset = NSAttributedString(string: assetSymbol, attributes: assetAttributes)

        let am = formattedAmount.prettyCurrency(baseFont: UIFont.styled(for: .paragraph1, isBold: true), smallSize: 10, locale: locale)

        let result = NSMutableAttributedString()
        result.append(am)
        result.append(NSAttributedString(string: " "))
        result.append(asset)

        return result
    }

    static func imageForAsset(id: String, assetManager: AssetManagerProtocol) -> WalletImageViewModelProtocol {
        let assetInfo = assetManager.assetInfo(for: id)
        if let iconString = assetInfo?.icon {
            return WalletSvgImageViewModel(svgString: iconString)
        } else {
            return WalletStaticImageViewModel(staticImage: R.image.assetUnkown() ?? UIImage())
        }
    }
}
