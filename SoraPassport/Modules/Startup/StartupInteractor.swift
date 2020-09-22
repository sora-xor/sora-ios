/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import RobinHood

private enum StartupInteractorError: Error {
    case unsupportedVersion(data: SupportedVersionData)
    case verificationFailed
}

private typealias RegistrationCompletionBlock = (Result<UserData?, Error>?) -> Void

final class StartupInteractor {

	weak var presenter: StartupInteractorOutputProtocol?

    var logger: LoggerProtocol?

    private(set) var state: StartupInteratorState = .initial {
        didSet {
            if state != oldValue {
                logger?.debug("State changed from \(oldValue) to \(state)")

                presenter?.didChangeState()
            }
        }
    }

    private(set) var settings: SettingsManagerProtocol
    private(set) var keystore: KeystoreProtocol
    private(set) var config: ApplicationConfigProtocol
    private(set) var identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol
    private(set) var identityLocalOperationFactory: IdentityOperationFactoryProtocol
    private(set) var accountOperationFactory: ProjectAccountOperationFactoryProtocol
    private(set) var informationOperationFactory: ProjectInformationOperationFactoryProtocol
    private(set) var operationManager: OperationManagerProtocol
    private(set) var reachabilityManager: ReachabilityManagerProtocol?

    deinit {
        reachabilityManager?.remove(listener: self)
    }

    init(settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         config: ApplicationConfigProtocol,
         identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol,
         identityLocalOperationFactory: IdentityOperationFactoryProtocol,
         accountOperationFactory: ProjectAccountOperationFactoryProtocol,
         informationOperationFactory: ProjectInformationOperationFactoryProtocol,
         operationManager: OperationManagerProtocol,
         reachabilityManager: ReachabilityManagerProtocol?) {

        self.reachabilityManager = reachabilityManager
        self.settings = settings
        self.keystore = keystore
        self.config = config
        self.identityNetworkOperationFactory = identityNetworkOperationFactory
        self.identityLocalOperationFactory = identityLocalOperationFactory
        self.accountOperationFactory = accountOperationFactory
        self.informationOperationFactory = informationOperationFactory
        self.operationManager = operationManager

        try? reachabilityManager?.add(listener: self)
    }

    private func performVersionCheckOperation(for urlTemplate: String) -> BaseOperation<SupportedVersionData> {
        let version = config.version

        logger?.debug("Checking if \(version) version supported")

        let checkVersionOperation = informationOperationFactory
            .checkSupportedVersionOperation(urlTemplate, version: version)

        operationManager.enqueue(operations: [checkVersionOperation], in: .transient)

        return checkVersionOperation
    }

    private func performIdentityUpdateOperation(for decentralizedId: String,
                                                dependingOn versionOperation: BaseOperation<SupportedVersionData>)
        -> BaseOperation<Void> {

        let identityFetchOperation = performIdentityFetch(for: decentralizedId, dependingOn: versionOperation)
        let identityVerifyOperation = performIdentityVerify(for: decentralizedId, dependingOn: identityFetchOperation)
        let identityUpdateOperation = performIdentityUpdateOperation(for: decentralizedId,
                                                                     dependingOn: identityVerifyOperation)
        let secondaryIdentityOperation = performSecondaryIdentitiesUpdateOperation(dependingOn: identityUpdateOperation)

        return secondaryIdentityOperation
    }

    private func performIdentityFetch(for decentralizedId: String,
                                      dependingOn versionOperation: BaseOperation<SupportedVersionData>)
        -> BaseOperation<DecentralizedDocumentObject> {
            logger?.debug("Fetching current identity for \(decentralizedId)")

            let identityFetchOperation = identityNetworkOperationFactory
                .createDecentralizedDocumentFetchOperation(decentralizedId: decentralizedId)

            identityFetchOperation.configurationBlock = {
                guard let versionResult = versionOperation.result else {
                    self.logger?.warning("Something cause version operation to cancel")

                    identityFetchOperation.cancel()
                    return
                }

                switch versionResult {
                case .success(let data):
                    self.logger?.debug("Current version is supported = \(data.supported)")
                    if !data.supported {
                        identityFetchOperation.result = .failure(StartupInteractorError.unsupportedVersion(data: data))
                    }
                case .failure(let error):
                    identityFetchOperation.result = .failure(error)
                }
            }

            identityFetchOperation.addDependency(versionOperation)

            operationManager.enqueue(operations: [identityFetchOperation], in: .transient)

            return identityFetchOperation
    }

