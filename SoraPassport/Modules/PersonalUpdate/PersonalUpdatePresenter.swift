/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class PersonalUpdatePresenter {
    enum ViewModelIndex: Int {
        case firstName
        case lastName
        case phone
    }

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

    let locale: Locale

    init(locale: Locale, viewModelFactory: PersonalInfoViewModelFactoryProtocol) {
        self.locale = locale
        self.viewModelFactory = viewModelFactory
    }

    private func updateViewModel() {
        let models = viewModelFactory.createViewModels(from: userData, locale: locale)
        models[ViewModelIndex.phone.rawValue].enabled = false
        self.models = models

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

        let newFirstName = models[ViewModelIndex.firstName.rawValue].value
        if newFirstName != userData.firstName {
            info.firstName = newFirstName
            hasChanges = true
        }

        let newLastName = models[ViewModelIndex.lastName.rawValue].value
        if newLastName != userData.lastName {
            info.lastName = newLastName
            hasChanges = true
        }

        return hasChanges ? info : nil
    }

    private func handleDataProvider(error: Error) {
        if wireframe.present(error: error, from: view, locale: locale) {
            return
        }
    }
}

extension PersonalUpdatePresenter: PersonalUpdatePresenterProtocol {
    func setup() {
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

        if wireframe.present(error: error, from: view, locale: locale) {
            return
        }
    }
}
