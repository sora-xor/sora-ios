import Foundation

protocol SourceType {
    func titleForLocale(_ locale: Locale) -> String
    var descriptionText: String? { get }
}
