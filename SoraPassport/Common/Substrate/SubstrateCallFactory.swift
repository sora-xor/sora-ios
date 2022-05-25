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
        let call = SoraTransferCall(receiver: receiverAccountId,
                                    amount: amount,
                                    assetId: asset)
        return RuntimeCall<SoraTransferCall>.transfer(call)
    }

    func swap(from asset: String,
              to targetAsset: String,
              amountCall: [SwapVariant: SwapAmount],
              type: [UInt?], filter: UInt) throws -> RuntimeCall<SwapCall> {
        let call = SwapCall(dexId: "0",
                            inputAssetId: asset,
                            outputAssetId: targetAsset,
                            amount: amountCall,
                            liquiditySourceType: type,
                            filterMode: filter)
        return RuntimeCall<SwapCall>.swap(call)
    }
}
