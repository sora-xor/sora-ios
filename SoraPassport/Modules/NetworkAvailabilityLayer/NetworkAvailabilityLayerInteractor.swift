import UIKit

final class NetworkAvailabilityLayerInteractor: NSObject {
    private struct Constants {
        static let reachabilityDelay: TimeInterval = 2.5
    }

    var presenter: NetworkAvailabilityLayerInteractorOutputProtocol!

    let reachabilityManager: ReachabilityManagerProtocol

    var logger: LoggerProtocol?

    private var pendingReachabilityStatus: Bool?

    init(reachabilityManager: ReachabilityManagerProtocol) {
        self.reachabilityManager = reachabilityManager
    }

    deinit {
        cancelReachabilityChange()
    }

    @objc private func notifyReachabilityChange() {
        guard let pendingStatus = pendingReachabilityStatus else {
            return
        }

        pendingReachabilityStatus = nil

        if pendingStatus {
            presenter.didDecideReachableStatusPresentation()
        } else {
            presenter.didDecideUnreachableStatusPresentation()
        }
    }

    private func setNeedsChangeReachability() {
        logger?.debug("Did change reachability to \(reachabilityManager.isReachable)")

        if let pendingValue = pendingReachabilityStatus {
            if pendingValue != reachabilityManager.isReachable {
                cancelReachabilityChange()
                pendingReachabilityStatus = nil
            }
        } else {
            pendingReachabilityStatus = reachabilityManager.isReachable
            scheduleReachabilityChange()
        }
    }

    private func cancelReachabilityChange() {
        NSObject.cancelPreviousPerformRequests(withTarget: self,
                                               selector: #selector(notifyReachabilityChange),
                                               object: nil)
    }

    private func scheduleReachabilityChange() {
        perform(#selector(notifyReachabilityChange), with: nil, afterDelay: Constants.reachabilityDelay)
    }
}

extension NetworkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol {
    func setup() {
        do {
            if !reachabilityManager.isReachable {
                setNeedsChangeReachability()
            }

            try reachabilityManager.add(listener: self)
        } catch {
            logger?.error("Can't add reachability listener due to error \(error)")
        }
    }
}

extension NetworkAvailabilityLayerInteractor: ReachabilityListenerDelegate {
    func didChangeReachability(by manager: ReachabilityManagerProtocol) {
        setNeedsChangeReachability()
    }
}
