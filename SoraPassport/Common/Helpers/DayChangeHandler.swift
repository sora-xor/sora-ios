import Foundation

protocol DayChangeHandlerDelegate: class {
    func handlerDidReceiveChange(_ handler: DayChangeHandlerProtocol)
}

protocol DayChangeHandlerProtocol: class {
    var delegate: DayChangeHandlerDelegate? { get set }
}

final class DayChangeHandler: DayChangeHandlerProtocol {
    weak var delegate: DayChangeHandlerDelegate?

    deinit {
        removeNotificationHandlers()
    }

    init() {
        setupNotificationHandlers()
    }

    func setupNotificationHandlers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didDayChangeHandler(_:)),
                                               name: .NSCalendarDayChanged,
                                               object: nil)
    }

    func removeNotificationHandlers() {
        // swiftlint:disable:next notification_center_detachment
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Private

    @objc func didDayChangeHandler(_ notification: Notification) {
        // notification is dispatched in background thread

        DispatchQueue.main.async {
            self.delegate?.handlerDidReceiveChange(self)
        }
    }
}
