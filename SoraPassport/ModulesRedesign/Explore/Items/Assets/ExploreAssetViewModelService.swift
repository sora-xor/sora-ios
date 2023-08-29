import Foundation
import Combine
import BigInt

final class ExploreAssetViewModelService {
    let marketCapService: MarketCapServiceProtocol
    var fiatService: FiatServiceProtocol?
    let itemFactory: ExploreItemFactory
    var assetManager: AssetManagerProtocol
    
    @Published var viewModels: [ExploreAssetViewModel] = [ ExploreAssetViewModel(serialNumber: "1"),
                                                           ExploreAssetViewModel(serialNumber: "2"),
                                                           ExploreAssetViewModel(serialNumber: "3"),
                                                           ExploreAssetViewModel(serialNumber: "4"),
                                                           ExploreAssetViewModel(serialNumber: "5") ]
    
    init(
        marketCapService: MarketCapServiceProtocol,
        fiatService: FiatServiceProtocol?,
        itemFactory: ExploreItemFactory,
        assetManager: AssetManagerProtocol
    ) {
        self.marketCapService = marketCapService
        self.fiatService = fiatService
        self.itemFactory = itemFactory
        self.assetManager = assetManager
    }
    
    func setup() {
        Task {
            let assetInfo = await marketCapService.getMarketCap()
            
            let fiat = await fiatService?.getFiat()
            
            let assetMarketCap = assetInfo.compactMap { asset in
                let amount = BigUInt(asset.liquidity) ?? 0
                let precision = Int16(assetManager.assetInfo(for: asset.tokenId)?.precision ?? 0)
                let price = fiat?.first { asset.tokenId == $0.id }?.priceUsd?.decimalValue ?? 0
                let marketCap = (Decimal.fromSubstrateAmount(amount, precision: precision) ?? 0) * price
                return ExploreAssetLiquidity(tokenId: asset.tokenId, marketCap: marketCap)
            }

            let sortedAssetMarketCap = assetMarketCap.sorted { $0.marketCap > $1.marketCap }
            
            let fullListAssets = sortedAssetMarketCap.enumerated().compactMap { (index, marketCap) in
                
                let price = fiat?.first(where: { $0.id == marketCap.tokenId })?.priceUsd?.decimalValue
                
                return self.itemFactory.createExploreAssetViewModel(with: marketCap.tokenId,
                                                                     serialNumber: String(index + 1),
                                                                     price: price,
                                                                     marketCap: marketCap.marketCap)
            }
            viewModels = fullListAssets
        }
    }
}
