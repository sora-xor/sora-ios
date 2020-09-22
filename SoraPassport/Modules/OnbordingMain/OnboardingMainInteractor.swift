import Foundation
import RobinHood
import SoraCrypto
import SoraKeystore

enum OnboardingMainInteractorState {
    case initial
    case preparing(operation: BaseOperation<SupportedVersionData>)
    case prepared
    case preparingSignup(onlyVersionCheck: Bool)
    case preparingRestoration(operation: BaseOperation<SupportedVersionData>)
}

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainOutputInteractorProtocol?

    var logger: LoggerProtocol?

    let onboardingPreparationService: OnboardingPreparationServiceProtocol
    private(set) var settings: SettingsManagerProtocol
    let keystore: KeystoreProtocol
    let identityLocalOperationFactory: IdentityOperationFactoryProtocol
    let identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    private(set) var state: OnboardingMainInteractorState = .initial

    init(onboardingPreparationService: OnboardingPreparationServiceProtocol,
         settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol,
         identityLocalOperationFactory: IdentityOperationFactoryProtocol,
         operationManager: OperationManagerProtocol) {
        self.onboardingPreparationService = onboardingPreparationService
        self.settings = settings
        self.keystore = keystore
        self.identityNetworkOperationFactory = identityNetworkOperationFactory
        self.identityLocalOperationFactory = identityLocalOperationFactory
        self.operationManager = operationManager
    }

    private func createNewIdentity(dependingOn optionalVersionOperation: BaseOperation<SupportedVersionData>?) {
        let creationOperation = identityLocalOperationFactory.createNewIdentityOperation(with: keystore)

        creationOperation.configurationBlock = { [weak self] in
            if let versionOperation = optionalVersionOperation {
                guard let result = versionOperation.result else {
                    creationOperation.cancel()
                    self?.logger?.warning("Unexpectedly version check cancelled during identity creation")
                    return
                }

                switch result {
                case .success(let data):
                    if !data.supported {
                        creationOperation.cancel()
                    }
                case .failure(let error):
                    creationOperation.result = .failure(error)
                }
            }
        }

        if let versionOperation = optionalVersionOperation {
            creationOperation.addDependency(versionOperation)
        }

        operationManager.enqueue(operations: [creationOperation], in: .transient)

        let submitionOperation = submitIdentity(dependingOn: creationOperation)

        saveIdentity(dependingOn: creationOperation,
                     submissionOperation: submitionOperation)
    }

    private func submitIdentity(dependingOn identityCreationOperation: BaseOperation<DecentralizedDocumentObject>)
        -> NetworkOperation<Bool> {
        let identitySubmitOperation = identityNetworkOperationFactory.createDecentralizedDocumentOperation {
            guard let result = identityCreationOperation.result else {
                throw BaseOperationError.parentOperationCancelled
            }

            switch result {
            case .success(let documentObject):
                return documentObject
            case .failure(let error):
                throw error
            }
        }

        identitySubmitOperation.addDependency(identityCreationOperation)

        operationManager.enqueue(operations: [identitySubmitOperation], in: .transient)

        return identitySubmitOperation
    }

    @discardableResult
    private func saveIdentity(dependingOn identityCreationOperation: BaseOperation<DecentralizedDocumentObject>,
                              submissionOperation: BaseOperation<Bool>) -> BaseOperation<Void> {
        let saveOperation = BaseOperation<Void>()
        saveOperation.configurationBlock = {
            guard let submitionResult = submissionOperation.result else {
                saveOperation.cancel()
                return
            }

            if case .failure(let error) = submitionResult {
                saveOperation.result = .failure(error)
                return
            }

            guard let creationResult = identityCreationOperation.result,
                case .success(let document) = creationResult else {
                    saveOperation.result = .failure(BaseOperationError.unexpectedDependentResult)
                    return
            }

            guard let publicKeyId = document.publicKey.first?.pubKeyId else {
                saveOperation.result = .failure(DDOBuilderError.noPublicKeysFound)
                return
            }

            self.settings.decentralizedId = document.decentralizedId
            self.settings.publicKeyId = publicKeyId

            saveOperation.result = .success(())
        }

        saveOperation.addDependency(submissionOperation)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {

                if let result = saveOperation.result {
                    switch result {
                    case .success:
                        self?.handleIdentityCreationCompletion()
                    case .failure(let error):
                        self?.handleIdentityCreation(error: error)
                    }
                } else {
                    self?.logger?.warning("Identity creation has been unexpectedly cancelled")
                }
            }
        }

        operationManager.enqueue(operations: [saveOperation], in: .transient)

        return saveOperation
    }

    private func prepareOnboarding() throws -> BaseOperation<SupportedVersionData> {
        let operation = try onboardingPreparationService.prepare(using: operationManager)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {

                if let result = operation.result {
                    switch result {
                    case .success(let data):
                        self?.handlePreparation(data: data)
                    case .failure(let error):
                        self?.handlePreparation(error: error)
                    }
                } else {
                    self?.logger?.warning("Check version unexpectedly cancelled")
                }
            }
        }

        return operation
    }

    private func handlePreparation(data: SupportedVersionData) {
        switch state {
        case .initial, .prepared:
            logger?.warning("Unexpected state \(state) when version result received")
        case .preparing:
            state = .prepared
            presenter?.didReceiveVersion(data: data)
        case .preparingSignup(let onlyVersionCheck):
            if onlyVersionCheck {
                state = .prepared

                presenter?.didReceiveVersion(data: data)

                if data.supported {
                    presenter?.didFinishSignupPreparation()
                }
            } else {
                if !data.supported {
                    state = .prepared
                }

                presenter?.didReceiveVersion(data: data)

                logger?.debug("Wait until new identity creation completes")
            }
        case .preparingRestoration:
            state = .prepared

            presenter?.didReceiveVersion(data: data)

            if data.supported {
                presenter?.didFinishRestorePreparation()
            }
        }
    }

    private func handlePreparation(error: Error) {
        switch state {
        case .initial, .prepared:
            logger?.warning("Unexpected state \(state) when received version error: \(error)")
        case .preparing:
            state = .initial
        case .preparingSignup(let onlyVersionCheck):
            if onlyVersionCheck {
                state = .initial
                presenter?.didReceiveSignupPreparation(error: error)
            } else {
                logger?.debug("Did receive check version error but will be propagated")
            }
        case .preparingRestoration:
            state = .initial
            presenter?.didReceiveRestorePreparation(error: error)
        }
    }

    private func handleIdentityCreationCompletion() {
        if case .preparingSignup = state {
            state = .prepared

            presenter?.didFinishSignupPreparation()
        } else {
            logger?.warning("Unexpected state \(state) when received identity completion")
        }
    }

    private func handleIdentityCreation(error: Error) {
        if case .preparingSignup = state {
            state = .initial

            presenter?.didReceiveSignupPreparation(error: error)
        } else {
            logger?.warning("Unexpected state \(state) when received identity creation error: \(error)")
        }
    }
}

