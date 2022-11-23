import UIKit

protocol AboutOptionViewModelProtocol {
    static var locale: Locale { get set }

    var option: AboutOption { get }

    var title: String { get }
    var subtitle: String? { get }
    var image: UIImage? { get }
    var address: URL? { get }
}

struct AboutOptionViewModel: AboutOptionViewModelProtocol {
    static var locale: Locale = Locale.current

    var option: AboutOption

    var title: String
    var image: UIImage?
    var address: URL?

    var subtitle: String? {
        switch option {
        case .terms, .privacy:
            return nil

        case .writeUs(let email):
            return email

        default:
            return address?.absoluteString.replacingOccurrences(of: "https://", with: "")
        }
    }

    init(by option: AboutOption) {
        self.option = option

        self.title = option.title(for: Self.locale)
        self.image = option.iconImage()
        self.address = option.address()
    }
}
