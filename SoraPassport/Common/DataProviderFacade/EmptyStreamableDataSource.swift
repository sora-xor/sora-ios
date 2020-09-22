import Foundation
import RobinHood

final class EmptyStreamableDataSource<T: Identifiable>: StreamableSourceProtocol {
    typealias Model = T

    func fetchHistory(runningIn queue: DispatchQueue?, commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        notify(on: queue, commitNotificationBlock: commitNotificationBlock)
    }

    func refresh(runningIn queue: DispatchQueue?, commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        notify(on: queue, commitNotificationBlock: commitNotificationBlock)
    }

    // MARK: Private

    private func notify(on queue: DispatchQueue?, commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        guard let notificationBlock = commitNotificationBlock else {
            return
        }

        if let queue = queue {
            queue.async {
                notificationBlock(.success(0))
            }
        } else {
            notificationBlock(.success(0))
        }
    }
}
