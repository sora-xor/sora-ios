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

import RobinHood
import XNetworking

struct SubqueryKmmError: Swift.Error {
    
}

public final class SubqueryHistoryOperation<ResultType>: BaseOperation<ResultType> {
    
    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let subQueryClient: SubQueryClientForSoraWallet
    private let address: String
    private let count: Int
    private let page: Int
    private var filter: ((TxHistoryItem) -> KotlinBoolean)? = nil

    public init(address: String, count: Int, page: Int, filter: ((TxHistoryItem) -> KotlinBoolean)? = nil) {
        self.httpProvider = SoramitsuHttpClientProviderImpl()
        self.filter = filter
        self.soraNetworkClient = SoramitsuNetworkClient(timeout: 60000, logging: true, provider: httpProvider)
        let provider = SoraRemoteConfigProvider(client: self.soraNetworkClient,
                                                commonUrl: ApplicationConfig.shared.commonConfigUrl,
                                                mobileUrl: ApplicationConfig.shared.mobileConfigUrl)
        let configBuilder = provider.provide()

        self.subQueryClient = SubQueryClientForSoraWalletFactory().create(soramitsuNetworkClient: self.soraNetworkClient,
                                                                          pageSize: Int32(count),
                                                                          soraRemoteConfigBuilder: configBuilder)
        self.address = address
        self.count = count
        self.page = page

        super.init()
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        let semaphore = DispatchSemaphore(value: 0)

        //TODO: delete after kotlin 1.7.0 released, now we should call method from main queue
        DispatchQueue.main.async {
            self.subQueryClient.getTransactionHistoryPaged(address: self.address,
                                                           page: Int64(self.page),
                                                           filter: self.filter,
                                                           completionHandler: { [self] requestResult, error in
                if let error = error {
                    self.result = .failure(error)
                    semaphore.signal()
                    return
                }

                guard let data = requestResult as? ResultType else {
                    self.result = .failure(SubqueryKmmError())
                    semaphore.signal()
                    return
                }

                if self.isCancelled {
                    return
                }
                semaphore.signal()
                self.result = .success(data)
            })
        }

        semaphore.wait()
    }
}
