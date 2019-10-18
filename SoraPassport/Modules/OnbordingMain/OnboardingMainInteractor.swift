/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import SoraCrypto
import SoraKeystore

enum OnboardingMainInteractorState {
    case initial
    case checkingVersion(operation: BaseOperation<SupportedVersionData>)
    case checkedVersion
    case preparingSignup(onlyVersionCheck: Bool)
    case preparingRestoration(operation: BaseOperation<SupportedVersionData>)
}

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainOutputInteractorProtocol?

    var logger: LoggerProtocol?

    let applicationConfig: ApplicationConfigProtocol
    private(set) var settings: SettingsManagerProtocol
    let keystore: KeystoreProtocol
    let informationOperationFactory: ProjectInformationOperationFactoryProtocol
    let identityLocalOperationFactory: IdentityOperationFactoryProtocol.Type
    let identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    private(set) var state: OnboardingMainInteractorState = .initial

    init(applicationConfig: ApplicationConfigProtocol,
         settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         informationOperationFactory: ProjectInformationOperationFactoryProtocol,
         identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol,
         identityLocalOperationFactory: IdentityOperationFactoryProtocol.Type,
         operationManager: OperationManagerProtocol) {
        self.applicationConfig = applicationConfig
        self.settings = settings
        self.keystore = keystore
        self.informationOperationFactory = informationOperationFactory
        self.identityNetworkOperationFactory = identityNetworkOperationFactory
        self.identityLocalOperationFactory = identityLocalOperationFactory
        self.operationManager = operationManager
    }

    private func createNewIdentity(dependingOn optionalVersionOperation: BaseOperation<SupportedVersionData>?) {
        let creationOperation = identityLocalOperationFactory.createNewIdentityOperation()

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
                case .error(let error):
                    creationOperation.result = .error(error)
                }
            }
        }

        if let versionOperation = optionalVersionOperation {
            creationOperation.addDependency(versionOperation)
        }

        operationManager.enqueue(operations: [creationOperation], in: .normal)

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
            case .error(let error):
                throw error
            }
        }

        identitySubmitOperation.addDependency(identityCreationOperation)

        operationManager.enqueue(operations: [identitySubmitOperation], in: .normal)

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

            if case .error(let error) = submitionResult {
                saveOperation.result = .error(error)
                return
            }

            guard let creationResult = identityCreationOperation.result,
                case .success(let document) = creationResult else {
                    saveOperation.result = .error(BaseOperationError.unexpectedDependentResult)
                    return
            }

            guard let publicKeyId = document.publicKey.first?.pubKeyId else {
                saveOperation.result = .error(DDOBuilderError.noPublicKeysFound)
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
                    case .error(let error):
                        self?.handleIdentityCreation(error: error)
                    }
                } else {
                    self?.logger?.warning("Identity creation has been unexpectedly cancelled")
                }
            }
        }

        operationManager.enqueue(operations: [saveOperation], in: .normal)

        return saveOperation
    }

    private func prepareOnboarding() throws -> BaseOperation<SupportedVersionData> {
        guard let service = applicationConfig.defaultProjectUnit
            .service(for: ProjectServiceType.supportedVersion.rawValue) else {
                throw NetworkUnitError.serviceUnavailable
        }

        let version = applicationConfig.version

        let versionCheckOperation = informationOperationFactory.checkSupportedVersionOperation(service.serviceEndpoint,
                                                                                               version: version)

        let keystoreClearOperation = ClosureOperation<SupportedVersionData> {
            guard let result = versionCheckOperation.result else {
                throw BaseOperationError.parentOperationCancelled
            }

            switch result {
            case .success(let versionCheckData):
                if versionCheckData.supported {
                    if self.settings.verificationState == nil {
                        self.settings.verificationState = VerificationState()
                    }

                    try self.keystore.deleteKeyIfExists(for: KeystoreKey.pincode.rawValue)
                }

                return versionCheckData
            case .error(let error):
                throw error
            }
        }

        keystoreClearOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {

                if let result = keystoreClearOperation.result {
                    switch result {
                    case .success(let data):
                        self?.handleCheckVersion(data: data)
                    case .error(let error):
                        self?.handleCheckVersion(error: error)
                    }
                } else {
                    self?.logger?.warning("Check version unexpectedly cancelled")
                }
            }
        }

        keystoreClearOperation.addDependency(versionCheckOperation)

        operationManager.enqueue(operations: [versionCheckOperation, keystoreClearOperation], in: .normal)

        return keystoreClearOperation
    }

    private func handleCheckVersion(data: SupportedVersionData) {
        switch state {
        case .initial, .checkedVersion:
            logger?.warning("Unexpected state \(state) when version result received")
        case .checkingVersion:
            state = .checkedVersion
            presenter?.didReceiveVersion(data: data)
        case .preparingSignup(let onlyVersionCheck):
            if onlyVersionCheck {
                state = .checkedVersion

                presenter?.didReceiveVersion(data: data)

                if data.supported {
                    presenter?.didFinishSignupPreparation()
                }
            } else {
                if !data.supported {
                    state = .checkedVersion
                }

                presenter?.didReceiveVersion(data: data)

                logger?.debug("Wait until new identity creation completes")
            }
        case .preparingRestoration:
            state = .checkedVersion

            presenter?.didReceiveVersion(data: data)

            if data.supported {
                presenter?.didFinishRestorePreparation()
            }
        }
    }

    private func handleCheckVersion(error: Error) {
        switch state {
        case .initial, .checkedVersion:
            logger?.warning("Unexpected state \(state) when received version error: \(error)")
        case .checkingVersion:
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
            state = .checkedVersion

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
            state = .checkingVersion(operation: operation)
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

        case .checkingVersion(let operation):
            if settings.decentralizedId == nil {
                createNewIdentity(dependingOn: operation)

                state = .preparingSignup(onlyVersionCheck: false)
            } else {
                state = .preparingSignup(onlyVersionCheck: true)
            }

            presenter?.didStartSignupPreparation()
        case .checkedVersion:
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
        case .checkingVersion(let operation):
            state = .preparingRestoration(operation: operation)
            presenter?.didStartRestorePreparation()
        case .checkedVersion:
            presenter?.didFinishRestorePreparation()
        case .preparingSignup:
            logger?.warning("Already processing signing up but restoration requested")
        case .preparingRestoration:
            logger?.warning("Already processing restoration but requested additionally")
        }
    }
}
