/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood

protocol WalletRemoteHistoryOperationFactoryProtocol {
    func fetchRemoteHistoryOperationForPagination(_ pagination: OffsetPagination)
        -> CompoundOperationWrapper<MiddlewareTransactionPageData>
}

extension SoraNetworkOperationFactory: WalletRemoteHistoryOperationFactoryProtocol {
    func fetchRemoteHistoryOperationForPagination(_ pagination: OffsetPagination)
        -> CompoundOperationWrapper<MiddlewareTransactionPageData> {
        let urlTemplate = networkResolver.urlTemplate(for: .history)

        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate)
                .buildURL(with: pagination)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<MiddlewareTransactionPageData> { (data) in
            let resultData =
                try self.decoder.decode(OptionalMultifieldResultData<WalletRemoteHistoryPageData>.self,
                                        from: data)

            guard resultData.status.isSuccess else {
                if let errorFactory = self.networkResolver.errorFactory(for: .history) {
                    throw errorFactory.createErrorFromStatus(resultData.status.code)
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            guard let remoteItems = resultData.result?.transactions else {
                return MiddlewareTransactionPageData(transactions: [])
            }

            let transactions: [AssetTransactionData] = remoteItems.map { item in
                return AssetTransactionData(item: item, accountId: self.accountSettings.accountId)
            }

            return MiddlewareTransactionPageData(transactions: transactions)
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = networkResolver.adapter(for: .history)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
