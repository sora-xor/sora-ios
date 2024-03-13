// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import RobinHood
import SoraKeystore

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
