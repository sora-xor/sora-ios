import Foundation
import RobinHood
import FearlessUtils
import SoraKeystore

enum OnboardingMainInteractorState {
    case initial
    case preparing(operation: BaseOperation<SupportedVersionData>)
    case prepared
    case preparingSignup(onlyVersionCheck: Bool)
    case preparingRestoration(operation: BaseOperation<SupportedVersionData>)
}

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    private(set) var state: OnboardingMainInteractorState = .initial

    let keystoreImportService: KeystoreImportServiceProtocol

    init(keystoreImportService: KeystoreImportServiceProtocol) {
        self.keystoreImportService = keystoreImportService
    }
}

extension OnboardingMainInteractor: OnboardingMainInteractorInputProtocol {
    func setup() {
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }
}

extension OnboardingMainInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }
}
