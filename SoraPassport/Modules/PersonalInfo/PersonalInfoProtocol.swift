/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

protocol PersonalInfoViewProtocol: LoadableViewProtocol, ControllerBackedProtocol {
    func didReceive(viewModels: [InputViewModelProtocol])
    func didReceive(footerViewModel: PersonalInfoFooterViewModel?)
    func didStartEditing(at index: Int)
}

protocol PersonalInfoPresenterProtocol: class {
    func load()
    func register()
}

protocol PersonalInfoInteractorInputProtocol: class {
    func load()
    func register(with form: PersonalForm)
}

protocol PersonalInfoInteractorOutputProtocol: class {
    func didReceive(invitationCode: String?)
    func didStartRegistration(with form: PersonalForm)
    func didCompleteRegistration(with form: PersonalForm)
    func didReceiveRegistration(error: Error)
}

protocol PersonalInfoWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showPassphraseBackup(from view: PersonalInfoViewProtocol?)
}

protocol PersonalInfoViewFactoryProtocol {
    static func createView(with form: PersonalForm) -> PersonalInfoViewProtocol?
}
