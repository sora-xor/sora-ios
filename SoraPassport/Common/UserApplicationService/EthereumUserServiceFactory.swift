import Foundation
import SoraKeystore
import SoraCrypto
import SoraFoundation
import IrohaCommunication
import RobinHood

struct EthereumUserServiceFactory {
    private func createRegistrationService() -> EthereumUserService? {
        let logger = Logger.shared

        do {
            let config: ApplicationConfigProtocol = ApplicationConfig.shared
            let keychain = Keychain()
            let userStoreFacade = UserStoreFacade.shared
            let operationManager = OperationManagerFacade.sharedManager

            guard let requestSigner = DARequestSigner.createDefault(with: logger) else {
                return nil
            }

            let primitiveFactory = WalletPrimitiveFactory(keychain: keychain,
                                                          settings: SettingsManager.shared,
                                                          localizationManager: LocalizationManager.shared)

            let publicKey = try primitiveFactory.createOperationSettings().publicKey
            let accountIdString = try primitiveFactory.createAccountId()
            let accountId = try IRAccountIdFactory.account(withIdentifier: accountIdString)

            let signer = IRSigningDecorator(keystore: keychain,
                                            identifier: KeystoreKey.privateKey.rawValue)

            let registrationFactory = try EthereumRegistrationFactory(signer: signer,
                                                                      publicKey: publicKey,
                                                                      sender: accountId)

            let mapper = SidechainInitDataMapper<EthereumInitUserInfo>()
            let repository: CoreDataRepository<EthereumInit, CDSidechainInit> =
                userStoreFacade.createCoreDataCache(mapper: AnyCoreDataMapper(mapper))

            let observer = CoreDataContextObservable<EthereumInit, CDSidechainInit>(
                service: userStoreFacade.databaseService,
                mapper: AnyCoreDataMapper(mapper),
                predicate: { _ in true })

            observer.start { error in
                if let error = error {
                    logger.error("Can't start observer: \(error)")
                }
            }

            return EthereumUserService(registrationFactory: registrationFactory,
                                       serviceUnit: config.defaultWalletUnit,
                                       requestSigner: requestSigner,
                                       repository: AnyDataProviderRepository(repository),
                                       repositoryObserver: observer,
                                       operationManager: operationManager,
                                       keystore: keychain,
                                       logger: logger)
        } catch {
            logger.error("Can't create registration service: \(error)")
            return nil
        }
    }
}

extension EthereumUserServiceFactory: UserApplicationServiceFactoryProtocol {
    func createServices() -> [UserApplicationServiceProtocol] {
        if let registrationService = createRegistrationService() {
            return [registrationService]
        } else {
            return []
        }
    }
}
