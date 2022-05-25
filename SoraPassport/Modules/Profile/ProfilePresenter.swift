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

    func activateOption(at index: UInt) {
        guard let option = ProfileOption(rawValue: index) else {
            return
        }

        switch option {
        case .account:      wireframe.showPersonalDetailsView(from: view)
        case .friends:      wireframe.showFriendsView(from: view)
        case .passphrase:   wireframe.showPassphraseView(from: view)
        case .changePin:    wireframe.showChangePin(from: view)
        case .biometry:     break // called by `biometryAction(_:)`
        case .language:     wireframe.showLanguageSelection(from: view)
        case .faq:          wireframe.showFaq(from: view)
        case .about:        wireframe.showAbout(from: view)
        case .disclaimer:   wireframe.showDisclaimer(from: view)
        case .logout:       wireframe.showLogout(from: view, completionBlock: interactor.logoutAndClean)
        }
    }
}

private extension ProfilePresenter {

    private func updateOptionsViewModel() {

        viewModelFactory.biometryIsOn = settingsManager.biometryEnabled ?? false
        viewModelFactory.biometryAction = biometryAction

        let optionViewModels = viewModelFactory.createOptionViewModels(
            locale: localizationManager?.selectedLocale ?? Locale.current,
            language: localizationManager?.selectedLanguage
        )

        view?.didLoad(optionViewModels: optionViewModels)
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
}

extension ProfilePresenter: Localizable {
    func applyLocalization() {
        updateOptionsViewModel()
    }
}
