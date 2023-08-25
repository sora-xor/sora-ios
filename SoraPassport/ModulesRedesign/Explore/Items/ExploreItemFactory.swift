import Foundation
import RobinHood
import CommonWallet
import SoraUIKit
import SoraFoundation
import IrohaCrypto

final class ExploreItemFactory {
    let assetManager: AssetManagerProtocol

    init(assetManager: AssetManagerProtocol) {
        self.assetManager = assetManager
    }
}

extension ExploreItemFactory {
    
    func createExploreAssetViewModel(with assetId: String, serialNumber: String, price: Decimal?, marketCap: Decimal) -> ExploreAssetViewModel? {
        guard let assetInfo = assetManager.assetInfo(for: assetId) else { return nil }

        let fiatText = price != nil ? "$" + (NumberFormatter.fiat.stringFromDecimal(price ?? .zero) ?? "") : ""
        let marketCapText = "$" + marketCap.formatNumber()
        
        return ExploreAssetViewModel(assetId: assetId,
                                     symbol: assetInfo.symbol,
                                     title: assetInfo.name,
                                     price: fiatText,
                                     serialNumber: serialNumber,
                                     marketCap: marketCapText,
                                     icon: RemoteSerializer.shared.image(with: assetInfo.icon ?? ""))
    }

    func createPoolsItem(with pool: ExplorePool, serialNumber: String, apy: Decimal? = nil) -> ExplorePoolViewModel? {
        guard let baseAssetInfo = assetManager.assetInfo(for: pool.baseAssetId) else { return nil }
        guard let targetAssetInfo = assetManager.assetInfo(for: pool.targetAssetId) else { return nil }

        let tvl = "$" + pool.tvl.formatNumber()
        let apyText: String? = apy != nil ? "\(NumberFormatter.percent.stringFromDecimal((apy ?? .zero) * 100) ?? "")% APY" : nil

        return ExplorePoolViewModel(poolId: pool.id.description,
                                    title: "\(baseAssetInfo.symbol)-\(targetAssetInfo.symbol)",
                                    tvl: tvl,
                                    serialNumber: serialNumber,
                                    apy: apyText,
                                    baseAssetId: baseAssetInfo.assetId,
                                    targetAssetId: targetAssetInfo.assetId,
                                    baseAssetIcon: RemoteSerializer.shared.image(with: baseAssetInfo.icon ?? ""),
                                    targetAssetIcon:  RemoteSerializer.shared.image(with: targetAssetInfo.icon ?? ""))
    }
}
