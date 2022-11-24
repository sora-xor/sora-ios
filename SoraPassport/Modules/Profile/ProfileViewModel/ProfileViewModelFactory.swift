/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation
import SoraKeystore

protocol ProfileViewModelFactoryProtocol: AnyObject {
    var biometryIsOn: Bool { get set }
    var biometryAction: ((Bool) -> Void)? { get set }
    func createOptionsViewModels(locale: Locale, nodeName: String, language: Language?, username: String, address: String, isNeedPassphase: Bool) -> [ProfileOptionsHeaderViewModelProtocol]
}

final class ProfileViewModelFactory: ProfileViewModelFactoryProtocol {

    var biometryIsOn: Bool = false
    var biometryAction: ((Bool) -> Void)?
    
    func createOptionsViewModels(locale: Locale, nodeName: String, language: Language?, username: String, address: String, isNeedPassphase: Bool) -> [ProfileOptionsHeaderViewModelProtocol] {
        let profileHeaderOptions = ProfileOptionsHeader.allCases.map { (optionsHeader) ->
            ProfileOptionsHeaderViewModel in

            var options = isNeedPassphase ? optionsHeader.options : optionsHeader.options.filter { $0 != .passphrase }

            let profileOptionViewModel = options.map { (option) -> ProfileOptionViewModelProtocol in
                return createOptionViewModel(by: option, nodeName: nodeName, locale: locale, username: username, address: address)
            }
            let profileOptionsHeader = ProfileOptionsHeaderViewModel(by: optionsHeader.title(for: locale), options: profileOptionViewModel)
            return profileOptionsHeader
        }

        return profileHeaderOptions
    }

    private func createOptionViewModel(by option: ProfileOption, nodeName: String, locale: Locale, username: String, address: String)  -> ProfileOptionViewModelProtocol {
        ProfileOptionViewModel.locale = locale
        ProfileNodeOptionViewModel.locale = locale
        switch option {
        case .account:      return ProfileOptionViewModel(by: option, accessoryTitle: address)
        case .accountName:  return ProfileOptionViewModel(by: option, accessoryTitle: username)
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
        case .nodes:        return ProfileNodeOptionViewModel(by: option, curentNodeName: nodeName)
        }
    }
}
