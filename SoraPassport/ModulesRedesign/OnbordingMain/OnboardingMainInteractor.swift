import Foundation
import RobinHood
import FearlessUtils
import SoraKeystore
import SSFCloudStorage

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
    let backupService: CloudStorageServiceProtocol

    init(keystoreImportService: KeystoreImportServiceProtocol,
         backupService: CloudStorageServiceProtocol) {
        self.keystoreImportService = keystoreImportService
        self.backupService = backupService
    }
}

extension OnboardingMainInteractor: OnboardingMainInteractorInputProtocol {
    func setup() {
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }
    
    func resetGoogleState() {
        backupService.disconnect()
    }
    
    func getBackupedAccounts(completion: @escaping (Result<[OpenBackupAccount], Error>) -> Void) {
        backupService.getBackupAccounts(completion: completion)
    }
}

extension OnboardingMainInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }
}