extension OnboardingMainInteractor: OnboardingMainInputInteractorProtocol {
    func setup() {
        if case .initial = state, let operation = try? prepareOnboarding() {
            state = .preparing(operation: operation)
        }
    }

    func prepareSignup() {
        switch state {
        case .initial:
            do {
                let versionOperation = try prepareOnboarding()

                if settings.decentralizedId == nil {
                    createNewIdentity(dependingOn: versionOperation)

                    state = .preparingSignup(onlyVersionCheck: false)
                } else {
                    state = .preparingSignup(onlyVersionCheck: true)
                }

                presenter?.didStartSignupPreparation()
            } catch {
                presenter?.didReceiveSignupPreparation(error: error)
            }

        case .preparing(let operation):
            if settings.decentralizedId == nil {
                createNewIdentity(dependingOn: operation)

                state = .preparingSignup(onlyVersionCheck: false)
            } else {
                state = .preparingSignup(onlyVersionCheck: true)
            }

            presenter?.didStartSignupPreparation()
        case .prepared:
            if settings.decentralizedId == nil {
                createNewIdentity(dependingOn: nil)

                state = .preparingSignup(onlyVersionCheck: false)

                presenter?.didStartSignupPreparation()
            } else {
                presenter?.didFinishSignupPreparation()
            }
        case .preparingSignup:
            logger?.warning("Already started signup preparation but called additionally")
        case .preparingRestoration:
            logger?.warning("Already processing sign up but requested additionally")
        }
    }

    func prepareRestore() {
        switch state {
        case .initial:
            do {
                let operation = try prepareOnboarding()
                state = .preparingRestoration(operation: operation)
                presenter?.didStartRestorePreparation()
            } catch {
                presenter?.didReceiveRestorePreparation(error: error)
            }
        case .preparing(let operation):
            state = .preparingRestoration(operation: operation)
            presenter?.didStartRestorePreparation()
        case .prepared:
            presenter?.didFinishRestorePreparation()
        case .preparingSignup:
            logger?.warning("Already processing signing up but restoration requested")
        case .preparingRestoration:
            logger?.warning("Already processing restoration but requested additionally")
        }
    }
}
