/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol PersonalUpdateViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
	func didReceive(viewModels: [PersonalInfoViewModelProtocol])
    func didStartSaving()
    func didCompleteSaving(success: Bool)
}

protocol PersonalUpdatePresenterProtocol: class {
	func setup()
    func save()
}

protocol PersonalUpdateInteractorInputProtocol: class {
	func setup()
    func refresh()
    func update(with info: PersonalInfo)
}

protocol PersonalUpdateInteractorOutputProtocol: class {
    func didReceive(user: UserData?)
    func didReceiveUserDataProvider(error: Error)

    func didUpdateUser(with info: PersonalInfo)
    func didReceiveUserUpdate(error: Error)
}

protocol PersonalUpdateWireframeProtocol: ErrorPresentable, AlertPresentable {
    func close(view: PersonalUpdateViewProtocol?)
}

protocol PersonalUpdateViewFactoryProtocol: class {
	static func createView() -> PersonalUpdateViewProtocol?
}
