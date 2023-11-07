import CommonWallet
import RobinHood
import SCard
import SoraFoundation

extension RedesignWalletViewModel {

    internal func initSoraCard() -> SCard {
        guard SCard.shared == nil else {
            startTotalBalanceStream()
            SCard.shared?.updateBalance(stream: xorBalanceStream)
            return SCard.shared!
        }
        startTotalBalanceStream()

        #if F_DEV
        let config = SCard.Config.test // Sora Dev
        #elseif F_TEST
        let config = SCard.Config.test // Soralution
        #elseif F_STAGING
        let config = SCard.Config.prod // Sora Staging
        #else
        let config = SCard.Config.prod // SORA release
        #endif

        let soraCard = SCard(
            addressProvider: { SelectedWalletSettings.shared.currentAccount?.address ?? "" },
            config: config,
            balanceStream: xorBalanceStream,
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

    private func startTotalBalanceStream() {
        totalXorBalance = nil
        singleSidedXorFarmedPools = nil
        referralBalance = nil
        xorBalanceStream = SCStream<Decimal>(wrappedValue: Decimal(0))

        poolsService.appendDelegate(delegate: self)
        balanceProvider?.removeObserver(self)
        balanceProvider = try? providerFactory.createBalanceDataProvider(for: [.xor], onlyVisible: false)
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            guard let change = changes.first else { return }
            switch change {
            case .insert(let items), .update(let items):

                /// wallet xor balance + frozen + bonded
                if let context = items.first?.context {
                    let balanceContext = BalanceContext(context: context)
                    self?.totalXorBalance = balanceContext.total //+ balanceContext.frozen + balanceContext.bonded
                }

                /// referrals.referrerBalances
                guard let operation = self?.referralFactory.createReferrerBalancesOperation() else { return }
                operation.completionBlock = { [weak self] in
                    do {
                        guard let data = try operation.extractResultData()?.underlyingValue else {
                            self?.referralBalance = .zero
                            return
                        }
                        self?.referralBalance = Decimal.fromSubstrateAmount(data.value, precision: 18) ?? Decimal(0)
                    } catch {
                         self?.referralBalance = .zero
                        Logger.shared.error("createReferrerBalancesOperation Request unsuccessful")
                    }
                }
                OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)


                /// Include the amount locked in the Demeter one-sided staking pools( isFarm == false)
                self?.farmingService.getSingleSidedXorFarmedPools { [weak self] pools in

                    var totalPooledTokens: Decimal = .zero
                    pools.forEach { pool in
                        totalPooledTokens += Decimal.fromSubstrateAmount(pool.pooledTokens, precision: 18) ?? .zero
                    }

                    self?.singleSidedXorFarmedPools = totalPooledTokens

                    /// pooled xor
                    self?.poolsService.loadAccountPools(isNeedForceUpdate: false)
                }

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
        refreshBalanceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self, refreshBalanceTimer] _ in
            _ = refreshBalanceTimer
            self?.balanceProvider?.refresh()
        }
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
