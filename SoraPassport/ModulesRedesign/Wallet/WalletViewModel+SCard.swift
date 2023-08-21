import CommonWallet
import RobinHood
import SCard
import SoraFoundation

extension RedesignWalletViewModel {

    internal func initSoraCard() -> SCard {
        guard SCard.shared == nil else { return SCard.shared! }

        poolService.appendDelegate(delegate: self)

        startTotalBalanceStream()

        let soraCard = SCard(
            addressProvider: { SelectedWalletSettings.shared.currentAccount?.address ?? "" },
            config: .prod,
            balanceStream: xorBalanceStream,
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

    private func startTotalBalanceStream() {
        let balanceProvider = try? providerFactory.createBalanceDataProvider(for: [.xor], onlyVisible: false)
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            guard let change = changes.first else { return }
            switch change {
            case .insert(let items), .update(let items):

                /// wallet xor balance + frozen + bonded
                if let context = items.first?.context {
                    let balanceContext = BalanceContext(context: context)
                    self?.totalXorBalance = balanceContext.total + balanceContext.frozen + balanceContext.bonded
                }

                /// pooled xor
                self?.poolService.loadPools(isNeedForceUpdate: false)

                return
            case .delete(_):
                break
            @unknown default:
                break
            }
        }

        balanceProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: changesBlock,
            failing: { (error: Error) in },
            options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        )

        var refreshBalanceTimer = Timer()
        refreshBalanceTimer.invalidate()
        refreshBalanceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [refreshBalanceTimer] _ in
            _ = refreshBalanceTimer
            balanceProvider?.refresh()
        }
    }
}

extension RedesignWalletViewModel: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        poolService.loadPools(currentAsset: .xor, completion: { [weak self] poolInfos in
            var xorPooledTotal = Decimal(0)
            poolInfos.forEach { poolInfo in
                if poolInfo.baseAssetId == .xor {
                    xorPooledTotal += poolInfo.targetAssetPooledByAccount ?? .zero
                } else {
                    xorPooledTotal += poolInfo.baseAssetPooledByAccount  ?? .zero
                }
            }
            if let totalXorBalance = self?.totalXorBalance {
                self?.xorBalanceStream.wrappedValue = totalXorBalance + xorPooledTotal
            }
        })
    }
}
