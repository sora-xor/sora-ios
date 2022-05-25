import Foundation
import SoraFoundation

protocol ProfileViewModelFactoryProtocol: class {
    var biometryIsOn: Bool { get set }
    var biometryAction: ((Bool) -> Void)? { get set }
    func createOptionViewModels(locale: Locale, language: Language?) -> [ProfileOptionViewModelProtocol]
}

final class ProfileViewModelFactory: ProfileViewModelFactoryProtocol {

    var biometryIsOn: Bool = false
    var biometryAction: ((Bool) -> Void)?

    func createOptionViewModels(locale: Locale, language: Language?) -> [ProfileOptionViewModelProtocol] {

        ProfileOptionViewModel.locale = locale

        let optionViewModels = ProfileOption.allCases.map { (option) -> ProfileOptionViewModel in
            switch option {
            case .account:      return ProfileOptionViewModel(by: option)
            case .friends:      return ProfileOptionViewModel(by: option)
            case .passphrase:   return ProfileOptionViewModel(by: option)
            case .changePin:    return ProfileOptionViewModel(by: option)
            case .biometry:     return ProfileOptionViewModel(by: option,
                                                              switchIsOn: biometryIsOn,
                                                              switchAction: biometryAction)
            case .language:     return ProfileOptionViewModel(by: option)
            case .faq:          return ProfileOptionViewModel(by: option)
            case .about:        return ProfileOptionViewModel(by: option)
            case .disclaimer:   return ProfileOptionViewModel(by: option)
            case .logout:       return ProfileOptionViewModel(by: option)
            }
        }

        return optionViewModels
    }
}
