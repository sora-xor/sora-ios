/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood
import IrohaCommunication

final class SoraNetworkOperationFactory: MiddlewareOperationFactoryProtocol {
    let accountSettings: WalletAccountSettingsProtocol
    let networkResolver: WalletNetworkResolverProtocol

    private(set) lazy var encoder: JSONEncoder = JSONEncoder()
    private(set) lazy var decoder: JSONDecoder = JSONDecoder()

    init(accountSettings: WalletAccountSettingsProtocol, networkResolver: WalletNetworkResolverProtocol) {
        self.accountSettings = accountSettings
        self.networkResolver = networkResolver
    }

    func transferOperation(_ info: TransferInfo) -> BaseOperation<Void> {
        let urlTemplate = networkResolver.urlTemplate(for: .transfer)

        let requestFactory = BlockNetworkRequestFactory {

            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var transactionBuilder = IRTransactionBuilder(creatorAccountId: self.accountSettings.accountId)
                .transferAsset(info.source,
                               destinationAccount: info.destination,
                               assetId: info.asset,
                               description: info.details,
                               amount: info.amount)

            if let fee = info.fee {
                transactionBuilder = transactionBuilder.subtractAssetQuantity(info.asset,
                                                                              amount: fee)
            }

            let transaction = try transactionBuilder.withQuorum(self.accountSettings.transactionQuorum)
                .build()
                .signed(withSignatories: [self.accountSettings.signer],
                        signatoryPublicKeys: [self.accountSettings.publicKey])

            let transactionData = try IRSerializationFactory.serializeTransaction(transaction)
            let transactionInfo = TransactionInfo(transaction: transactionData)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try self.encoder.encode(transactionInfo)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory { (data) in
            let resultData = try self.decoder.decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = networkResolver.adapter(for: .transfer)

        return operation
    }
}
