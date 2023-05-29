import Foundation
import RobinHood
import SoraKeystore
import CommonWallet
import IrohaCrypto


extension WalletNetworkFacade {
    
    func createLiquidityPairIfNeeded(_ info: TransferInfo) throws -> BaseOperation<String>? {

        let dexId = info.context?[TransactionContextKeys.dex] ?? "0"
        let assetIdA: String = info.source
        let assetIdB: String = info.destination

        let operationQueue = OperationQueue()

        // poolProperties
        let poolPropertiesOperation = try self.polkaswapNetworkOperationFactory.poolProperties(
            baseAsset: assetIdA,
            targetAsset: assetIdB
        )
        operationQueue.addOperations([poolPropertiesOperation], waitUntilFinished: true)

        let poolProperties = try poolPropertiesOperation.extractResultData()?.underlyingValue

        let poolIsPresentAndInitialized = poolProperties != nil
        
        guard !poolIsPresentAndInitialized else {
            return nil
        }

        // isPairEnabled
        let isPairEnabledOperation = self.polkaswapNetworkOperationFactory.isPairEnabled(
            dexId: UInt32(dexId) ?? 0,
            assetId: assetIdA,
            tokenAddress: assetIdB
        )
        operationQueue.addOperations([isPairEnabledOperation], waitUntilFinished: true)

        let isPairEnabled = try isPairEnabledOperation.extractResultData() ?? false
        
        let extrinsicClosure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let registerCall = try callFactory.register(dexId: dexId, baseAssetId: assetIdA, targetAssetId: assetIdB)
            let initializeCall = try callFactory.initializePool(dexId: dexId, baseAssetId: assetIdA, targetAssetId: assetIdB)

            if isPairEnabled {
                return try builder
                    .with(shouldUseAtomicBatch: true)
                    .adding(call: initializeCall)
            } else {
                return try builder
                    .with(shouldUseAtomicBatch: true)
                    .adding(call: registerCall)
                    .adding(call: initializeCall)
            }
        }

        guard let operation = (self.nodeOperationFactory as? WalletNetworkOperationFactory)?
            .createExtrinsicServiceOperation(closure: extrinsicClosure)
        else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }

        return operation
    }
}
