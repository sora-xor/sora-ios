import Foundation
import SoraKeystore
import SoraCrypto
import IrohaCrypto
import RobinHood
import SoraFoundation

final class AccessRestoreInteractor {
    weak var presenter: AccessRestoreInteractorOutputProtocol?

    var logger: LoggerProtocol?

    private(set) var identityLocalOperationFactory: IdentityOperationFactoryProtocol
    private(set) var accountOperationFactory: ProjectAccountOperationFactoryProtocol
    private(set) var keystore: KeystoreProtocol
    private(set) var operationManager: OperationManagerProtocol
    private(set) var settings: SettingsManagerProtocol
    private(set) var applicationConfig: ApplicationConfigProtocol
    private(set) var mnemonicCreator: IRMnemonicCreatorProtocol
    private(set) var invitationLinkService: InvitationLinkServiceProtocol

    private(set) var restoreOperation: Operation?

    private var restoredDocument: DecentralizedDocumentObject?

    init(identityLocalOperationFactory: IdentityOperationFactoryProtocol,
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
                        operation.result = .failure(AccessRestoreInteractorError.documentSignerCreationFailed)
                    }

                    self.logger?.debug("Start checking customer registration")

                case .failure(let error):
                    self.logger?.warning("Document object generation failed with \(error)")

                    operation.result = .failure(error)
                }
            }

            operation.addDependency(identityOperation)

            return operation
    }

    private func createIdentityCopyOperation(for oldKeystore: KeystoreProtocol,
                                             newKeystore: KeystoreProtocol,
                                             dependingOn customerOperation: NetworkOperation<UserData?>)
        -> IdentityCopyOperation {
        let operation = identityLocalOperationFactory.createCopyingOperation(oldKeystore: oldKeystore,
                                                                             newKeystore: newKeystore)

        operation.configurationBlock = {
            guard let result = customerOperation.result else {
                self.logger?.warning("Customer operation unexpectedly cancelled...")

                operation.cancel()
                return
            }

            switch result {
            case .success(let userData):
                if userData == nil {
                    self.logger?.error("User is missing")
                    operation.result = .failure(AccessRestoreInteractorError.userMissing)
                }
            case .failure(let error):
                self.logger?.warning("Identity copy operation failed with \(error)")

                operation.result = .failure(error)
            }
        }

        operation.addDependency(customerOperation)

        return operation
    }

    private func completeRestoration(with result: Result<Void, Error>,
                                     mnemonic: String) {

        switch result {
        case .success:

            guard let document = restoredDocument else {
                logger?.error("Generated document is missing")

                presenter?.didReceiveRestoreAccess(error: AccessRestoreInteractorError.documentMissing)
                return
            }

            logger?.debug("Restoration successfully completed")

            settings.decentralizedId = document.decentralizedId
            settings.publicKeyId = document.publicKey.first?.pubKeyId
            settings.verificationState = nil

            invitationLinkService.clear()

            presenter?.didRestoreAccess(from: mnemonic)

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
    func restoreAccess(mnemonic: String) {
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

            let mnemonicRepresentation = try mnemonicCreator.mnemonic(fromList: mnemonic)

            let restorationKeystore = InMemoryKeychain()

            let identityRestoreOperation = identityLocalOperationFactory
                .createRestorationOperation(with: mnemonicRepresentation,
                                            keystore: restorationKeystore)

            let customerOperation = createCustormerCheck(with: service.serviceEndpoint,
                                                         dependingOn: identityRestoreOperation)

            let identityCopyOperation = createIdentityCopyOperation(for: restorationKeystore,
                                                                    newKeystore: self.keystore,
                                                                    dependingOn: customerOperation)

            restoreOperation = identityCopyOperation

            identityCopyOperation.completionBlock = {
                DispatchQueue.main.async {
                    self.restoreOperation = nil

                    if let result = identityCopyOperation.result {
                        self.completeRestoration(with: result, mnemonic: mnemonic)
                    }
                }
            }

            logger?.debug("Start access restoration")

            operationManager.enqueue(operations: [identityRestoreOperation, customerOperation, identityCopyOperation],
                                     in: .transient)
        } catch {
            presenter?.didReceiveRestoreAccess(error: error)
        }
    }
}
