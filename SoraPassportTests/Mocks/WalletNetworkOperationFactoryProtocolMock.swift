import Foundation
@testable import SoraPassport

import RobinHood
import SSFUtils

final class WalletNetworkOperationFactoryProtocolMock: WalletNetworkOperationFactoryProtocol/*, WalletRemoteHistoryOperationFactoryProtocol*/ {
    func getPoolsDetails() throws -> CompoundOperationWrapper<[PoolDetails]> {
        .init(targetOperation: .init())
    }
    
    func accountPools(accountId: Data) throws -> JSONRPCListOperation<JSONScaleDecodable<AccountPools>> {
        .init(engine: WebSocketEngine(connectionName: nil, url: .init(string: "")!, logger: Logger.shared), method: "")
    }

    var balanceClosure: (([String]) -> CompoundOperationWrapper<[BalanceData]?>)?

    var historyClosure: ((WalletHistoryRequest, Pagination)
    -> CompoundOperationWrapper<AssetTransactionPageData?>)?

    var transferMetadataClosure: ((TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?>)?

    var transferClosure: ((TransferInfo) -> CompoundOperationWrapper<Data>)?

    var transferFeeClosure: ((TransferInfo) async throws -> Decimal)?

    var prepareTransferClosure: ((TransferInfo, () throws -> Void) async throws
        -> PreparedSora2TransferSubmission)?

    var submitPreparedTransferClosure: ((PreparedSora2TransferSubmission, TransferInfo, () throws -> Void) async throws
        -> Data)?

    var liquidityFeeClosure: ((TransferInfo) async throws -> Decimal)?

    var prepareLiquidityClosure: ((TransferInfo, () throws -> Void) async throws
        -> PreparedLiquiditySubmission)?

    var submitPreparedLiquidityClosure: ((PreparedLiquiditySubmission, TransferInfo, () throws -> Void) async throws
        -> Data)?

    var searchClosure: ((String) -> CompoundOperationWrapper<[SearchData]?>)?

    var contactsClosure: (() -> CompoundOperationWrapper<[SearchData]?>)?

    var withdrawMetadataClosure: ((WithdrawMetadataInfo) -> CompoundOperationWrapper<WithdrawMetaData?>)?

    var withdrawClosure: ((WithdrawInfo) -> CompoundOperationWrapper<Data>)?

//    var remoteHistoryClosure: ((OffsetPagination) -> CompoundOperationWrapper<MiddlewareTransactionPageData>)?

    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        if let closure = balanceClosure {
            return closure(assets)
        } else {
            let operation = ClosureOperation<[BalanceData]?> { nil }
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func fetchBalanceOperation(_ assets: [String], onlyVisible: Bool) -> CompoundOperationWrapper<[BalanceData]?> {
        if let closure = balanceClosure {
            return closure(assets)
        } else {
            let operation = ClosureOperation<[BalanceData]?> { nil }
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func fetchTransactionHistoryOperation(_ filter: WalletHistoryRequest,
                                          pagination: Pagination)
        -> CompoundOperationWrapper<AssetTransactionPageData?> {
        if let closure = historyClosure {
            return closure(filter, pagination)
        } else {
            let operation = ClosureOperation<AssetTransactionPageData?> { nil }
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func transferMetadataOperation(_ info: TransferMetadataInfo)
        -> CompoundOperationWrapper<TransferMetaData?> {
        if let closure = transferMetadataClosure {
            return closure(info)
        } else {
            let operation = ClosureOperation<TransferMetaData?> { nil }
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        if let closure = transferClosure {
            return closure(info)
        } else {
            let operation = ClosureOperation<Data> { Data() }
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func estimateTransferFee(for info: TransferInfo) async throws -> Decimal {
        guard let transferFeeClosure else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        return try await transferFeeClosure(info)
    }

    func prepareTransferSubmission(
        for info: TransferInfo,
        preSigningValidation: @escaping () throws -> Void
    ) async throws -> PreparedSora2TransferSubmission {
        guard let prepareTransferClosure else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        return try await prepareTransferClosure(info, preSigningValidation)
    }

    func submitPreparedTransfer(
        _ submission: PreparedSora2TransferSubmission,
        info: TransferInfo,
        preTransportValidation: @escaping () throws -> Void
    ) async throws -> Data {
        guard let submitPreparedTransferClosure else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        return try await submitPreparedTransferClosure(
            submission,
            info,
            preTransportValidation
        )
    }

    func estimateLiquidityFee(for info: TransferInfo) async throws -> Decimal {
        guard let liquidityFeeClosure else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        return try await liquidityFeeClosure(info)
    }

    func prepareLiquiditySubmission(
        for info: TransferInfo,
        preSigningValidation: @escaping () throws -> Void
    ) async throws -> PreparedLiquiditySubmission {
        guard let prepareLiquidityClosure else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        return try await prepareLiquidityClosure(info, preSigningValidation)
    }

    func submitPreparedLiquidity(
        _ submission: PreparedLiquiditySubmission,
        info: TransferInfo,
        preTransportValidation: @escaping () throws -> Void
    ) async throws -> Data {
        guard let submitPreparedLiquidityClosure else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        return try await submitPreparedLiquidityClosure(
            submission,
            info,
            preTransportValidation
        )
    }

    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?> {
        if let closure = searchClosure {
            return closure(searchString)
        } else {
            let operation = ClosureOperation<[SearchData]?> { nil }
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        if let closure = contactsClosure {
            return closure()
        } else {
            let operation = ClosureOperation<[SearchData]?> { nil }
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func withdrawalMetadataOperation(_ info: WithdrawMetadataInfo) -> CompoundOperationWrapper<WithdrawMetaData?> {
        if let closure = withdrawMetadataClosure {
            return closure(info)
        } else {
            let operation = ClosureOperation<WithdrawMetaData?> { nil }
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        if let closure = withdrawClosure {
            return closure(info)
        } else {
            let operation = ClosureOperation<Data> { Data() }
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

//    func fetchRemoteHistoryOperationForPagination(_ pagination: OffsetPagination)
//        -> CompoundOperationWrapper<MiddlewareTransactionPageData> {
//        if let closure = remoteHistoryClosure {
//            return closure(pagination)
//        } else {
//            let page = MiddlewareTransactionPageData(transactions: [])
//            let operation = ClosureOperation<MiddlewareTransactionPageData> { page }
//            return CompoundOperationWrapper(targetOperation: operation)
//        }
//    }
}
