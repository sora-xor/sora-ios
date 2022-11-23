/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import RobinHood
import XNetworking
import Foundation

public final class SubqueryReferralRewardsOperation<ResultType>: BaseOperation<ResultType> {

    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let subQueryClient: SoraWalletBlockExplorerInfo
    private let address: String
    private let baseUrl: URL
    private let count: Int

    public init(address: String, count: Int = 1000, baseUrl: URL) {
        self.baseUrl = baseUrl
        self.httpProvider = SoramitsuHttpClientProviderImpl()
        self.soraNetworkClient = SoramitsuNetworkClient(timeout: 60000, logging: true, provider: httpProvider)

        self.subQueryClient = SoraWalletBlockExplorerInfo(networkClient: self.soraNetworkClient, baseUrl: baseUrl.absoluteString)
        self.address = address
        self.count = count

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

        DispatchQueue.main.async {
            self.subQueryClient.getReferrerRewards(address: self.address,
                                                   caseName: ApplicationConfig.shared.caseName,
                                                   url: self.baseUrl.absoluteString,
                                                   completionHandler: { [self] requestResult, error in
                guard let data = requestResult as? ResultType else { return }

                if isCancelled {
                    return
                }
                semaphore.signal()

                result = .success(data)
            })
        }

        semaphore.wait()
    }
}
