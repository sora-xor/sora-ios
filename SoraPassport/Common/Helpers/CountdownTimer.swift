/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum CountdownTimerState {
    case stopped
    case paused(atDate: Date)
    case inProgress
}

protocol CountdownTimerProtocol: class {
    func start(with interval: TimeInterval)
    func stop()
}

protocol CountdownTimerDelegate: class {
    func didStart(with interval: TimeInterval)
    func didCountdown(remainedInterval: TimeInterval)
    func didStop(with remainedInterval: TimeInterval)
}

final class CountdownTimer: NSObject {

    weak var delegate: CountdownTimerDelegate?

    private var applicationHandler: ApplicationHandlerProtocol
    private var timer: Timer?

    private(set) var state: CountdownTimerState = .stopped
    private(set) var remainedInterval: TimeInterval = 0.0

    init(delegate: CountdownTimerDelegate,
         applicationHander: ApplicationHandlerProtocol = ApplicationHandler()) {
        self.delegate = delegate
        self.applicationHandler = applicationHander

        super.init()
    }

    @objc private func actionTimer(_ sender: Timer) {
        remainedInterval -= sender.timeInterval

        if remainedInterval < TimeInterval.leastNonzeroMagnitude {
            remainedInterval = 0.0

            stop()
        } else {
            delegate?.didCountdown(remainedInterval: remainedInterval)
        }
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1.0,
                                     target: self,
                                     selector: #selector(actionTimer(_:)),
                                     userInfo: nil,
                                     repeats: true)
    }
}

extension CountdownTimer: CountdownTimerProtocol {
    func start(with interval: TimeInterval) {
        stop()

        remainedInterval = interval

        state = .inProgress

        delegate?.didStart(with: remainedInterval)

        if remainedInterval > 0 {
            applicationHandler.delegate = self

            scheduleTimer()
        } else {
            state = .stopped

            delegate?.didStop(with: remainedInterval)
        }
    }

    func stop() {
        let previousState = state

        state = .stopped

        timer?.invalidate()
        timer = nil

        let currentRemainedInterval = remainedInterval
        remainedInterval = 0

        applicationHandler.delegate = nil

        switch previousState {
        case .inProgress, .paused:
            delegate?.didStop(with: currentRemainedInterval)
        default:
            break
        }
    }
}

extension CountdownTimer: ApplicationHandlerDelegate {
    func didReceiveWillResignActive(notification: Notification) {
        if case .inProgress = state {
            state = .paused(atDate: Date())

            timer?.invalidate()
            timer = nil
        }
    }

    func didReceiveDidBecomeActive(notification: Notification) {
        if case .paused(let date) = state {
            let leftInterval = Date().timeIntervalSince(date)

            guard leftInterval >= 0 else {
                stop()
                return
            }

            if remainedInterval - leftInterval > 0.0 {
                remainedInterval -= leftInterval
                state = .inProgress

                scheduleTimer()

                if leftInterval > 0.0 {
                    delegate?.didCountdown(remainedInterval: remainedInterval)
                }

            } else {
                stop()
            }
        }
    }
}
