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