    private func performIdentityVerify(for decentralizedId: String,
                                       dependingOn fetchOperation: BaseOperation<DecentralizedDocumentObject>)
        -> IdentityVerifyOperation {

            let identityVerifyOperation = identityLocalOperationFactory.createVerificationOperation(with: keystore)
            identityVerifyOperation.configurationBlock = {
                guard let fetchResult = fetchOperation.result else {
                    self.logger?.warning("Something caused identity fetch to cancel")

                    identityVerifyOperation.cancel()
                    return
                }

                switch fetchResult {
                case .success(let documentObject):
                    self.logger?.debug("Successfully fetched identity for \(decentralizedId)")

                    identityVerifyOperation.decentralizedDocument = documentObject
                case .failure(let error):
                    self.logger?.warning("Identity fetching error received \(error)")

                    identityVerifyOperation.result = .failure(error)
                }
            }

            identityVerifyOperation.addDependency(fetchOperation)

            operationManager.enqueue(operations: [identityVerifyOperation], in: .transient)

            return identityVerifyOperation
    }

    private func performIdentityUpdateOperation(for decentralizedId: String,
                                                dependingOn verifyOperation: IdentityVerifyOperation)
        -> BaseOperation<Bool> {

        let identityUpdateOperation = BaseOperation<Bool>()
        identityUpdateOperation.configurationBlock = {

            self.logger?.debug("Updating identity for \(decentralizedId)")

            guard let verificationResult = verifyOperation.result else {
                self.logger?.warning("Something caused identity update to cancel")

                identityUpdateOperation.cancel()
                return
            }

            switch verificationResult {
            case .success(let publicKeyId):
                self.logger?
                    .debug("Successfully updated identity \(decentralizedId) with public key id \(publicKeyId)")

                self.settings.publicKeyId = publicKeyId
                identityUpdateOperation.result = .success(true)
            case .failure(let error):
                self.logger?.warning("Identity verification error \(error)")

                identityUpdateOperation.result = .failure(error)
            }
        }

        identityUpdateOperation.addDependency(verifyOperation)

            operationManager.enqueue(operations: [identityUpdateOperation], in: .transient)

        return identityUpdateOperation
    }

    private func performSecondaryIdentitiesUpdateOperation(dependingOn operation: BaseOperation<Bool>)
        -> BaseOperation<Void> {
        let updateOperation = identityLocalOperationFactory.createSecondaryIdentitiesOperation(with: keystore,
                                                                                               skipIfExists: true)

        updateOperation.configurationBlock = {
            self.logger?.debug("Did start secondary identities update")

            guard let dependencyResult = operation.result else {
                self.logger?.warning("Something caused identity registration checking to cancel")

                updateOperation.cancel()
                return
            }

            switch dependencyResult {
            case .success(let isSuccess):
                if !isSuccess {
                    updateOperation.result = .failure(StartupInteractorError.verificationFailed)
                }
            case .failure(let error):
                self.logger?.warning("Update identity error \(error)")

                updateOperation.result = .failure(error)
            }
        }

        updateOperation.addDependency(operation)

        operationManager.enqueue(operations: [updateOperation], in: .transient)

        return updateOperation
    }

    private func performRegistrationCheckOperation(for urlTemplate: String,
                                                   dependingOn operation: BaseOperation<Void>,
                                                   with completionBlock: @escaping RegistrationCompletionBlock) {
        let userOperation = accountOperationFactory.fetchCustomerOperation(urlTemplate)

        if let requestSigner = DARequestSigner.createDefault() {
            userOperation.requestModifier = requestSigner
        }

        userOperation.configurationBlock = {
            self.logger?.debug("Did start checking identity registration")

            guard let dependencyResult = operation.result else {
                self.logger?.warning("Something caused identity registration checking to cancel")

                userOperation.cancel()
                return
            }

            if case .failure(let error) = dependencyResult {
                if let verificationError = error as? IdentityVerifyOperationError,
                    verificationError == .authenticablePublicKeyNotFound {
                    userOperation.result = .failure(StartupInteractorError.verificationFailed)
                } else if let decentralizedObjectError = error as? DecentralizedDocumentQueryDataError,
                    decentralizedObjectError == .decentralizedIdNotFound {
                    userOperation.result = .failure(StartupInteractorError.verificationFailed)
                } else {
                    userOperation.result = .failure(error)
                }
            }
        }

        userOperation.addDependency(operation)

        userOperation.completionBlock = {
            DispatchQueue.main.async {
                completionBlock(userOperation.result)
            }
        }

        operationManager.enqueue(operations: [userOperation], in: .transient)
    }

