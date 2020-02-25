/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import IrohaCrypto
import RobinHood
import SoraFoundation

final class AccessRestoreInteractor {
    weak var presenter: AccessRestoreInteractorOutputProtocol?

    var logger: LoggerProtocol?

    private(set) var identityLocalOperationFactory: IdentityOperationFactoryProtocol.Type
    private(set) var accountOperationFactory: ProjectAccountOperationFactoryProtocol
    private(set) var keystore: KeystoreProtocol
    private(set) var operationManager: OperationManagerProtocol
    private(set) var settings: SettingsManagerProtocol
    private(set) var applicationConfig: ApplicationConfigProtocol
    private(set) var mnemonicCreator: IRMnemonicCreatorProtocol
    private(set) var invitationLinkService: InvitationLinkServiceProtocol

    private(set) var restoreOperation: Operation?

    private var restoreKeystore: KeystoreProtocol?
    private var restoredDocument: DecentralizedDocumentObject?

    init(identityLocalOperationFactory: IdentityOperationFactoryProtocol.Type,
         accountOperationFactory: ProjectAccountOperationFactoryProtocol,
         keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         applicationConfig: ApplicationConfigProtocol,
         mnemonicCreator: IRMnemonicCreatorProtocol,
         invitationLinkService: InvitationLinkServiceProtocol,
         operationManager: OperationManagerProtocol) {
        self.identityLocalOperationFactory = identityLocalOperationFactory
        self.accountOperationFactory = accountOperationFactory
        self.keystore = keystore
        self.settings = settings
        self.applicationConfig = applicationConfig
        self.mnemonicCreator = mnemonicCreator
        self.invitationLinkService = invitationLinkService
        self.operationManager = operationManager
    }

    private func createIdentityRestorationOperation(mnemonic: IRMnemonicProtocol) -> IdentityRestorationOperation {

            let restoreKeystore = InMemoryKeychain()
            self.restoreKeystore = restoreKeystore

            let operation = identityLocalOperationFactory.createRestorationOperation(with: mnemonic,
                                                                                     keystore: restoreKeystore)
            return operation
    }

    private func createCustormerCheck(with endpoint: String,
                                      dependingOn identityOperation: IdentityRestorationOperation)
        -> NetworkOperation<UserData?> {
            let operation = accountOperationFactory.fetchCustomerOperation(endpoint)

            operation.configurationBlock = {
                guard let result = identityOperation.result else {
                    self.logger?.warning("Document object generation unexpectedly cancelled...")

                    operation.cancel()
                    return
                }

                switch result {
                case .success(let document):
                    self.restoredDocument = document

                    let rawSigner = IRSigningDecorator(keystore: identityOperation.keystore,
                                                       identifier: KeystoreKey.privateKey.rawValue)
                    if let requestSigner = DARequestSigner.createFrom(document: document, rawSigner: rawSigner) {
                        operation.requestModifier = requestSigner
                    } else {
                        operation.result = .failure(DARequestSignerError.signatureCreationFailed)
                    }

                    self.logger?.debug("Start checking customer registration")

                case .failure(let error):
                    self.logger?.warning("Document object generation failed with \(error)")

                    operation.result = .failure(error)
                    return
                }
            }

            operation.addDependency(identityOperation)

            return operation
    }

    private func completeRestoration(with result: Result<UserData?, Error>,
                                     phrase: [String]) {

        switch result {
        case .success(let userData):
            guard let userData = userData else {
                logger?.error("User is missing")

                presenter?.didReceiveRestoreAccess(error: AccessRestoreInteractorError.userMissing)
                return
            }

            logger?.debug("Customer check successfully completed for \(userData.userId)")

            guard let document = restoredDocument else {
                logger?.error("Generated document is missing")

                presenter?.didReceiveRestoreAccess(error: AccessRestoreInteractorError.documentMissing)
                return
            }

            guard let restoreKeystore = restoreKeystore else {
                logger?.error("Restore keystore missing")

                presenter?.didReceiveRestoreAccess(error: AccessRestoreInteractorError.keystoreMissing)
                return
            }

            do {
                let newPrivateKeyData = try restoreKeystore.fetchKey(for: KeystoreKey.privateKey.rawValue)
                let seedData = try restoreKeystore.fetchKey(for: KeystoreKey.seedEntropy.rawValue)

                try keystore.saveKey(newPrivateKeyData, with: KeystoreKey.privateKey.rawValue)
                try keystore.saveKey(seedData, with: KeystoreKey.seedEntropy.rawValue)

                settings.decentralizedId = document.decentralizedId
                settings.publicKeyId = document.publicKey.first?.pubKeyId
                settings.verificationState = nil

                invitationLinkService.clear()

                presenter?.didRestoreAccess(from: phrase)
            } catch {
                presenter?.didReceiveRestoreAccess(error: error)
            }

        case .failure(let error):
            self.logger?.error("Access restoration failed with \(error)")

            if let networkError = error as? NetworkResponseError, networkError == .authorizationError {
                presenter?.didReceiveRestoreAccess(error: AccessRestoreInteractorError.invalidPassphrase)
            } else {
                presenter?.didReceiveRestoreAccess(error: error)
            }
        }
    }
}

extension AccessRestoreInteractor: AccessRestoreInteractorInputProtocol {
    func restoreAccess(phrase: [String]) {
        guard restoreOperation == nil else {
            logger?.warning("Restoration already in progress")
            return
        }

        do {
            guard let service = applicationConfig.defaultProjectUnit
                .service(for: ProjectServiceType.customer.rawValue) else {
                presenter?.didReceiveRestoreAccess(error: NetworkUnitError.serviceUnavailable)
                return
            }

            let mnemonic = try mnemonicCreator.mnemonic(fromList: phrase)

            let identityRestoreOperation = createIdentityRestorationOperation(mnemonic: mnemonic)
            let customerOperation = createCustormerCheck(with: service.serviceEndpoint,
                                                         dependingOn: identityRestoreOperation)

            restoreOperation = customerOperation

            customerOperation.completionBlock = {
                DispatchQueue.main.async {
                    self.restoreOperation = nil

                    if let result = customerOperation.result {
                        self.completeRestoration(with: result, phrase: phrase)
                    }

                    self.restoreKeystore = nil
                }
            }

            logger?.debug("Start access restoration")

            operationManager.enqueue(operations: [identityRestoreOperation, customerOperation], in: .normal)
        } catch {
            presenter?.didReceiveRestoreAccess(error: error)
        }
    }
}
