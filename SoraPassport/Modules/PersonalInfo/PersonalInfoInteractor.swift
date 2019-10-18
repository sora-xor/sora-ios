/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import IrohaCrypto
import RobinHood

final class PersonalInfoInteractor {
    weak var presenter: PersonalInfoInteractorOutputProtocol?

    let registrationService: ProjectUnitServiceProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    let keystore: KeystoreProtocol
    let invitationLinkService: InvitationLinkServiceProtocol

    private var registrationOperation: Operation?

    init(registrationService: ProjectUnitServiceProtocol,
         settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         invitationLinkService: InvitationLinkServiceProtocol) {
        self.registrationService = registrationService
        self.settingsManager = settings
        self.keystore = keystore
        self.invitationLinkService = invitationLinkService
    }

    private func register(_ serviceEndpoint: String, form: PersonalForm) throws {
        let info = RegistrationInfo.create(with: form)
        let registrationOperation = try registrationService
            .registerCustomer(with: info, runCompletionIn: .main) { [weak self] optionalResult in
                if let result = optionalResult {
                    self?.registrationOperation = nil

                    self?.process(result: result, for: form)
                }
        }

        self.registrationOperation = registrationOperation
    }

    private func process(result: OperationResult<Bool>, for form: PersonalForm) {
        switch result {
        case .success:
            completeRegistration(for: form)
        case .error(let error):
            presenter?.didReceiveRegistration(error: error)
        }
    }

    private func completeRegistration(for form: PersonalForm) {
        settingsManager.verificationState = nil

        invitationLinkService.clear()
        invitationLinkService.remove(observer: self)

        presenter?.didCompleteRegistration(with: form)
    }
}

extension PersonalInfoInteractor: PersonalInfoInteractorInputProtocol {
    func load() {
        invitationLinkService.add(observer: self)

        guard let invitationCode = invitationLinkService.link?.code else {
            return
        }

        presenter?.didReceive(invitationCode: invitationCode)
    }

    func register(with form: PersonalForm) {
        guard registrationOperation == nil else {
            return
        }

        do {
            presenter?.didStartRegistration(with: form)

            guard let service = ApplicationConfig.shared.defaultProjectUnit
                .service(for: ProjectServiceType.register.rawValue) else {
                    presenter?.didReceiveRegistration(error: NetworkUnitError.serviceUnavailable)
                    return
            }

            try register(service.serviceEndpoint, form: form)
        } catch {
            presenter?.didReceiveRegistration(error: error)
        }
    }
}

extension PersonalInfoInteractor: InvitationLinkObserver {
    func didUpdateInvitationLink(from oldLink: InvitationDeepLink?) {
        if let code = invitationLinkService.link?.code {
            presenter?.didReceive(invitationCode: code)
        }
    }
}
