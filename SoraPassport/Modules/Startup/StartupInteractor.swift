/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import RobinHood

private enum StartupInteractorError: Error {
    case verificationFailed
}

private typealias RegistrationCompletionBlock = (OperationResult<UserData>?) -> Void

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
    private(set) var identityLocalOperationFactory: IdentityOperationFactoryProtocol.Type
    private(set) var accountOperationFactory: ProjectAccountOperationFactoryProtocol
    private(set) var operationManager: OperationManagerProtocol
    private(set) var reachabilityManager: ReachabilityManagerProtocol?

    deinit {
        reachabilityManager?.remove(listener: self)
    }

    init(settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         config: ApplicationConfigProtocol,
         identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol,
         identityLocalOperationFactory: IdentityOperationFactoryProtocol.Type,
         accountOperationFactory: ProjectAccountOperationFactoryProtocol,
         operationManager: OperationManagerProtocol,
         reachabilityManager: ReachabilityManagerProtocol?) {

        self.reachabilityManager = reachabilityManager
        self.settings = settings
        self.keystore = keystore
        self.config = config
        self.identityNetworkOperationFactory = identityNetworkOperationFactory
        self.identityLocalOperationFactory = identityLocalOperationFactory
        self.accountOperationFactory = accountOperationFactory
        self.operationManager = operationManager

        try? reachabilityManager?.add(listener: self)
    }

    private func performIdentityUpdateOperation(for decentralizedId: String) -> BaseOperation<Bool> {
        logger?.debug("Fetching current identity for \(decentralizedId)")

        let identityFetchOperation = identityNetworkOperationFactory
            .createDecentralizedDocumentFetchOperation(decentralizedId: decentralizedId)

        let identityVerifyOperation = identityLocalOperationFactory.createVerificationOperation()
        identityVerifyOperation.configurationBlock = {
            guard let fetchResult = identityFetchOperation.result else {
                self.logger?.warning("Something caused identity fetch to cancel")

                identityVerifyOperation.cancel()
                return
            }

            switch fetchResult {
            case .success(let documentObject):
                self.logger?.debug("Successfully fetched identity for \(decentralizedId)")

                identityVerifyOperation.decentralizedDocument = documentObject
            case .error(let error):
                self.logger?.warning("Identity fetching error received \(error)")

                identityVerifyOperation.result = .error(error)
            }
        }

        identityVerifyOperation.addDependency(identityFetchOperation)

        let identityUpdateOperation = BaseOperation<Bool>()
        identityUpdateOperation.configurationBlock = {

            self.logger?.debug("Updating identity for \(decentralizedId)")

            guard let verificationResult = identityVerifyOperation.result else {
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
            case .error(let error):
                self.logger?.warning("Update identity error \(error)")

                identityUpdateOperation.result = .error(error)
            }
        }

        identityUpdateOperation.addDependency(identityVerifyOperation)

        let operations = [identityFetchOperation, identityVerifyOperation, identityUpdateOperation]
        operationManager.enqueue(operations: operations, in: .normal)

        return identityUpdateOperation
    }

    private func performRegistrationCheckOperation(for urlTemplate: String, dependingOn operation: BaseOperation<Bool>,
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

            switch dependencyResult {
            case .success(let isSuccess):
                if !isSuccess {
                    userOperation.result = .error(StartupInteractorError.verificationFailed)
                }
            case .error(let error):
                if let verificationError = error as? IdentityVerifyOperationError,
                    verificationError == .authenticablePublicKeyNotFound {
                    userOperation.result = .error(StartupInteractorError.verificationFailed)
                } else if let decentralizedObjectError = error as? DecentralizedDocumentQueryDataError,
                    decentralizedObjectError == .decentralizedIdNotFound {
                    userOperation.result = .error(StartupInteractorError.verificationFailed)
                } else {
                    userOperation.result = .error(error)
                }
            }
        }

        userOperation.addDependency(operation)

        userOperation.completionBlock = {
            DispatchQueue.main.async {
                completionBlock(userOperation.result)
            }
        }

        operationManager.enqueue(operations: [userOperation], in: .normal)
    }

    private func removeIdentityAndFailVerification() {
        let removalOperation = identityLocalOperationFactory.createLocalRemoveOperation()

        removalOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = removalOperation.result {
                    self.proccessRemovalOperation(result: result)
                } else {
                    self.scheduleVerificationRetry()
                }
            }
        }

        operationManager.enqueue(operations: [removalOperation], in: .normal)
    }

    private func proccessRemovalOperation(result: OperationResult<Bool>) {
        switch result {
        case .success:
            completeVerification(success: false)
        case .error:
            scheduleVerificationRetry()
        }
    }

    private func processVerification(result: OperationResult<UserData>?) {
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
        case .error(let error):
            self.logger?.warning("Identity verification completed with \(error)")

            if let interatorError = error as? StartupInteractorError, interatorError == .verificationFailed {
                removeIdentityAndFailVerification()
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

        guard let service = config.defaultProjectUnit.service(for: ProjectServiceType.customer.rawValue) else {
            scheduleVerificationRetry()
            return
        }

        let identityUpdateOperation = performIdentityUpdateOperation(for: decentralizedId)

        performRegistrationCheckOperation(for: service.serviceEndpoint,
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
