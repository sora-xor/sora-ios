/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo

class CountdownTimerTests: XCTestCase {

    func testStartCountdownStopDelegateCalled() {
        // given
        let mockDelegate = MockCountdownTimerDelegate()
        let mockApplicationHandler = MockApplicationHandlerProtocol()

        let timerStartExpectation = XCTestExpectation()
        let timerStopExpectation = XCTestExpectation()
        let timerCountdownExpectation = XCTestExpectation()

        stub(mockDelegate) { stub in
            when(stub).didStart(with: any(TimeInterval.self)).then { _ in
                timerStartExpectation.fulfill()
            }

            when(stub).didCountdown(remainedInterval: any(TimeInterval.self)).then { _ in
                timerCountdownExpectation.fulfill()
            }

            when(stub).didStop(with: any(TimeInterval.self)).then { _ in
                timerStopExpectation.fulfill()
            }
        }

        stub(mockApplicationHandler) { stub in
            when(stub).delegate.get.thenReturn(nil)
            when(stub).delegate.set(any(ApplicationHandlerDelegate?.self)).thenDoNothing()
        }

        let countdownTimer = CountdownTimer(delegate: mockDelegate,
                                            applicationHander: mockApplicationHandler)

        // when
        guard case .stopped = countdownTimer.state else {
            XCTFail()
            return
        }

        let interval = 2.0
        countdownTimer.start(with: interval)

        guard case .inProgress = countdownTimer.state else {
            XCTFail()
            return
        }

        wait(for: [timerStartExpectation, timerStopExpectation, timerCountdownExpectation],
             timeout: Constants.expectationDuration)

        // then

        guard case .stopped = countdownTimer.state else {
            XCTFail()
            return
        }

        verify(mockDelegate, times(1)).didStart(with: interval)
        verify(mockDelegate, atLeast(1)).didCountdown(remainedInterval: any(TimeInterval.self))
        verify(mockDelegate, times(1)).didStop(with: 0.0)
    }

    func testPauseWhenApplicationResignsActivity() {
        // given
        let mockDelegate = MockCountdownTimerDelegate()
        let mockApplicationHandler = MockApplicationHandlerProtocol()

        let timerStartExpectation = XCTestExpectation()
        let timerStopExpectation = XCTestExpectation()
        let timerCountdownExpectation = XCTestExpectation()

        stub(mockDelegate) { stub in
            when(stub).didStart(with: any(TimeInterval.self)).then { _ in
                timerStartExpectation.fulfill()
            }

            when(stub).didCountdown(remainedInterval: any(TimeInterval.self)).then { _ in
                timerCountdownExpectation.fulfill()
            }

            when(stub).didStop(with: any(TimeInterval.self)).then { _ in
                timerStopExpectation.fulfill()
            }
        }

        stub(mockApplicationHandler) { stub in
            when(stub).delegate.get.thenReturn(nil)
            when(stub).delegate.set(any(ApplicationHandlerDelegate?.self)).thenDoNothing()
        }

        let countdownTimer = CountdownTimer(delegate: mockDelegate,
                                            applicationHander: mockApplicationHandler)

        // when

        let interval = 3.0
        countdownTimer.start(with: interval)

        XCTAssert(checkNotificationInvariant(for: countdownTimer))

        guard case .inProgress = countdownTimer.state else {
            XCTFail()
            return
        }

        sleep(1)

        countdownTimer.didReceiveWillResignActive(notification: Notification(name: UIApplication.willResignActiveNotification))

        guard case .paused = countdownTimer.state else {
            XCTFail()
            return
        }

        sleep(1)

        countdownTimer.didReceiveDidBecomeActive(notification: Notification(name: UIApplication.didBecomeActiveNotification))

        XCTAssert(checkNotificationInvariant(for: countdownTimer))

        guard case .inProgress = countdownTimer.state else {
            XCTFail()
            return
        }

        sleep(1)

        countdownTimer.stop()

        XCTAssert(checkNotificationInvariant(for: countdownTimer))

        wait(for: [timerStartExpectation, timerCountdownExpectation, timerStopExpectation], timeout: Constants.expectationDuration + interval)

        // then

        guard case .stopped = countdownTimer.state else {
            XCTFail()
            return
        }

        verify(mockDelegate, times(1)).didStart(with: interval)
        verify(mockDelegate, atLeast(1)).didCountdown(remainedInterval: any(TimeInterval.self))
        verify(mockDelegate, times(1)).didStop(with: any(TimeInterval.self))
    }

    func testNotificationIntervalProperlyHandled() {
        // given

        let mockDelegate = MockCountdownTimerDelegate()
        let mockApplicationHandler = MockApplicationHandlerProtocol()

        let timerStartExpectation = XCTestExpectation()
        let timerStopExpectation = XCTestExpectation()
        let timerCountdownExpectation = XCTestExpectation()

        stub(mockDelegate) { stub in
            when(stub).didStart(with: any(TimeInterval.self)).then { _ in
                timerStartExpectation.fulfill()
            }

            when(stub).didCountdown(remainedInterval: any(TimeInterval.self)).then { _ in
                timerCountdownExpectation.fulfill()
            }

            when(stub).didStop(with: any(TimeInterval.self)).then { _ in
                timerStopExpectation.fulfill()
            }
        }

        stub(mockApplicationHandler) { stub in
            when(stub).delegate.get.thenReturn(nil)
            when(stub).delegate.set(any(ApplicationHandlerDelegate?.self)).thenDoNothing()
        }

        let notificationInterval: TimeInterval = 2.0

        let countdownTimer = CountdownTimer(delegate: mockDelegate,
                                            applicationHander: mockApplicationHandler,
                                            notificationInterval: notificationInterval)

        // when

        let runningInterval: TimeInterval = notificationInterval + 1

        countdownTimer.start(with: runningInterval)


        wait(for: [timerStartExpectation, timerStopExpectation, timerCountdownExpectation],
             timeout: Constants.expectationDuration)

        // then

        guard case .stopped = countdownTimer.state else {
            XCTFail()
            return
        }

        verify(mockDelegate, times(1)).didStart(with: runningInterval)
        verify(mockDelegate, times(1)).didCountdown(remainedInterval: any(TimeInterval.self))
        verify(mockDelegate, times(1)).didStop(with: 0.0)

        XCTAssert(checkNotificationInvariant(for: countdownTimer))
    }

    private func checkNotificationInvariant(for timer: CountdownTimer) -> Bool {
        return timer.lastNotifiedInterval - timer.remainedInterval < timer.notificationInterval
    }
}
