import Foundation
import FearlessUtils
import SoraKeystore
import BigInt
import IrohaCrypto

protocol FeeProviderProtocol {
    func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void)
    func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void)
}

final class FeeProvider: FeeProviderProtocol {

    private var feeStore: [String: Decimal] = [:]

    private var selectedAccount: AccountItem? {
        SelectedWalletSettings.shared.currentAccount
    }

    private var extrinsicService: ExtrinsicService {
        let selectedAccount = selectedAccount!
        let engine = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())!
        let runtime = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())!
        return ExtrinsicService(address: selectedAccount.address,
                                                                                  cryptoType: selectedAccount.cryptoType,
                                                                                  runtimeRegistry: runtime,
                                                                                  engine: engine,
                                                                                  operationManager: OperationManagerFacade.sharedManager)
    }

    func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void) {

        let dexId = "0"

        if let cached =  feeStore[type.rawValue] {
            completion(cached)
            return
        }
        var builderClosure: ExtrinsicBuilderClosure?
        switch type {

        case .outgoing:
            builderClosure = { [weak self] builder in
                let callFactory = SubstrateCallFactory()

                let accountId = try SS58AddressFactory().accountId(from: self?.selectedAccount?.address ?? "").toHex()
                let transferCall = try callFactory.transfer(to: accountId,
                                                            asset: WalletAssetId.xor.rawValue,
                                                            amount: 0)

                return try builder
                    .adding(call: transferCall)
            }

        case .swap:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()

                let swapCall = try callFactory.swap(
                    from: WalletAssetId.xor.chainId,
                    to: WalletAssetId.val.chainId,
                    dexId: "0",
                    amountCall: [SwapVariant.desiredInput: SwapAmount(type: .desiredInput, desired: 0, slip: 0)],
                    type: [],
                    filter: 0
                )

                return try builder
                    .adding(call: swapCall)
            }

        case .liquidityAdd:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()

                let depositCall = try callFactory.depositLiquidity(
                    dexId: dexId,
                    assetA: WalletAssetId.xor.chainId,
                    assetB: WalletAssetId.val.chainId,
                    desiredA: 1,
                    desiredB: 1,
                    minA: 1,
                    minB: 1
                )

                return try builder
                    .adding(call: depositCall)
            }
        case .liquidityAddToExistingPoolFirstTime:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()
                let dexId = dexId
                let initializeCall = try callFactory.initializePool(dexId: dexId,
                                                                    baseAssetId: WalletAssetId.xor.chainId,
                                                                    targetAssetId: WalletAssetId.val.chainId)

                let depositCall = try callFactory.depositLiquidity(
                    dexId: dexId,
                    assetA: WalletAssetId.xor.chainId,
                    assetB: WalletAssetId.val.chainId,
                    desiredA: 1,
                    desiredB: 1,
                    minA: 1,
                    minB: 1
                )

                return try builder
                    .with(shouldUseAtomicBatch: true)
                    // .adding(call: initializeCall) // TODO: fix fee calculations for AtomicBatch
                    .adding(call: depositCall)
            }
        case .liquidityAddNewPool:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()

                let registerCall = try callFactory.register(dexId: dexId,
                                                            baseAssetId: WalletAssetId.xor.chainId,
                                                            targetAssetId: WalletAssetId.val.chainId)

                let initializeCall = try callFactory.initializePool(dexId: dexId,
                                                                    baseAssetId: WalletAssetId.xor.chainId,
                                                                    targetAssetId: WalletAssetId.val.chainId)

                let depositCall = try callFactory.depositLiquidity(
                    dexId: dexId,
                    assetA: WalletAssetId.xor.chainId,
                    assetB: WalletAssetId.val.chainId,
                    desiredA: 1,
                    desiredB: 1,
                    minA: 1,
                    minB: 1
                )

                return try builder
                    .with(shouldUseAtomicBatch: true)
                    .adding(call: registerCall)
                    .adding(call: initializeCall)
                    .adding(call: depositCall)
            }
        case .liquidityRemoval:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()

                let withdrawCall = try callFactory.withdrawLiquidityCall(
                    dexId: dexId,
                    assetA: WalletAssetId.val.chainId,
                    assetB: WalletAssetId.val.chainId,
                    assetDesired: 1,
                    minA: 1,
                    minB: 1
                )

                return try builder
                    .adding(call: withdrawCall)
            }
        case .referral:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()

                let addressFactory = SS58AddressFactory()
                let address = self.selectedAccount?.address ?? ""
                let addressType = try? addressFactory.extractAddressType(from: address)
                let accountId = try? addressFactory.accountId(fromAddress: address, type: addressType ?? 0)
                let referrer = accountId?.toHex(includePrefix: true) ?? ""

                let call = try callFactory.setReferrer(referrer: referrer)
                return try builder.adding(call: call)
            }
        case .reward, .incoming, .migration, .extrinsic, .slash:
            ()
        }

        if let builderClosure = builderClosure {
            estimateFee(for: type.rawValue, builderClosure: builderClosure, runningIn: .main, completion: completion)
        }
    }

    func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) {
        if let cached = feeStore[type.rawValue] {
            completion(cached)
            return
        }

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()
            let call = try type == .bond ? callFactory.reserveReferralBalance(balance: 0) : callFactory.unreserveReferralBalance(balance: 0)
            return try builder.adding(call: call)
        }
        
        estimateFee(for: type.rawValue, builderClosure: builderClosure, runningIn: .main, completion: completion)
    }
    
    private func estimateFee(
        for type: String,
        builderClosure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping (Decimal) -> Void
    ) {
        extrinsicService.estimateFee(builderClosure, runningIn: queue, completion: { [weak self] result in
            switch result {
            case let .success(info):
                guard let fee = BigUInt(info), let decimalFee = Decimal.fromSubstrateAmount(fee, precision: 18) else { return }
                self?.feeStore[type] = decimalFee
                completionClosure(decimalFee)
            case let .failure(error):
                print("fee error: \(error)")
            }
        })
    }
}
