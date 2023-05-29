import Foundation
import CommonWallet
import SoraUIKit
import XNetworking

protocol PoolViewModelFactoryProtocol: AnyObject {
    func createPoolViewModel(with pool: PoolInfo, fiatData: [FiatData], mode: WalletViewMode) -> PoolViewModel?
}

final class PoolViewModelFactory {
    let walletAssets: [AssetInfo]
    let assetManager: AssetManagerProtocol
    weak var fiatService: FiatServiceProtocol?
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        return formatter
    }()
    
    init(walletAssets: [AssetInfo], assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol?) {
        self.walletAssets = walletAssets
        self.assetManager = assetManager
        self.fiatService = fiatService
    }
}

extension PoolViewModelFactory: PoolViewModelFactoryProtocol {
    
    func createPoolViewModel(with pool: PoolInfo, fiatData: [FiatData], mode: WalletViewMode) -> PoolViewModel? {
        guard let baseAsset = walletAssets.first(where: { $0.identifier == pool.baseAssetId  }) else { return nil }
        guard let targetAsset = walletAssets.first(where: { $0.identifier == pool.targetAssetId }) else { return nil }
        
        guard let baseAssetInfo = assetManager.assetInfo(for: baseAsset.identifier) else { return nil }
        guard let targetAssetInfo = assetManager.assetInfo(for: targetAsset.identifier) else { return nil }
        
        guard let rewardAssetInfo = assetManager.assetInfo(for: WalletAssetId.pswap.rawValue) else { return nil }

        let baseBalance = formatter.stringFromDecimal(pool.baseAssetPooledByAccount ?? Decimal(0)) ?? ""
        let targetBalance = formatter.stringFromDecimal(pool.targetAssetPooledByAccount ?? Decimal(0)) ?? ""
        
        var fiatText = ""
        if let firstPriceUsd = fiatData.first(where: { $0.id == baseAsset.identifier })?.priceUsd?.decimalValue,
           let secondPriceUsd = fiatData.first(where: { $0.id == targetAsset.identifier })?.priceUsd?.decimalValue {
            
            let fiatDecimal = (pool.baseAssetPooledByAccount ?? Decimal(0)) * firstPriceUsd + (pool.targetAssetPooledByAccount ?? Decimal(0)) + secondPriceUsd
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        return PoolViewModel(identifier: pool.poolId,
                             title: "\(baseAsset.symbol)-\(targetAsset.symbol)",
                             subtitle: "\(baseBalance) \(baseAsset.symbol) - \(targetBalance) \(targetAsset.symbol)",
                             fiatText: fiatText,
                             baseAssetImage: RemoteSerializer.shared.image(with: baseAssetInfo.icon ?? ""),
                             targetAssetImage: RemoteSerializer.shared.image(with: targetAssetInfo.icon ?? ""),
                             rewardAssetImage: RemoteSerializer.shared.image(with: rewardAssetInfo.icon ?? ""),
                             mode: mode,
                             isFavorite: true)
    }
}
