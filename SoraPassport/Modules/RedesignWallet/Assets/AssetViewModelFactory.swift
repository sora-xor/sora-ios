import Foundation
import CommonWallet
import SoraSwiftUI

protocol AssetViewModelFactoryProtocol {
    func createAssetViewModel(with balanceData: BalanceData, mode: AssetViewMode) -> AssetViewModel?
}

final class AssetViewModelFactory {
    let walletAssets: [AssetInfo]
    let assetManager: AssetManagerProtocol

    init(walletAssets: [AssetInfo], assetManager: AssetManagerProtocol) {
        self.walletAssets = walletAssets
        self.assetManager = assetManager
    }
}

extension AssetViewModelFactory: AssetViewModelFactoryProtocol {
    func createAssetViewModel(with balanceData: BalanceData, mode: AssetViewMode) -> AssetViewModel? {
        guard let asset = walletAssets.first(where: { $0.identifier == balanceData.identifier }),
              let assetInfo = assetManager.assetInfo(for: asset.identifier) else {
            return nil
        }

        var symbolViewModel: WalletImageViewModelProtocol?

        if let iconString = assetInfo.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        }

        let balance = balanceData.balance.stringValue + " " + asset.symbol

        return AssetViewModel(title: asset.name,
                              subtitle: balance,
                              imageViewModel: symbolViewModel,
                              mode: mode,
                              isFavorite: assetInfo.visible)
    }
}
