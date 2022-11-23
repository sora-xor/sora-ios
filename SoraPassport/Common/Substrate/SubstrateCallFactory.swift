import BigInt
import FearlessUtils
import Foundation
import IrohaCrypto

protocol SubstrateCallFactoryProtocol {
    func migrate(irohaAddress: String, irohaKey: String, signature: String) throws -> RuntimeCall<MigrateCall>
}

final class SubstrateCallFactory: SubstrateCallFactoryProtocol {
    private let addressFactory = SS58AddressFactory()

    func migrate(irohaAddress: String, irohaKey: String, signature: String) throws -> RuntimeCall<MigrateCall> {
        let call = MigrateCall(irohaAddress: irohaAddress, irohaPublicKey: irohaKey, irohaSignature: signature)
        return RuntimeCall<MigrateCall>.migrate(call)
    }

    func transfer(to receiverAccountId: String,
                  asset: String,
                  amount: BigUInt) throws -> RuntimeCall<SoraTransferCall> {

        let data = try Data(hexString: receiverAccountId)

        let call = SoraTransferCall(receiver: MultiAddress.accoundId(data),
                                    amount: amount,
                                    assetId: AssetId(wrappedValue:asset))
        return RuntimeCall<SoraTransferCall>.transfer(call)
    }

    func swap(from asset: String,
              to targetAsset: String,
              amountCall: [SwapVariant: SwapAmount],
              type: [[String?]], filter: UInt) throws -> RuntimeCall<SwapCall> {
        let filterMode = FilterMode.allCases[Int(filter)].rawValue
        let call = SwapCall(dexId: "0",
                            inputAssetId: AssetId(wrappedValue:asset),
                            outputAssetId: AssetId(wrappedValue:targetAsset),
                            amount: amountCall,
                            liquiditySourceType: type,
                            filterMode: FilterModeType(wrappedName: filterMode, wrappedValue: filter))
        return RuntimeCall<SwapCall>.swap(call)
    }
    
    func register(dexId: String, baseAssetId: String, targetAssetId: String) throws -> RuntimeCall<PairRegisterCall> {
        let call = PairRegisterCall(dexId: dexId, baseAssetId: AssetId(wrappedValue:baseAssetId), targetAssetId: AssetId(wrappedValue:targetAssetId))
        return RuntimeCall<PairRegisterCall>.register(call)
    }
    
    func initializePool(dexId: String, baseAssetId: String, targetAssetId: String) throws -> RuntimeCall<InitializePoolCall> {
        let call = InitializePoolCall(dexId: dexId, assetA: AssetId.init(wrappedValue: baseAssetId), assetB: AssetId(wrappedValue: targetAssetId))
        return RuntimeCall<InitializePoolCall>.initializePool(call)
    }
    
    func depositLiquidity(
        dexId: String,
        assetA: String,
        assetB: String,
        desiredA: BigUInt,
        desiredB: BigUInt,
        minA: BigUInt,
        minB: BigUInt
    ) throws -> RuntimeCall<DepositLiquidityCall> {
        let call = DepositLiquidityCall(
            dexId: dexId,
            assetA: AssetId.init(wrappedValue: assetA),
            assetB: AssetId.init(wrappedValue: assetB),
            desiredA: desiredA,
            desiredB: desiredB,
            minA: minA,
            minB: minB
        )
        return RuntimeCall<DepositLiquidityCall>.depositLiquidity(call)
    }
    
    func withdrawLiquidityCall(
        dexId: String,
        assetA: String,
        assetB: String,
        assetDesired: BigUInt,
        minA: BigUInt,
        minB: BigUInt
    ) throws -> RuntimeCall<WithdrawLiquidityCall> {
        let call = WithdrawLiquidityCall(
            dexId: dexId,
            assetA: AssetId.init(wrappedValue: assetA),
            assetB: AssetId.init(wrappedValue: assetB),
            assetDesired: assetDesired,
            minA: minA,
            minB: minB
        )
        return RuntimeCall<WithdrawLiquidityCall>.withdrawLiquidity(call)
    }

    func setReferrer(referrer: String) throws -> RuntimeCall<SetReferrerCall> {
        let referrerData = try Data(hexString: referrer)
        let call = SetReferrerCall(referrer: MultiAddress.accoundId(referrerData))
        return RuntimeCall<SetReferrerCall>.setReferrer(call)
    }

    func reserveReferralBalance(balance: BigUInt) throws -> RuntimeCall<ReferralBalanceCall> {
        let call = ReferralBalanceCall(balance: balance)
        return RuntimeCall<ReferralBalanceCall>.reserveReferralBalance(call)
    }

    func unreserveReferralBalance(balance: BigUInt) throws -> RuntimeCall<ReferralBalanceCall> {
        let call = ReferralBalanceCall(balance: balance)
        return RuntimeCall<ReferralBalanceCall>.unreserveReferralBalance(call)
    }
}
