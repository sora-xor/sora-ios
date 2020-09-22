import Foundation
import RobinHood
import SoraKeystore

protocol OnboardingPreparationServiceProtocol {
    func prepare(using operationManager: OperationManagerProtocol) throws -> BaseOperation<SupportedVersionData>
}

final class OnboardingPreparationService {
    let invitationLinkService: InvitationLinkServiceProtocol
    let accountOperationFactory: ProjectAccountOperationFactoryProtocol
    let informationOperationFactory: ProjectInformationOperationFactoryProtocol
    let deviceInfoFactory: DeviceInfoFactoryProtocol
    let keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol
    let applicationConfig: ApplicationConfigProtocol

    init(accountOperationFactory: ProjectAccountOperationFactoryProtocol,
         informationOperationFactory: ProjectInformationOperationFactoryProtocol,
         invitationLinkService: InvitationLinkServiceProtocol,
         deviceInfoFactory: DeviceInfoFactoryProtocol,
         keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         applicationConfig: ApplicationConfigProtocol) {
        self.accountOperationFactory = accountOperationFactory
        self.informationOperationFactory = informationOperationFactory
        self.invitationLinkService = invitationLinkService
        self.deviceInfoFactory = deviceInfoFactory
        self.keystore = keystore
        self.settings = settings
        self.applicationConfig = applicationConfig
    }

    private func createVersionCheckOperation() throws -> BaseOperation<SupportedVersionData> {
        guard let service = applicationConfig.defaultProjectUnit
            .service(for: ProjectServiceType.supportedVersion.rawValue) else {
                throw NetworkUnitError.serviceUnavailable
        }

        let version = applicationConfig.version

        return informationOperationFactory.checkSupportedVersionOperation(service.serviceEndpoint,
                                                                          version: version)
    }

    private func createStateSetupOperation(
        dependingOn versionCheckOperation: BaseOperation<SupportedVersionData>) throws
        -> BaseOperation<SupportedVersionData> {
        let operation = ClosureOperation<SupportedVersionData> {
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
            case .failure(let error):
                throw error
            }
        }

        operation.addDependency(versionCheckOperation)

        return operation
    }

    private func createInvitationCheckOperationIfNeeded(
        dependingOn versionCheckOperation: BaseOperation<SupportedVersionData>) throws
        -> BaseOperation<InvitationCheckData>? {
        guard settings.isCheckedInvitation != true else {
            return nil
        }

        guard let serviceUnit = applicationConfig.defaultProjectUnit
            .service(for: ProjectServiceType.checkInvitation.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let deviceInfo = deviceInfoFactory.createDeviceInfo()

        let operation = accountOperationFactory.checkInvitation(serviceUnit.serviceEndpoint,
                                                                deviceInfo: deviceInfo)

        operation.configurationBlock = {
            guard let result = versionCheckOperation.result else {
                operation.cancel()
                return
            }

            switch result {
            case .success(let data):
                if !data.supported {
                    operation.cancel()
                }
            case .failure(let error):
                operation.result = .failure(error)
            }
        }

        operation.completionBlock = {
            DispatchQueue.main.async {
                self.processCheckInvitation(result: operation.result)
            }
        }

        operation.addDependency(versionCheckOperation)

        return operation
    }

    private func processCheckInvitation(result: Result<InvitationCheckData, Error>?) {
        guard let result = result else {
            return
        }

        switch result {
        case .success(let data):
            if let code = data.code {
                invitationLinkService.save(code: code)
            }

            settings.isCheckedInvitation = true

        case .failure(let error):
            if error is InvitationCheckDataError {
                settings.isCheckedInvitation = true
            }
        }
    }
}

extension OnboardingPreparationService: OnboardingPreparationServiceProtocol {
    func prepare(using operationManager: OperationManagerProtocol) throws -> BaseOperation<SupportedVersionData> {
        let versionCheckOperation = try createVersionCheckOperation()
        let stateOperation = try createStateSetupOperation(dependingOn: versionCheckOperation)

        if let invitationOperation = try createInvitationCheckOperationIfNeeded(dependingOn: stateOperation) {
            operationManager.enqueue(operations: [versionCheckOperation,
                                                  stateOperation,
                                                  invitationOperation],
                                     in: .transient)
        } else {
            operationManager.enqueue(operations: [versionCheckOperation, stateOperation],
                                     in: .transient)
        }

        return stateOperation
    }
}
