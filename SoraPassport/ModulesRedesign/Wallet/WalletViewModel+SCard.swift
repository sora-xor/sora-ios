
import RobinHood
import SCard
import SoraFoundation

extension RedesignWalletViewModel {

    @MainActor
    internal func initSoraCard() -> SCard {
        guard SCard.shared == nil else {
            return SCard.shared!
        }

        #if F_DEV
        let config = SCard.Config.dev // Sora Dev
        #elseif F_TEST
        let config = SCard.Config.test // Soralution
        #elseif F_STAGING
        let config = SCard.Config.prod // Sora Staging
        #elseif F_RELEASE
        let config = SCard.Config.prod // Sora Production
        #else
        let config = SCard.Config.prod // Sora Production
        #endif

        let soraCard = SCard(
            addressProvider: { SelectedWalletSettings.shared.currentAccount?.address ?? "" },
            config: config,
            onReceiveController: { [weak self] vc in
                self?.showReceiveController(in: vc)
            },
            onSwapController: { [weak self] vc in
                self?.showSwapController(in: vc)
            }
        )

        SCard.shared = soraCard

        LocalizationManager.shared.addObserver(with: soraCard) { [weak soraCard] (_, newLocalization) in
            soraCard?.selectedLocalization = newLocalization
        }

        return soraCard
    }
}

extension RedesignWalletViewModel: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        let poolInfos = poolsService.loadPools(currentAsset: .xor)
        var xorPooledTotal = Decimal(0)
        poolInfos.forEach { poolInfo in
            if poolInfo.baseAssetId == .xor {
                xorPooledTotal += poolInfo.targetAssetPooledByAccount ?? .zero
            } else {
                xorPooledTotal += poolInfo.baseAssetPooledByAccount  ?? .zero
            }
        }
        if let totalXorBalance = totalXorBalance,
           let referralBalance = referralBalance,
           let singleSidedXorFarmedPools = singleSidedXorFarmedPools
        {
            xorBalanceStream.wrappedValue = totalXorBalance + referralBalance + xorPooledTotal + singleSidedXorFarmedPools
        }
    }
}
