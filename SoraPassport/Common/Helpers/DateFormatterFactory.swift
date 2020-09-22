import Foundation
import SoraFoundation

protocol DateFormatterFactoryProtocol {
    static func createDateFormatter() -> DateFormatter
}

struct EventListDateFormatterFactory: DateFormatterFactoryProtocol {
    static func createDateFormatter() -> DateFormatter {
        let dateFormatterBuilder = CompoundDateFormatterBuilder(baseDate: Date())

        let today = LocalizableResource { locale in
            R.string.localizable.commonToday(preferredLanguages: locale.rLanguages)
        }

        let yesterday = LocalizableResource { locale in
            R.string.localizable.commonYesterday(preferredLanguages: locale.rLanguages)
        }

        let defaultFormat = R.string.localizable
            .anyYearFormat(preferredLanguages: Locale.current.rLanguages)

        let dateFormatter = dateFormatterBuilder
            .withToday(title: today)
            .withYesterday(title: yesterday)
            .withThisYear(dateFormatter: DateFormatter.sectionThisYear.localizableResource())
            .build(defaultFormat: defaultFormat)

        return dateFormatter
    }
}

struct FinishedProjectDateFormatterFactory: DateFormatterFactoryProtocol {
    static func createDateFormatter() -> DateFormatter {
        let dateFormatterBuilder = CompoundDateFormatterBuilder()

        let today = LocalizableResource { locale in
            R.string.localizable.commonToday(preferredLanguages: locale.rLanguages)
        }

        let yesterday = LocalizableResource { locale in
            R.string.localizable.commonYesterday(preferredLanguages: locale.rLanguages)
        }

        let defaultFormat = R.string.localizable
            .finishedProjectYearFormat(preferredLanguages: Locale.current.rLanguages)

        let dateFormatter = dateFormatterBuilder
            .withToday(title: today)
            .withYesterday(title: yesterday)
            .withThisYear(dateFormatter: DateFormatter.shortThisYear.localizableResource())
            .build(defaultFormat: defaultFormat)

        return dateFormatter
    }
}
