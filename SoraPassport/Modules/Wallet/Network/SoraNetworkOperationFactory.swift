import Foundation
import CommonWallet
import RobinHood
import IrohaCommunication

private struct Constants {
    static let queryEncoding = CharacterSet.urlQueryAllowed
        .subtracting(CharacterSet(charactersIn: "+"))
}

enum SoranetFeeId: String {
    case transfer = "soranetTransferFeeId"
    case withdraw = "soranetWithdrawFeeId"
}

protocol WalletAsyncOperationFactoryProtocol {
    func transferOperation(_ infoClosure: @escaping () throws -> TransferInfo)
        -> CompoundOperationWrapper<Data>
}

final class SoraNetworkOperationFactory: MiddlewareOperationFactoryProtocol, WalletAsyncOperationFactoryProtocol {
    let accountSettings: WalletAccountSettingsProtocol
    let networkResolver: MiddlewareNetworkResolverProtocol
    let operationSettings: MiddlewareOperationSettingsProtocol

    private(set) lazy var encoder: JSONEncoder = JSONEncoder()
    private(set) lazy var decoder: JSONDecoder = JSONDecoder()

    init(accountSettings: WalletAccountSettingsProtocol,
         operationSettings: MiddlewareOperationSettingsProtocol,
         networkResolver: MiddlewareNetworkResolverProtocol) {
        self.accountSettings = accountSettings
        self.operationSettings = operationSettings
        self.networkResolver = networkResolver
    }

    func transferMetadataOperation(_ info: TransferMetadataInfo)
        -> CompoundOperationWrapper<TransferMetaData?> {
        let urlTemplate = networkResolver.urlTemplate(for: .transferMetadata)

        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate)
                .withUrlEncoding(allowedCharset: Constants.queryEncoding)
                .buildParameterURL(info.assetId)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<TransferMetaData?> { data in
            let resultData = try self.decoder.decode(MultifieldResultData<WalletTransferMetadata>.self,
                                                     from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            let feeDescription = FeeDescription(identifier: SoranetFeeId.transfer.rawValue,
                                                assetId: info.assetId,
                                                type: resultData.result.feeType,
                                                parameters: [resultData.result.feeRate])

            return TransferMetaData(feeDescriptions: [feeDescription])
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = networkResolver.adapter(for: .transferMetadata)

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        transferOperation { info }
    }

    func transferOperation(_ infoClosure: @escaping () throws -> TransferInfo)
        -> CompoundOperationWrapper<Data> {
        let urlTemplate = networkResolver.urlTemplate(for: .transfer)


        let transferOperation = ClosureOperation<IRTransaction> {
            let info = try infoClosure()
            return try self.createTransferTransaction(info)
        }

        let requestFactory = BlockNetworkRequestFactory {

            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            let transaction = try transferOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let transactionData = try IRSerializationFactory.serializeTransaction(transaction)
            let transactionInfo = TransactionInfo(transaction: transactionData)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try self.encoder.encode(transactionInfo)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Data> { (data) in
            let resultData = try self.decoder.decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            let transaction = try transferOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return try transaction.transactionHash()
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = networkResolver.adapter(for: .transfer)

        operation.addDependency(transferOperation)

        return CompoundOperationWrapper(targetOperation: operation, dependencies: [transferOperation])
    }

    func withdrawalMetadataOperation(_ info: WithdrawMetadataInfo)
        -> CompoundOperationWrapper<WithdrawMetaData?> {
        let urlTemplate = networkResolver.urlTemplate(for: .withdrawalMetadata)

        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate)
                .withUrlEncoding(allowedCharset: Constants.queryEncoding)
                .buildURL(with: info)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<WithdrawMetaData?> { data in
            let resultData = try self.decoder.decode(MultifieldResultData<WalletWithdrawMetadata>.self,
                                                     from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            let feeDescription = FeeDescription(identifier: SoranetFeeId.withdraw.rawValue,
                                                assetId: info.assetId,
                                                type: resultData.result.feeType,
                                                parameters: [resultData.result.feeRate])

            return WithdrawMetaData(providerAccountId: resultData.result.providerAccountId,
                                    feeDescriptions: [feeDescription])
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = networkResolver.adapter(for: .withdrawalMetadata)

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        let urlTemplate = networkResolver.urlTemplate(for: .withdraw)

        let transactionOperation = ClosureOperation {
            try self.createWithdrawTransaction(info)
        }

        let requestFactory = BlockNetworkRequestFactory {

            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            let transaction = try transactionOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let transactionData = try IRSerializationFactory.serializeTransaction(transaction)
            let transactionInfo = TransactionInfo(transaction: transactionData)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try self.encoder.encode(transactionInfo)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Data> { data in
            let resultData = try self.decoder.decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            let transaction = try transactionOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return try transaction.transactionHash()
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = networkResolver.adapter(for: .withdraw)

        operation.addDependency(transactionOperation)

        return CompoundOperationWrapper(targetOperation: operation,
                                        dependencies: [transactionOperation])
    }

    // MARK: Private

    private func createTransferTransaction(_ info: TransferInfo) throws -> IRTransaction {
        let amount = try IRAmountFactory.transferAmount(from: info.amount.stringValue)
        let creator = try IRAccountIdFactory.account(withIdentifier: self.accountSettings.accountId)
        let source = try IRAccountIdFactory.account(withIdentifier: info.source)
        let destination = try IRAccountIdFactory.account(withIdentifier: info.destination)
        let asset = try IRAssetIdFactory.asset(withIdentifier: info.asset)

        var transactionBuilder = IRTransactionBuilder(creatorAccountId: creator)
            .transferAsset(source,
                           destinationAccount: destination,
                           assetId: asset,
                           description: info.details,
                           amount: amount)

        if let feeValue = info.fees.first, feeValue.value.decimalValue > 0.0 {
            let fee = try IRAmountFactory.transferAmount(from: feeValue.value.stringValue)
            transactionBuilder = transactionBuilder.subtractAssetQuantity(asset,
                                                                          amount: fee)
        }

        return try transactionBuilder.withQuorum(self.operationSettings.transactionQuorum)
            .build().signed(withSignatories: [self.operationSettings.signer],
                            signatoryPublicKeys: [self.operationSettings.publicKey])
    }

    private func createWithdrawTransaction(_ info: WithdrawInfo) throws -> IRTransaction {
        let amount = try IRAmountFactory.transferAmount(from: info.amount.stringValue)
        let creator = try IRAccountIdFactory.account(withIdentifier: self.accountSettings.accountId)
        let destination = try IRAccountIdFactory.account(withIdentifier: info.destinationAccountId)
        let asset = try IRAssetIdFactory.asset(withIdentifier: info.assetId)

        var transactionBuilder = IRTransactionBuilder(creatorAccountId: creator)
            .transferAsset(creator,
                           destinationAccount: destination,
                           assetId: asset,
                           description: info.details,
                           amount: amount)

        if let feeValue = info.fees.first, feeValue.value.decimalValue > 0.0 {
            let fee = try IRAmountFactory.transferAmount(from: feeValue.value.stringValue)
            transactionBuilder = transactionBuilder.subtractAssetQuantity(asset,
                                                                          amount: fee)
        }

        return try transactionBuilder.withQuorum(self.operationSettings.transactionQuorum)
            .build().signed(withSignatories: [self.operationSettings.signer],
                            signatoryPublicKeys: [self.operationSettings.publicKey])
    }
}
