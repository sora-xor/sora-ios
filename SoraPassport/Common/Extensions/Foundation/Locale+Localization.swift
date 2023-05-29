import Foundation
import SoraFoundation

extension Locale {
    var rLanguages: [String]? {
        return [identifier]
    }
}

extension Array where Element == String {
    static var currentLocale: [String]? {
        LocalizationManager.shared.selectedLocale.rLanguages
    }
}
