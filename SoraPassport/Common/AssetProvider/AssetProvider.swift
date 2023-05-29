import Foundation

import RobinHood
import CommonWallet

protocol AssetProviderObserverProtocol: AnyObject {
    func processBalance(data: [BalanceData])
}


protocol AssetProviderProtocol: AnyObject {
    func getBalances(with assetIds: [String]) -> [BalanceData]
    func add(observer: AssetProviderObserverProtocol)
    func remove(observer: AssetProviderObserverProtocol)
}

struct AssetProviderObserver {
    weak var observer: AssetProviderObserverProtocol?
}

final class AssetProvider {
    private var balanceData: [BalanceData] = []
    private let balanceProvider: SingleValueProvider<[BalanceData]>?
    private var observers: [AssetProviderObserver] = []
    private let syncQueue = DispatchQueue(label: "co.jp.soramitsu.sora.balance.provider")
    
    init(assetManager: AssetManagerProtocol, providerFactory: BalanceProviderFactory) {
        balanceProvider = try? providerFactory.createBalanceDataProvider(for: assetManager.getAssetList() ?? [], onlyVisible: false)
        setupBalanceDataProvider()
        EventCenter.shared.add(observer: self)
    }
    
    func setupBalanceDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            guard let change = changes.first else { return }
            switch change {
            case .insert(let items), .update(let items):
                self?.balanceData = items
                self?.notify()
            default:
                break
            }
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        balanceProvider?.addObserver(self,
                                    deliverOn: .main,
                                    executing: changesBlock,
                                    failing: { (error: Error) in },
                                    options: options)
    }
}

extension AssetProvider: AssetProviderProtocol {
    func getBalances(with assetIds: [String]) -> [BalanceData] {
        return balanceData.filter { assetIds.contains($0.identifier) }
    }
    
    func add(observer: AssetProviderObserverProtocol) {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            if !self.observers.contains(where: { $0.observer === observer }) {
                self.observers.append(AssetProviderObserver(observer: observer))
                self.notify()
            }
        }
    }

    func remove(observer: AssetProviderObserverProtocol) {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil && $0.observer !== observer }
        }
    }
    
    func notify() {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            for wrapper in self.observers {
                guard let observer = wrapper.observer else {
                    continue
                }

                observer.processBalance(data: self.balanceData)
            }
        }
    }
}

extension AssetProvider: EventVisitorProtocol {
    func processBalanceChanged(event: WalletBalanceChanged) {
        balanceProvider?.refresh()
    }
}
