import Foundation
import SoraUIKit
import CommonWallet
import XNetworking
import FearlessUtils
import SoraFoundation

final class PoolDetailsItemFactory {
    let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }()
    
    func createAccountItem(
        with assetManager: AssetManagerProtocol,
        poolInfo: PoolInfo,
        apy: SbApyInfo?,
        detailsFactory: DetailViewModelFactoryProtocol,
        viewModel: PoolDetailsViewModelProtocol,
        pools: [StakedPool]
    ) -> SoramitsuTableViewItemProtocol {

        let baseAsset = assetManager.assetInfo(for: poolInfo.baseAssetId)
        let targetAsset = assetManager.assetInfo(for: poolInfo.targetAssetId)
        let rewardAsset = assetManager.assetInfo(for: WalletAssetId.pswap.rawValue)
        
        let baseAssetSymbol = baseAsset?.symbol.uppercased() ?? ""
        let targetAssetSymbol = targetAsset?.symbol.uppercased() ?? ""
        
        let poolText = R.string.localizable.polkaswapPoolTitle(preferredLanguages: .currentLocale)
        
        let title = "\(baseAssetSymbol)-\(targetAssetSymbol) \(poolText)"
        
        let detailsViewModels = detailsFactory.createPoolDetailViewModels(with: poolInfo, apy: apy, viewModel: viewModel)

        let isRemoveLiquidityEnabled = pools.map {
            let pooledTokens = Decimal.fromSubstrateAmount($0.pooledTokens, precision: 18) ?? .zero
            let accountPoolBalance = poolInfo.accountPoolBalance ?? .zero
            return (pooledTokens / accountPoolBalance) == 1
        }.filter { $0 }.isEmpty
        
        let detailsItem = PoolDetailsItem(title: title,
                                          firstAssetImage: baseAsset?.icon,
                                          secondAssetImage: targetAsset?.icon,
                                          rewardAssetImage: rewardAsset?.icon,
                                          detailsViewModel: detailsViewModels,
                                          isRemoveLiquidityEnabled: isRemoveLiquidityEnabled)
        detailsItem.handler = { type in
            viewModel.infoButtonTapped(with: type)
        }

        return detailsItem
    }
    
    
    func stakedItem(with assetManager: AssetManagerProtocol, poolInfo: PoolInfo, stakedPool: StakedPool) -> SoramitsuTableViewItemProtocol {
        let rewardAsset = assetManager.assetInfo(for: stakedPool.rewardAsset.value)
        let rewardSymbol = rewardAsset?.symbol.uppercased() ?? ""
        
        let accountPoolBalance = poolInfo.accountPoolBalance ?? .zero
        let pooledTokens = Decimal.fromSubstrateAmount(stakedPool.pooledTokens, precision: 18) ?? .zero
        let percentage = accountPoolBalance > 0 ? (pooledTokens / accountPoolBalance) * 100 : 0

        let progressTitle = R.string.localizable.polkaswapFarmingPoolShare(preferredLanguages: .currentLocale)

        let text = SoramitsuTextItem(text: "\(percentFormatter.stringFromDecimal(percentage) ?? "")%",
                                     fontData: FontType.textS,
                                     textColor: .fgPrimary,
                                     alignment: .right)

        let progressDetails = DetailViewModel(title: progressTitle,
                                              assetAmountText: text,
                                              type: .progress(percentage.floatValue))
        
        let rewardText = SoramitsuTextItem(text: rewardSymbol,
                                           fontData: FontType.textS,
                                           textColor: .fgPrimary,
                                           alignment: .right)

        let rewardDetailsViewModel = DetailViewModel(title: R.string.localizable.polkaswapRewardPayout(preferredLanguages: .currentLocale),
                                                     rewardAssetImage: rewardAsset?.icon,
                                                     assetAmountText: rewardText)

        let title = R.string.localizable.polkaswapFarmingStakedFor(rewardSymbol, preferredLanguages: .currentLocale)
        return StakedItem(title: title, detailsViewModel: [rewardDetailsViewModel, progressDetails])
    }
}

extension Decimal {
    var floatValue: Float {
        return NSDecimalNumber(decimal:self).floatValue
    }
}
