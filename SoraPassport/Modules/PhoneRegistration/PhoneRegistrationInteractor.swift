import UIKit
import SoraKeystore
import RobinHood

final class PhoneRegistrationInteractor {
    weak var presenter: PhoneRegistrationInteractorOutputProtocol!

    let accountService: ProjectUnitAccountProtocol

    private(set) var settings: SettingsManagerProtocol

    init(accountService: ProjectUnitAccountProtocol, settings: SettingsManagerProtocol) {
        self.accountService = accountService
        self.settings = settings
    }

    private func handleCustomerCreation(result: Result<VerificationCodeData, Error>) {
        switch result {
        case .success(let verificationCodeData):
            updateVerificationState(from: verificationCodeData)
            presenter?.didCreateCustomer()
        case .failure(let error):
            presenter?.didReceiveCustomerCreation(error: error)
        }
    }

    private func updateVerificationState(from data: VerificationCodeData) {
        var verificationState = settings.verificationState ?? VerificationState()

        if let delay = data.delay {
            verificationState.didPerformAttempt(with: TimeInterval(delay))
        }

        settings.verificationState = verificationState
    }
}

extension PhoneRegistrationInteractor: PhoneRegistrationInteractorInputProtocol {
    func createCustomer(with info: UserCreationInfo) {
        do {
            _ = try accountService.createCustomer(with: info, runCompletionIn: .main) { [weak self] (optionalResult) in
                if let result = optionalResult {
                    self?.handleCustomerCreation(result: result)
                }
            }
        } catch {
            presenter?.didReceiveCustomerCreation(error: error)
        }
    }
}
