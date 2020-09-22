import Foundation
import SoraFoundation

final class PollingService: UserApplicationServiceProtocol {
    let pollables: [Pollable]
    let pollingInterval: TimeInterval
    let applicationHandler: ApplicationHandlerProtocol
    let logger: LoggerProtocol

    private var isSetup: Bool = false

    private var timer: Timer?
    private var isPolling: Bool { timer != nil }

    init(pollables: [Pollable],
         pollingInterval: TimeInterval,
         applicationHandler: ApplicationHandlerProtocol,
         logger: LoggerProtocol) {
        self.pollables = pollables
        self.pollingInterval = pollingInterval
        self.applicationHandler = applicationHandler
        self.logger = logger
    }

    func setup() {
        guard !isSetup else {
            return
        }

        isSetup = true

        applicationHandler.delegate = self

        pollables.forEach {
            $0.delegate = self
            $0.setup()
        }
    }

    func throttle() {
        guard isSetup else {
            return
        }

        isSetup = false

        applicationHandler.delegate = nil

        stopPollingIfNeeded()

        pollables.forEach {
            $0.delegate = nil
            $0.cancel()
        }
    }

    // MARK: Private

    private func startPollingIfNeeded() {
        guard timer == nil else {
            return
        }

        logger.debug("Did start polling with interval: \(pollingInterval) sec.")

        timer = Timer.scheduledTimer(timeInterval: pollingInterval,
                                     target: self,
                                     selector: #selector(poll),
                                     userInfo: nil,
                                     repeats: true)

        poll()
    }

    private func stopPollingIfNeeded() {
        guard timer != nil else {
            return
        }

        logger.debug("Did stop polling")

        timer?.invalidate()
        timer = nil
    }

    @objc private func poll() {
        logger.debug("Poll triggered")

        for pollable in pollables where pollable.state == .ready {
            pollable.poll()
        }
    }
}

extension PollingService: PollableDelegate {
    func pollableDidChangeState(_ pollable: Pollable, from oldState: PollableState) {
        guard isSetup else {
            return
        }

        if
            pollables.allSatisfy({ $0.state == .setup || $0.state == .ready }),
            pollables.contains(where: { $0.state == .ready }) {

            startPollingIfNeeded()
        } else {
            stopPollingIfNeeded()
        }
    }
}

extension PollingService: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification: Notification) {
        if isSetup {
            pollables.forEach { $0.cancel() }
        }

        if isPolling {
            stopPollingIfNeeded()
        }
    }

    func didReceiveWillEnterForeground(notification: Notification) {
        if isSetup {
            pollables.forEach { $0.setup() }
        }
    }
}