    private func handleInteractor(error: StartupInteractorError) {
        switch error {
        case .unsupportedVersion(let data):
            state = .unsupported

            presenter?.didDecideUnsupportedVersion(data: data)
        case .verificationFailed:
            removeIdentityAndFailVerification()
        }
    }

    private func removeIdentityAndFailVerification() {
        let removalOperation = identityLocalOperationFactory.createLocalRemoveOperation(with: keystore,
                                                                                        settings: settings)

        removalOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = removalOperation.result {
                    self.proccessRemovalOperation(result: result)
                } else {
                    self.scheduleVerificationRetry()
                }
            }
        }

        operationManager.enqueue(operations: [removalOperation], in: .transient)
    }

    private func proccessRemovalOperation(result: Result<Bool, Error>) {
        switch result {
        case .success:
            completeVerification(success: false)
        case .failure:
            scheduleVerificationRetry()
        }
    }

    private func processVerification(result: Result<UserData?, Error>?) {
        logger?.debug("Processing identity verification result")

        guard let verificationResult = result else {
            logger?.warning("Identity verification was cancelled")

            scheduleVerificationRetry()
            return
        }

        switch verificationResult {
        case .success:
            logger?.info("Successfully verified identity")

            completeVerification(success: true)
        case .failure(let error):
            self.logger?.warning("Identity verification completed with \(error)")

            if let interactorError = error as? StartupInteractorError {
                handleInteractor(error: interactorError)
            } else {
                scheduleVerificationRetry()
            }
        }
    }

    private func completeVerification(success: Bool) {
        state = .completed

        if success {
            do {
                let pincodeExists = try keystore.checkKey(for: KeystoreKey.pincode.rawValue)

                if pincodeExists {
                    presenter?.didDecideMain()
                } else {
                    presenter?.didDecidePincodeSetup()
                }

            } catch {
                presenter?.didDecidePincodeSetup()
            }
        } else {
            presenter?.didDecideOnboarding()
        }
    }

    private func scheduleVerificationRetry() {
        state = .waitingRetry

        retryVerificationIfPossible()
    }

    private func retryVerificationIfPossible() {
        logger?.debug("""
                Retrying identinty verification when reachability\
            \(String(describing: reachabilityManager?.isReachable))
            """)

        if let reachability = reachabilityManager,
            reachability.isReachable, state == .waitingRetry {
            state = .initial
            verify()
        }
    }
}

extension StartupInteractor: StartupInteractorInputProtocol {
    func verify() {
        guard state == .initial || state == .waitingRetry else {
            return
        }

        state = .verifying

        guard let decentralizedId = settings.decentralizedId else {
            logger?.warning("Strange, can't verify state without decentralized identifier")

            completeVerification(success: false)
            return
        }

        guard
            let customerService = config.defaultProjectUnit.service(for: ProjectServiceType.customer.rawValue),
            let versionCheckService = config.defaultProjectUnit
                .service(for: ProjectServiceType.supportedVersion.rawValue) else {
            scheduleVerificationRetry()
            return
        }

        let versionCheckOperation = performVersionCheckOperation(for: versionCheckService.serviceEndpoint)

        let identityUpdateOperation = performIdentityUpdateOperation(for: decentralizedId,
                                                                     dependingOn: versionCheckOperation)

        performRegistrationCheckOperation(for: customerService.serviceEndpoint,
                                          dependingOn: identityUpdateOperation) { [weak self] (optionalResult) in
                                            self?.processVerification(result: optionalResult)
        }
    }
}

extension StartupInteractor: ReachabilityListenerDelegate {
    func didChangeReachability(by manager: ReachabilityManagerProtocol) {
        retryVerificationIfPossible()
    }
}
