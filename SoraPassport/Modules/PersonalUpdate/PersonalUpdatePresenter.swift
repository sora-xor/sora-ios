import Foundation
import SoraFoundation

extension PersonalUpdatePresenter {
    enum ViewModelIndex: Int {
        case userName
    }
}

final class PersonalUpdatePresenter {
	weak var view: PersonalUpdateViewProtocol?
	var interactor: PersonalUpdateInteractorInputProtocol!
	var wireframe: PersonalUpdateWireframeProtocol!

    private(set) var viewModelFactory: PersonalInfoViewModelFactoryProtocol

    private(set) var username: String?
    private(set) var models: [InputViewModelProtocol]?

    init(viewModelFactory: PersonalInfoViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory
    }

    private func prepareUpdateInfo() -> String? {
        guard let models = models else {
            return nil
        }

        var hasChanges: Bool = false

        let newUserName = models[ViewModelIndex.userName.rawValue].inputHandler.normalizedValue
        if newUserName != username {
            username = newUserName
            hasChanges = true
        }

        return hasChanges ? username : nil
    }

    private func updateViewModel() {
        let models = viewModelFactory.createViewModels(from: username, locale: locale)
        self.models = models

        view?.didReceive(viewModels: models)
    }
}

extension PersonalUpdatePresenter: PersonalUpdatePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func save() {
        if let username = prepareUpdateInfo() {
            interactor.update(username: username)
        } else {
            view?.didCompleteSaving(success: true)
            wireframe.close(view: view)
        }
    }
}

extension PersonalUpdatePresenter: PersonalUpdateInteractorOutputProtocol {
    func didReceive(username: String?) {
        self.username = username
        updateViewModel()
    }

    func didUpdate(username: String?) {
        view?.didCompleteSaving(success: true)
        wireframe.close(view: view)
    }
}

extension PersonalUpdatePresenter: Localizable {
    private var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
}
