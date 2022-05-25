import Foundation
@testable import SoraPassport
import CommonWallet
import RobinHood

final class WalletNetworkOperationFactoryProtocolMock: WalletNetworkOperationFactoryProtocol/*, WalletRemoteHistoryOperationFactoryProtocol*/ {
    func getPoolsDetails() throws -> CompoundOperationWrapper<[PoolDetails]> {
        .init(targetOperation: .init())
    }
    
    func accountPools(accountId: Data) throws -> JSONRPCListOperation<JSONScaleDecodable<AccountPools>> {
        .init(engine: WebSocketEngine(url: .init(string: "")!, logger: Logger.shared), method: "")
    }

    var balanceClosure: (([String]) -> CompoundOperationWrapper<[BalanceData]?>)?

    var historyClosure: ((WalletHistoryRequest, Pagination)
    -> CompoundOperationWrapper<AssetTransactionPageData?>)?

    var transferMetadataClosure: ((TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?>)?

    var transferClosure: ((TransferInfo) -> CompoundOperationWrapper<Data>)?

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
