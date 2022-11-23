import CommonWallet
import UIKit

final class PolkaswapPoolCellModel {
    let cellReuseIdentifier: String = PolkaswapPoolCell.cellId

    let title: String
    let poolShare: String
    let bonusApy: String
    let baseAssetSymbol: String
    let baseAssetPoolded: String
    let targetAssetSymbol: String
    let targetAssetPooled: String
    let baseAssetFee: String
    let targetAssetFee: String
    let baseAssetImage: WalletImageViewModelProtocol
    let targetAssetImage: WalletImageViewModelProtocol
    private(set) var isExpanded: Bool = false
    private(set) var onExpand: ((Bool) -> Void) -> Void = { _ in }
    private(set) var onAdd: () -> Void = { }
    private(set) var onRemove: () -> Void = { }

    init(
        poolShare: String,
        bonusApy: String,
        baseAssetPoolled: String,
        targetAssetPoolled: String,
        baseAssetFee: String,
        targetAssetFee: String,
        baseAssetInfo: AssetInfo?,
        targetAssetInfo: AssetInfo?,
        details: PoolDetails,
        onAddLiquidy: @escaping (PoolDetails) -> Void,
        onRemoveLiquidy: @escaping (PoolDetails) -> Void,
        onExpand: @escaping () -> Void
    ) {
        self.poolShare = poolShare
        self.bonusApy = bonusApy
        baseAssetPoolded = baseAssetPoolled
        targetAssetPooled = targetAssetPoolled
        self.baseAssetFee = baseAssetFee
        self.targetAssetFee = targetAssetFee

        baseAssetSymbol = baseAssetInfo?.symbol ?? "?"
        targetAssetSymbol = targetAssetInfo?.symbol ?? "?"

        title = "\(baseAssetSymbol)-\(targetAssetSymbol)"

        baseAssetImage = Self.imageForAsset(baseAssetInfo)
        targetAssetImage = Self.imageForAsset(targetAssetInfo)

        self.onExpand = { [unowned self] completion in
            isExpanded.toggle()
            completion(isExpanded)
            onExpand()
        }

        onAdd = {
            onAddLiquidy(details)
        }

        onRemove = {
            onRemoveLiquidy(details)
        }
    }

    private static func imageForAsset(_ assetInfo: AssetInfo?) -> WalletImageViewModelProtocol {
        if let iconString = assetInfo?.icon {
            return WalletSvgImageViewModel(svgString: iconString)
        } else {
            return WalletStaticImageViewModel(staticImage: R.image.assetUnkown() ?? UIImage())
        }
    }
}
