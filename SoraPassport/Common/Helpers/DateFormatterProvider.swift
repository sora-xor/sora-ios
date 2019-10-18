import Foundation

protocol DateFormatterProviderDelegate: class {
    func providerDidChangeDateFormatter(_ provider: DateFormatterProviderProtocol)
}

protocol DateFormatterProviderProtocol: class {
    var delegate: DateFormatterProviderDelegate? { get set }
    var dateFormatter: DateFormatter { get }
}

final class DateFormatterProvider: DateFormatterProviderProtocol {
    let dateFormatterFactory: DateFormatterFactoryProtocol.Type
    let dayChangeHandler: DayChangeHandlerProtocol

    private(set) var dateFormatter: DateFormatter

    weak var delegate: DateFormatterProviderDelegate?

    init(dateFormatterFactory: DateFormatterFactoryProtocol.Type,
         dayChangeHandler: DayChangeHandlerProtocol) {
        self.dateFormatterFactory = dateFormatterFactory
        self.dayChangeHandler = dayChangeHandler

        dateFormatter = dateFormatterFactory.createDateFormatter()

        dayChangeHandler.delegate = self
    }
}

extension DateFormatterProvider: DayChangeHandlerDelegate {
    func handlerDidReceiveChange(_ handler: DayChangeHandlerProtocol) {
        dateFormatter = dateFormatterFactory.createDateFormatter()

        delegate?.providerDidChangeDateFormatter(self)
    }
}
