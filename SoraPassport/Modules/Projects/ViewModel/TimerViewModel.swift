/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

protocol TimerViewModelProtocol: class {
    var remainedSeconds: TimeInterval { get }

    func titleForLocale(_ locale: Locale?) -> String

    func start(_ delegate: TimerViewModelDelegate)
    func stop()
}

protocol TimerViewModelDelegate: class {
    func didStart(_ viewModel: TimerViewModelProtocol)
    func didChangeRemainedTime(_ viewModel: TimerViewModelProtocol)
    func didStop(_ viewModel: TimerViewModelProtocol)
}

final class ReferendumTimerViewModel {
    static let dayRemainedInterval: TimeInterval = 24.0 * 3600.0

    var remainedSeconds: TimeInterval {
        deadline.timeIntervalSince(Date())
    }

    let timeFormatter: TimeFormatterProtocol
    let deadline: Date

    weak var delegate: TimerViewModelDelegate?

    private var timer: CountdownTimer?

    private var waitingDayRemained: Bool = false

    deinit {
        invalidateTimer()
    }

    init(deadline: Date, timeFormatter: TimeFormatterProtocol) {
        self.deadline = deadline
        self.timeFormatter = timeFormatter
    }

    private func startTimer() {
        let remainedInterval = self.remainedSeconds

        if remainedInterval > Self.dayRemainedInterval {
            waitingDayRemained = true

            timer = CountdownTimer(delegate: self,
                                   applicationHander: ApplicationHandler(),
                                   notificationInterval: remainedInterval - Self.dayRemainedInterval)
            timer?.start(with: remainedInterval - Self.dayRemainedInterval)
        } else if remainedInterval > 0.0 {
            waitingDayRemained = false

            timer = CountdownTimer(delegate: self,
                                   applicationHander: ApplicationHandler(),
                                   notificationInterval: 1.0)
            timer?.start(with: remainedInterval)
        }
    }

    private func invalidateTimer() {
        timer?.stop()
        timer = nil
    }
}

extension ReferendumTimerViewModel: TimerViewModelProtocol {
    func titleForLocale(_ locale: Locale?) -> String {
        guard remainedSeconds > 0.0 else {
            return R.string.localizable
                .referendumFinishingSoon(preferredLanguages: locale?.rLanguages)
        }

        if remainedSeconds >= Self.dayRemainedInterval {
            let days = Int(TimeInterval(remainedSeconds) / Self.dayRemainedInterval)

            return R.string.localizable.referendumDateDayPlurals(value: days,
                                                                 preferredLanguages: locale?.rLanguages)
        } else {
            return (try? timeFormatter.string(from: TimeInterval(remainedSeconds))) ?? ""
        }
    }

    func start(_ delegate: TimerViewModelDelegate) {
        invalidateTimer()

        self.delegate = delegate

        startTimer()
    }

    func stop() {
        invalidateTimer()
    }
}

extension ReferendumTimerViewModel: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        delegate?.didStart(self)
    }

    func didCountdown(remainedInterval: TimeInterval) {
        delegate?.didChangeRemainedTime(self)

        if waitingDayRemained {
            invalidateTimer()
            startTimer()
        }
    }

    func didStop(with remainedInterval: TimeInterval) {
        delegate?.didStop(self)

        if waitingDayRemained {
            invalidateTimer()
            startTimer()
        }
    }
}
