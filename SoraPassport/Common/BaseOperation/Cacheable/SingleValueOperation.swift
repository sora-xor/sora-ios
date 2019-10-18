import Foundation
import RobinHood
import CoreData

final class SingleValueOperation<T: Codable & Equatable, U: NSManagedObject>: BaseOperation<T> {
    let provider: SingleValueProvider<T, U>

    init(provider: SingleValueProvider<T, U>) {
        self.provider = provider

        super.init()
    }

    override func main() {
         super.main()

        var optionalResultError: Error?
        var optionalResultData: T?

        let semaphore = DispatchSemaphore(value: 0)

        let updateBlock: ([DataProviderChange<T>]) -> Void = { changes in
            if let change = changes.first {
                switch change {
                case .insert(let item), .update(let item):
                    optionalResultData = item
                    semaphore.signal()
                case .delete:
                    break
                }
            }
        }

        let failureBlock: (Error) -> Void = { error in
            optionalResultError = error

            semaphore.signal()
        }

        provider.addCacheObserver(self,
                                  deliverOn: nil,
                                  executing: updateBlock,
                                  failing: failureBlock,
                                  options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true))
        provider.refreshCache()

        semaphore.wait()

        provider.removeCacheObserver(self)

        if let resultError = optionalResultError {
            result = .error(resultError)
            return
        }

        guard let resultData = optionalResultData else {
            result = .error(NetworkBaseError.unexpectedResponseObject)
            return
        }

        result = .success(resultData)
    }
}
