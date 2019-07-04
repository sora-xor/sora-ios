/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import IrohaCrypto
import RobinHood

private typealias IdentityOperationList = (creation: IdentityCreationOperation,
    submition: NetworkOperation<Bool>, save: BaseOperation<Bool>)

final class PersonalInfoInteractor {
    weak var presenter: PersonalInfoInteractorOutputProtocol?

    private(set) var projectOperationFactory: ProjectAccountOperationFactoryProtocol
    private(set) var identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol
    private(set) var identityLocalOperationFactory: IdentityOperationFactoryProtocol.Type

    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var keystore: KeystoreProtocol
    private(set) var applicationConfig: ApplicationConfigProtocol
    private(set) var operationManager: OperationManagerProtocol

    private var registrationOperation: Operation?

    init(projectOperationFactory: ProjectAccountOperationFactoryProtocol,
         identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol,
         identityLocalOperationFactory: IdentityOperationFactoryProtocol.Type,
         settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         applicationConfig: ApplicationConfigProtocol,
         operationManager: OperationManagerProtocol) {
        self.projectOperationFactory = projectOperationFactory
        self.identityNetworkOperationFactory = identityNetworkOperationFactory
        self.identityLocalOperationFactory = identityLocalOperationFactory
        self.settingsManager = settings
        self.keystore = keystore
        self.applicationConfig = applicationConfig
        self.operationManager = operationManager
    }

    private func createNewIdentity() -> IdentityOperationList {

        let identityCreationOperation = identityLocalOperationFactory.createNewIdentityOperation()

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

        let saveOperation = BaseOperation<Bool>()
        saveOperation.configurationBlock = {
            guard let submitionResult = identitySubmitOperation.result else {
                saveOperation.cancel()
                return
            }

            switch submitionResult {
            case .error(let error):
                saveOperation.result = .error(error)
                return
            default:
                break
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

            do {
                try self.keystore.deleteKeyIfExists(for: KeystoreKey.pincode.rawValue)

                self.settingsManager.decentralizedId = document.decentralizedId
                self.settingsManager.publicKeyId = publicKeyId
                self.settingsManager.verificationState = VerificationState()

                saveOperation.result = .success(true)
            } catch {
                saveOperation.result = .error(error)
            }
        }

        saveOperation.addDependency(identitySubmitOperation)

        operationManager.enqueue(operations: [identityCreationOperation, identitySubmitOperation, saveOperation],
                                 in: .normal)

        return (creation: identityCreationOperation, submition: identitySubmitOperation, save: saveOperation)
    }

    private func register(_ serviceEndpoint: String, info: RegistrationInfo, dependencies: IdentityOperationList?) {

        let registrationOperation = projectOperationFactory.registrationOperation(serviceEndpoint, with: info)
        registrationOperation.configurationBlock = {
            if let saveOperation = dependencies?.save {
                guard let saveResult = saveOperation.result else {
                    registrationOperation.cancel()
                    return
                }

                switch saveResult {
                case .error(let error):
                    registrationOperation.result = .error(error)
                    return
                default:
                    break
                }
            }

            if let requestSigner = DARequestSigner.createDefault() {
                registrationOperation.requestModifier = requestSigner
            } else {
                registrationOperation.result = .error(DARequestSignerError.signatureCreationFailed)
            }
        }

        self.registrationOperation = registrationOperation

        if let saveOperation = dependencies?.save {
            registrationOperation.addDependency(saveOperation)
        }

        registrationOperation.completionBlock = {
            DispatchQueue.main.async {
                self.registrationOperation = nil

                guard let result = registrationOperation.result else {
                    return
                }

                self.process(result: result, for: info)
            }
        }

        operationManager.enqueue(operations: [registrationOperation], in: .normal)
    }

    private func process(result: OperationResult<Bool>, for info: RegistrationInfo) {
        switch result {
        case .success:
            self.presenter?.didCompleteRegistration(with: info)
        case .error(let error):
            self.presenter?.didReceiveRegistration(error: error)
        }
    }
}

extension PersonalInfoInteractor: PersonalInfoInteractorInputProtocol {
    var isBusy: Bool {
        return registrationOperation != nil
    }

    func register(with applicationForm: ApplicationFormInfo, invitationCode: String) {
        if isBusy {
            return
        }

        let registrationInfo = RegistrationInfo(applicationForm: applicationForm,
                                                invitationCode: invitationCode)

        presenter?.didStartRegistration(with: registrationInfo)

        guard let service = ApplicationConfig.shared.defaultProjectUnit
            .service(for: ProjectServiceType.register.rawValue) else {
                presenter?.didReceiveRegistration(error: NetworkUnitError.serviceUnavailable)
                return
        }

        var identityOperationList: IdentityOperationList?

        if settingsManager.decentralizedId == nil {
            identityOperationList = createNewIdentity()
        }

        register(service.serviceEndpoint, info: registrationInfo, dependencies: identityOperationList)
    }
}
