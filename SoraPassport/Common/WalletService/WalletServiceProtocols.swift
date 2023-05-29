import Foundation
import RobinHood
import CommonWallet

typealias BalanceCompletionBlock = (Result<[BalanceData]?, Error>?) -> Void
typealias TransactionHistoryBlock = (Result<AssetTransactionPageData?, Error>?) -> Void
typealias EmptyResultCompletionBlock = (Result<Void, Error>?) -> Void
typealias DataResultCompletionBlock = (Result<Data, Error>?) -> Void
typealias SearchCompletionBlock = (Result<[SearchData]?, Error>?) -> Void
typealias WithdrawalMetadataCompletionBlock = (Result<WithdrawMetaData?, Error>?) -> Void
typealias TransferMetadataCompletionBlock = (Result<TransferMetaData?, Error>?) -> Void

protocol WalletServiceProtocol {
    
    @discardableResult
    func fetchBalance(for assets: [String],
                      runCompletionIn queue: DispatchQueue,
                      completionBlock: @escaping BalanceCompletionBlock) -> CancellableCall

    @discardableResult
    func fetchTransactionHistory(for filter: WalletHistoryRequest,
                                 pagination: Pagination,
                                 runCompletionIn queue: DispatchQueue,
                                 completionBlock: @escaping TransactionHistoryBlock) -> CancellableCall

    @discardableResult
    func fetchTransferMetadata(for info: TransferMetadataInfo,
                               runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping TransferMetadataCompletionBlock)
        -> CancellableCall

    @discardableResult
    func transfer(info: TransferInfo,
                  runCompletionIn queue: DispatchQueue,
                  completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall

    @discardableResult
    func search(for searchString: String,
                runCompletionIn queue: DispatchQueue,
                completionBlock: @escaping SearchCompletionBlock) -> CancellableCall
    
    @discardableResult
    func fetchContacts(runCompletionIn queue: DispatchQueue,
                       completionBlock: @escaping SearchCompletionBlock) -> CancellableCall

    @discardableResult
    func fetchWithdrawalMetadata(for info: WithdrawMetadataInfo,
                                 runCompletionIn queue: DispatchQueue,
                                 completionBlock: @escaping WithdrawalMetadataCompletionBlock)
        -> CancellableCall

    @discardableResult
    func withdraw(info: WithdrawInfo,
                  runCompletionIn queue: DispatchQueue,
                  completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall
}
