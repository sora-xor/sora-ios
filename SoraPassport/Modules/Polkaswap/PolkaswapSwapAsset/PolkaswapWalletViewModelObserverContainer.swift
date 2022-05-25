import Foundation
import CommonWallet

public struct PolkaswapWalletViewModelObserverWrapper<Observer> where Observer: AnyObject {
    weak var observer: Observer?

    init(observer: Observer) {
        self.observer = observer
    }
}

public final class PolkaswapWalletViewModelObserverContainer<Observer> where Observer: AnyObject {
    private(set) var observers: [PolkaswapWalletViewModelObserverWrapper<Observer>] = []

    public func add(observer: Observer) {
        observers = observers.filter { $0.observer != nil }

        guard !observers.contains(where: { $0.observer === observer }) else {
            return
        }

        observers.append(PolkaswapWalletViewModelObserverWrapper(observer: observer))
    }

    public func remove(observer: Observer) {
        observers = observers.filter { $0.observer != nil && $0.observer !== observer }
    }
}
