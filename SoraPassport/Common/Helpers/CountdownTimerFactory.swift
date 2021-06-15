import Foundation
import SoraFoundation

enum TimerNotificationInterval: TimeInterval {
    case second = 1.0
    case minute = 60.0
}

protocol CountdownFactoryProtocol {
    func createTimer(with delegate: CountdownTimerDelegate,
                     notificationInterval: TimeInterval) -> CountdownTimerProtocol
}

extension CountdownFactoryProtocol {
    func createTimer(with delegate: CountdownTimerDelegate) -> CountdownTimerProtocol {
        return createTimer(with: delegate,
                           notificationInterval: TimerNotificationInterval.second.rawValue)
    }
}

struct CountdownTimerFactory: CountdownFactoryProtocol {
    func createTimer(with delegate: CountdownTimerDelegate,
                     notificationInterval: TimeInterval) -> CountdownTimerProtocol {
        return CountdownTimer(delegate: delegate,
                              applicationHander: ApplicationHandler(),
                              notificationInterval: notificationInterval)
    }
}
