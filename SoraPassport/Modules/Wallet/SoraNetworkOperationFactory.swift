/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood
import IrohaCommunication

final class SoraNetworkOperationFactory: IrohaOperationFactoryProtocol {

    let accountSettings: WalletAccountSettingsProtocol

    private(set) lazy var encoder: JSONEncoder = JSONEncoder()
    private(set) lazy var decoder: JSONDecoder = JSONDecoder()

    init(accountSettings: WalletAccountSettingsProtocol) {
        self.accountSettings = accountSettings
    }

    func transferOperation(_ urlTemplate: String, info: TransferInfo) -> NetworkOperation<Bool> {
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

        let resultFactory = AnyNetworkResultFactory<Bool> { (data) in
            let resultData = try self.decoder.decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            return true
        }

        return NetworkOperation(requestFactory: requestFactory,
                                resultFactory: resultFactory)
    }
}
