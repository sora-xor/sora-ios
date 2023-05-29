import Foundation
import CommonWallet
import SoraUIKit
import XNetworking
import SoraFoundation

protocol AssetViewModelFactoryProtocol: AnyObject {
    func createAssetViewModel(with balanceData: BalanceData, fiatData: [FiatData], mode: WalletViewMode) -> AssetViewModel?
    func createAssetViewModel(with asset: AssetInfo, fiatData: [FiatData], mode: WalletViewMode) -> AssetViewModel?
}

final class AssetViewModelFactory {
    let walletAssets: [AssetInfo]
    let assetManager: AssetManagerProtocol
    weak var fiatService: FiatServiceProtocol?
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }()

    init(walletAssets: [AssetInfo], assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol?) {
        self.walletAssets = walletAssets
        self.assetManager = assetManager
        self.fiatService = fiatService
    }
}

extension AssetViewModelFactory: AssetViewModelFactoryProtocol {
    func createAssetViewModel(with balanceData: BalanceData, fiatData: [FiatData], mode: WalletViewMode) -> AssetViewModel? {
        guard let asset = walletAssets.first(where: { $0.identifier == balanceData.identifier }),
              let assetInfo = assetManager.assetInfo(for: asset.identifier) else {
            return nil
        }

        let balance = (formatter.stringFromDecimal(balanceData.balance.decimalValue) ?? "") + " " + asset.symbol
        var fiatText = ""
        if let priceUsd = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = balanceData.balance.decimalValue * priceUsd
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        return AssetViewModel(identifier: asset.identifier,
                              title: asset.name,
                              subtitle: balance,
                              fiatText: fiatText,
                              icon: RemoteSerializer.shared.image(with: assetInfo.icon ?? ""),
                              mode: mode,
                              isFavorite: assetInfo.visible)
    }
    
    func createAssetViewModel(with asset: AssetInfo, fiatData: [FiatData], mode: WalletViewMode) -> AssetViewModel? {
        var fiatText = ""
        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(usdPrice) ?? "")
        }

        return AssetViewModel(identifier: asset.assetId,
                              title: asset.name,
                              subtitle: asset.symbol,
                              fiatText: fiatText,
                              icon: RemoteSerializer.shared.image(with: asset.icon ?? ""),
                              mode: mode,
                              isFavorite: asset.visible)
    }
}
