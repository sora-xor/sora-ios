/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class PersonalUpdatePresenter {
    enum DataLoadingState {
        case waitingCached
        case waitingRefresh
        case refreshed
    }

	weak var view: PersonalUpdateViewProtocol?
	var interactor: PersonalUpdateInteractorInputProtocol!
	var wireframe: PersonalUpdateWireframeProtocol!

    var logger: LoggerProtocol?

    private(set) var viewModelFactory: PersonalInfoViewModelFactoryProtocol

    private(set) var userData: UserData?
    private(set) var models: [PersonalInfoViewModel]?

    private(set) var dataLoadingState: DataLoadingState = .waitingCached

    init(viewModelFactory: PersonalInfoViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory
    }

    private func updateViewModel() {
        if let userData = userData {
            models = viewModelFactory.createViewModels(from: userData)
        } else {
            models = viewModelFactory.createEmpty()
        }

        guard let models = models else {
            return
        }

        models[PersonalInfoViewModelIndex.phone.rawValue].enabled = false

        view?.didReceive(viewModels: models)
    }

    private func prepareUpdateInfo() -> PersonalInfo? {
        guard let models = models else {
            return nil
        }

        guard let userData = userData else {
            return nil
        }

        var info = PersonalInfo()
        var hasChanges: Bool = false

        let newFirstName = models[PersonalInfoViewModelIndex.firstName.rawValue].value
        if newFirstName != userData.firstName {
            info.firstName = newFirstName
            hasChanges = true
        }

        let newLastName = models[PersonalInfoViewModelIndex.lastName.rawValue].value
        if newLastName != userData.lastName {
            info.lastName = newLastName
            hasChanges = true
        }

        let newEmail = models[PersonalInfoViewModelIndex.email.rawValue].value
        if newEmail != userData.email {
            info.email = newEmail
            hasChanges = true
        }

        return hasChanges ? info : nil
    }

    private func handleDataProvider(error: Error) {
        if wireframe.present(error: error, from: view) {
            return
        }

        if let userError = error as? UserDataError {
            switch userError {
            case .userNotFound:
                wireframe.present(message: R.string.localizable.errorTitle(),
                                  title: R.string.localizable.personalUpdateInfoUserNotFoundError(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            case .userValuesNotFound:
                wireframe.present(message: R.string.localizable.errorTitle(),
                                  title: R.string.localizable.personalUpdateInfoUserValuesNotFoundError(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            }
        }
    }
}

extension PersonalUpdatePresenter: PersonalUpdatePresenterProtocol {
    func viewIsReady() {
        view?.didStartLoading()

        interactor.setup()
    }

    func save() {
        guard case .refreshed = dataLoadingState else {
            return
        }

        if let info = prepareUpdateInfo() {
            view?.didStartLoading()

            interactor.update(with: info)
        } else {
            view?.didStopLoading()
            view?.didCompleteSaving(success: true)

            wireframe.close(view: view)
        }
    }
}

extension PersonalUpdatePresenter: PersonalUpdateInteractorOutputProtocol {
    func didReceive(user: UserData?) {
        switch dataLoadingState {
        case .waitingCached:
            self.userData = user
            updateViewModel()

            dataLoadingState = .waitingRefresh
            interactor.refresh()
        case .waitingRefresh, .refreshed:
            if let user = user {
                self.userData = user
                updateViewModel()
            }

            dataLoadingState = .refreshed
            view?.didStopLoading()
        }
    }

    func didReceiveUserDataProvider(error: Error) {
        view?.didStopLoading()

        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Unexpected data provider fail while waiting cached data")
        case .waitingRefresh:
            handleDataProvider(error: error)
        case .refreshed:
            logger?.debug("Data provider failed but already refreshed")
        }
    }

    func didUpdateUser(with info: PersonalInfo) {
        view?.didStopLoading()
        view?.didCompleteSaving(success: true)

        wireframe.close(view: view)
    }

    func didReceiveUserUpdate(error: Error) {
        view?.didStopLoading()
        view?.didCompleteSaving(success: false)

        if wireframe.present(error: error, from: view) {
            return
        }

        if let updateError = error as? PersonalUpdateDataError {
            switch updateError {
            case .userNotFound:
                wireframe.present(message: R.string.localizable.errorTitle(),
                                  title: R.string.localizable.personalUpdateInfoUserNotFoundError(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            }
        }
    }
}
