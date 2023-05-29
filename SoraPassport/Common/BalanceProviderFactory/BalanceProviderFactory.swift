import Foundation
import RobinHood
import CommonWallet

class BalanceProviderFactory {

    static let executionQueue: OperationQueue = OperationQueue()
    static let balanceSyncQueue = DispatchQueue(label: "co.jp.soramitsu.wallet.cache.balance.queue")
    static let contactsSyncQueue = DispatchQueue(label: "co.jp.soramitsu.wallet.cache.contact.queue")

    let accountId: String
    let networkOperationFactory: WalletNetworkOperationFactoryProtocol
    let identifierFactory: SingleProviderIdentifierFactoryProtocol
    let cacheFacade: CoreDataCacheFacadeProtocol

    init(accountId: String,
         cacheFacade: CoreDataCacheFacadeProtocol,
         networkOperationFactory: WalletNetworkOperationFactoryProtocol,
         identifierFactory: SingleProviderIdentifierFactoryProtocol) {
        self.accountId = accountId
        self.cacheFacade = cacheFacade
        self.networkOperationFactory = networkOperationFactory
        self.identifierFactory = identifierFactory
    }

    public func createBalanceDataProvider(for assets: [AssetInfo], onlyVisible: Bool) throws -> SingleValueProvider<[BalanceData]> {
        let source: AnySingleValueProviderSource<[BalanceData]> = AnySingleValueProviderSource {
            let assets = assets.map { $0.assetId }
            let operation = (self.networkOperationFactory as? WalletNetworkFacade)?.fetchBalanceOperation(assets, onlyVisible: onlyVisible)
            return operation!
        }

        let updateTrigger = DataProviderEventTrigger.onAddObserver

        let targetId = identifierFactory.balanceIdentifierForAccountId(accountId)

        let cache = createSingleValueCache()

        return SingleValueProvider(targetIdentifier: targetId,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: updateTrigger,
                                   executionQueue: BalanceProviderFactory.executionQueue,
                                   serialSyncQueue: BalanceProviderFactory.balanceSyncQueue)
    }
    
    func createContactsDataProvider() throws -> SingleValueProvider<[SearchData]> {
        let source: AnySingleValueProviderSource<[SearchData]> = AnySingleValueProviderSource {
            let operation = self.networkOperationFactory.contactsOperation()
            return operation
        }
        
        let cache = createSingleValueCache()
        
        let updateTrigger = DataProviderEventTrigger.onAddObserver

        let targetId = identifierFactory.contactsIdentifierForAccountId(accountId)

        return SingleValueProvider(targetIdentifier: targetId,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: updateTrigger,
                                   executionQueue: BalanceProviderFactory.executionQueue,
                                   serialSyncQueue: BalanceProviderFactory.contactsSyncQueue)
    }
    

    private func createSingleValueCache()
        -> CoreDataRepository<SingleValueProviderObject, CDCWSingleValue> {
            return cacheFacade.createCoreDataCache(filter: nil)
    }
}
