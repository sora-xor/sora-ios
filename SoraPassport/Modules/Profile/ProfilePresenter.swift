/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import SoraFoundation
import SoraUI

final class ProfilePresenter {
    weak var view: ProfileViewProtocol?
    var wireframe: ProfileWireframeProtocol!
    var interactor: ProfileInteractorInputProtocol!

    private(set) var viewModelFactory: ProfileViewModelFactoryProtocol
    private(set) var settingsManager: SettingsManagerProtocol

    init(viewModelFactory: ProfileViewModelFactoryProtocol,
         settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
        self.viewModelFactory = viewModelFactory
    }
}

extension ProfilePresenter: ProfilePresenterProtocol {

    func setup() {
        updateOptionsViewModel()
    }

    func activateOption(_ option: ProfileOption) {
        switch option {
        case .account:      wireframe.showChangeAccountView(from: view, completion: updateOptionsViewModel)
        case .accountName:  wireframe.showPersonalDetailsView(from: view, completion: updateOptionsViewModel)
        case .friends:      wireframe.showFriendsView(from: view)
        case .passphrase:   wireframe.showPassphraseView(from: view)
        case .changePin:    wireframe.showChangePin(from: view!)
        case .biometry:     break // called by `biometryAction(_:)`
        case .language:     wireframe.showLanguageSelection(from: view)
        case .faq:          wireframe.showFaq(from: view)
        case .about:        wireframe.showAbout(from: view)
        case .disclaimer:   wireframe.showDisclaimer(from: view)
        case .logout:
            interactor.isLastAccountWithCustomNodes { [weak self] result in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.wireframe.showLogout(from: self.view, isNeedCustomNodeText: result, completionBlock: self.interactor.logoutAndClean)
                }
            }

        case .nodes:        wireframe.showNodes(from: view)
        }
    }
}

private extension ProfilePresenter {

    private func updateOptionsViewModel() {

        viewModelFactory.biometryIsOn = settingsManager.biometryEnabled ?? false
        viewModelFactory.biometryAction = biometryAction

        interactor?.getCurrentNodeName(completion: { [weak self] nodeName in

            let optionsViewModels = self?.viewModelFactory.createOptionsViewModels(
                locale:  self?.localizationManager?.selectedLocale ?? Locale.current,
                nodeName: nodeName,
                language:  self?.localizationManager?.selectedLanguage,
                username:  self?.settingsManager.userName ?? "",
                address:  SelectedWalletSettings.shared.currentAccount?.address ?? "",
                isNeedPassphase:  self?.interactor?.isThereEntropy ?? false
            )

            self?.view?.didLoad(optionsViewModels: optionsViewModels ?? [])
        })
    }

    private func biometryAction(_ isOn: Bool) {
        wireframe.switchBiometry(toValue: isOn, from: view) { (_) in
            self.updateOptionsViewModel()
        }
    }
}

extension ProfilePresenter: ProfileInteractorOutputProtocol {
    func restart() {
        wireframe.showRoot()
    }

    func updateScreen() {
        updateOptionsViewModel()
    }
}

extension ProfilePresenter: Localizable {
    func applyLocalization() {
        updateOptionsViewModel()
    }
}
