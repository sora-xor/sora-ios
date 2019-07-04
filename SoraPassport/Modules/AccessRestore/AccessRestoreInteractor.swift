/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import IrohaCrypto
import RobinHood

final class AccessRestoreInteractor {
    weak var presenter: AccessRestoreInteractorOutputProtocol?

    var logger: LoggerProtocol?

    private(set) var accountOperationFactory: ProjectAccountOperationFactoryProtocol
    private(set) var identityLocalOperationFactory: IdentityOperationFactoryProtocol.Type
    private(set) var keystore: KeystoreProtocol
    private(set) var operationManager: OperationManagerProtocol
    private(set) var applicationConfig: ApplicationConfigProtocol
    private(set) var settings: SettingsManagerProtocol
    private(set) var mnemonicCreator: IRMnemonicCreatorProtocol

    private(set) var restoredDocument: DecentralizedDocumentObject?

    init(accountOperationFactory: ProjectAccountOperationFactoryProtocol,
         identityLocalOperationFactory: IdentityOperationFactoryProtocol.Type,
         keystore: KeystoreProtocol,
         operationManager: OperationManagerProtocol,
         applicationConfig: ApplicationConfigProtocol,
         settings: SettingsManagerProtocol,
         mnemonicCreator: IRMnemonicCreatorProtocol) {
        self.accountOperationFactory = accountOperationFactory
        self.identityLocalOperationFactory = identityLocalOperationFactory
        self.keystore = keystore
        self.operationManager = operationManager
        self.applicationConfig = applicationConfig
        self.settings = settings
        self.mnemonicCreator = mnemonicCreator
    }

    private func createCustormerCheck(with endpoint: String,
                                      dependingOn identityOperation: IdentityRestorationOperation)
        -> NetworkOperation<UserData> {
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

                let rawSigner = IRSigningDecorator(keystore: self.keystore, identifier: KeystoreKey.privateKey.rawValue)
                if let requestSigner = DARequestSigner.createFrom(document: document, rawSigner: rawSigner) {
                    operation.requestModifier = requestSigner
                } else {
                    operation.result = .error(DARequestSignerError.signatureCreationFailed)
                }

                self.logger?.debug("Start checking customer registration")

            case .error(let error):
                self.logger?.warning("Document object generation failed with \(error)")

                operation.result = .error(error)
                return
            }
        }

        operation.addDependency(identityOperation)

        return operation
    }

    private func processCustomer(result: OperationResult<UserData>, for phrase: [String]) {
        switch result {
        case .success(let userData):
            logger?.debug("Customer check successfully completed for \(userData.userId)")

            guard let document = restoredDocument else {
                logger?.error("Generated document unexpectedly is missing")

                presenter?.didReceiveRestoreAccess(error: AccessRestoreInteractorError.documentMissing)
                return
            }

            do {
                try keystore.deleteKeyIfExists(for: KeystoreKey.pincode.rawValue)

                settings.decentralizedId = document.decentralizedId
                settings.publicKeyId = document.publicKey.first?.pubKeyId
                settings.verificationState = nil

                presenter?.didRestoreAccess(from: phrase)
            } catch {
                presenter?.didReceiveRestoreAccess(error: error)
            }

        case .error(let error):
            self.logger?.error("Access restoration failed with \(error)")

            presenter?.didReceiveRestoreAccess(error: error)
        }
    }
}

extension AccessRestoreInteractor: AccessRestoreInteractorInputProtocol {
    func restoreAccess(phrase: [String]) {
        let projectUnit = applicationConfig.defaultProjectUnit

        guard let customerService = projectUnit.service(for: ProjectServiceType.customer.rawValue) else {
            presenter?.didReceiveRestoreAccess(error: NetworkUnitError.serviceUnavailable)
            return
        }

        do {
            let mnemonic = try mnemonicCreator.mnemonic(fromList: phrase)

            let identityRestoreOperation = identityLocalOperationFactory.createRestorationOperation(with: mnemonic)
            let customerCheckOperation = createCustormerCheck(with: customerService.serviceEndpoint,
                                                              dependingOn: identityRestoreOperation)

            customerCheckOperation.completionBlock = {
                DispatchQueue.main.async {
                    if let result = customerCheckOperation.result {
                        self.processCustomer(result: result, for: phrase)
                    }
                }
            }

            logger?.debug("Start access restoration")

            operationManager.enqueue(operations: [identityRestoreOperation, customerCheckOperation], in: .normal)
        } catch {
            presenter?.didReceiveRestoreAccess(error: error)
        }
    }
}
