import Foundation
import SoraKeystore
//import SoraCrypto
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
//    private(set) var identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol
//    private(set) var identityLocalOperationFactory: IdentityOperationFactoryProtocol
//    private(set) var accountOperationFactory: ProjectAccountOperationFactoryProtocol
//    private(set) var informationOperationFactory: ProjectInformationOperationFactoryProtocol
    private(set) var operationManager: OperationManagerProtocol
    private(set) var reachabilityManager: ReachabilityManagerProtocol?

    deinit {
        reachabilityManager?.remove(listener: self)
    }

    init(settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         config: ApplicationConfigProtocol,
//         identityNetworkOperationFactory: DecentralizedResolverOperationFactoryProtocol,
//         identityLocalOperationFactory: IdentityOperationFactoryProtocol,
//         accountOperationFactory: ProjectAccountOperationFactoryProtocol,
//         informationOperationFactory: ProjectInformationOperationFactoryProtocol,
         operationManager: OperationManagerProtocol,
         reachabilityManager: ReachabilityManagerProtocol?) {

        self.reachabilityManager = reachabilityManager
        self.settings = settings
        self.keystore = keystore
        self.config = config
//        self.identityNetworkOperationFactory = identityNetworkOperationFactory
//        self.identityLocalOperationFactory = identityLocalOperationFactory
//        self.accountOperationFactory = accountOperationFactory
//        self.informationOperationFactory = informationOperationFactory
        self.operationManager = operationManager

        try? reachabilityManager?.add(listener: self)
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

//            let service = ProjectUnitService()//unit: config.defaultProjectUnit)
//            try? service.fetchEthConfigOperation(runCompletionIn: .main) {[weak self] (result) in
//                switch result {
//                case .success(let data):
//                    self?.config.applyExternalConfig(data!)
//                case .none, .failure:
//                    let configError = ConfigError.ethConfigFailed
//                    self?.presenter?.didReceiveConfigError(configError)
//                }
//                self?.completeVerification(success: true)
//            }

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

//        guard
//            let customerService = config.defaultProjectUnit.service(for: ProjectServiceType.customer.rawValue),
//            let versionCheckService = config.defaultProjectUnit
//                .service(for: ProjectServiceType.supportedVersion.rawValue) else {
//            scheduleVerificationRetry()
//            return
//        }
//
//        let versionCheckOperation = performVersionCheckOperation(for: versionCheckService.serviceEndpoint)
//
//        let identityUpdateOperation = performIdentityUpdateOperation(for: decentralizedId,
//                                                                     dependingOn: versionCheckOperation)
//
//        performRegistrationCheckOperation(for: customerService.serviceEndpoint,
//                                          dependingOn: identityUpdateOperation) { [weak self] (optionalResult) in
//                                            self?.processVerification(result: optionalResult)
//        }
    }
}

extension StartupInteractor: ReachabilityListenerDelegate {
    func didChangeReachability(by manager: ReachabilityManagerProtocol) {
        retryVerificationIfPossible()
    }
}
