// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import BigInt
import RobinHood
import SSFUtils

protocol LPFeeServiceProtocol {
    func getLpfee(with dexId: UInt32) -> String
}

struct LPFee: ScaleDecodable {
    let inner: Balance

    init(scaleDecoder: ScaleDecoding) throws {
        inner = try Balance(scaleDecoder: scaleDecoder)
    }
}

struct LPFeeData: Decodable {
    let inner: String
}

final class LPFeeService {
    let operationManager = OperationManager()
    let engine: JSONRPCEngine = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())!
    let runtime = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())!
    var xorFee = String(0.3)
    var xstFee = ""
    
    init() {
        updateLpFeePercentage()
    }
    
    private func updateLpFeePercentage() {
        guard let operation = createLpFeePercentOperation() else { return }
        operation.completionBlock = { [weak self] in
            guard let data = try? operation.extractNoCancellableResultData().underlyingValue else {
                self?.getDefaultLpFee()
                return
            }
            self?.xstFee = Decimal.fromSubstrateAmount(data.inner.value, precision: 16)?.stringWithPointSeparator ?? ""
        }
        operationManager.enqueue(operations: [operation], in: .transient)
    }
    
    private func createLpFeePercentOperation() -> JSONRPCListOperation<JSONScaleDecodable<LPFee>>? {
        guard let parameters = try? StorageKeyFactory().xstPoolBaseFee().toHex(includePrefix: true) else { return nil }
        return JSONRPCListOperation<JSONScaleDecodable<LPFee>>(engine: engine, method: RPCMethod.getStorage, parameters: [ parameters ])
    }
    
    private func getDefaultLpFee() {
        let codingFactoryOperation = runtime.fetchCoderFactoryOperation()
        codingFactoryOperation.completionBlock = { [weak self] in
            guard let self = self, let codingFactory = try? codingFactoryOperation.extractNoCancellableResultData() else { return }
            let operation = self.createFallbackLpFeeOperation(with: codingFactory)
            self.operationManager.enqueue(operations: [operation], in: .transient)
        }
        operationManager.enqueue(operations: [codingFactoryOperation], in: .transient)
    }
    
    private func createFallbackLpFeeOperation(with codingFactory: RuntimeCoderFactoryProtocol) -> StorageFallbackDecodingOperation<LPFeeData> {
        let operation = StorageFallbackDecodingOperation<LPFeeData>(path: .xstPoolFee)
        operation.codingFactory = codingFactory
        operation.completionBlock = { [weak self] in
            guard let data = try? operation.extractResultData()??.inner, let fee = BigUInt(data) else { return }
            self?.xstFee = Decimal.fromSubstrateAmount(fee, precision: 16)?.stringWithPointSeparator ?? ""
        }
        return operation
    }
}

extension LPFeeService: LPFeeServiceProtocol {
    func getLpfee(with dexId: UInt32) -> String {
        return dexId == 0 ? xorFee : xstFee
    }
}
