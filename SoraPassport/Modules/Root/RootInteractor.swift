import Foundation
import SoraKeystore
import IrohaCrypto

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    var settings: SettingsManagerProtocol
    var keystore: KeystoreProtocol
    let migrators: [Migrating]
    var securityLayerInteractor: SecurityLayerInteractorInputProtocol
    var networkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol?

    init(settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         migrators: [Migrating],
         securityLayerInteractor: SecurityLayerInteractorInputProtocol,
         networkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol?) {
        self.settings = settings
        self.keystore = keystore
        self.migrators = migrators
        self.securityLayerInteractor = securityLayerInteractor
        self.networkAvailabilityLayerInteractor = networkAvailabilityLayerInteractor
        checkLegacyUpdate()
    }

    private func configureSecurityService() {
        securityLayerInteractor.setup()
    }

    private func configureDeepLinkService() {
        let invitationLinkService = InvitationLinkService(settings: settings)
        DeepLinkService.shared.setup(children: [invitationLinkService])
    }

    private func configureNetworkAvailabilityService() {
        networkAvailabilityLayerInteractor?.setup()
    }

    private func setupURLHandlingService() {
        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

//        let callbackUrl = applicationConfig.purchaseRedirect
//        let purchaseHandler = PurchaseCompletionHandler(callbackUrl: callbackUrl,
//                                                        eventCenter: eventCenter)

        URLHandlingService.shared.setup(children: [/*purchaseHandler,*/ keystoreImportService])
    }

    var legacyImportInteractor: AccountImportInteractorInputProtocol?

    private func checkLegacyUpdate() {
        if let legacySeed = try? keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue),
           let mnemonic = try? IRMnemonicCreator(language: .english).mnemonic(fromEntropy: legacySeed),
           let importInteractor = AccountImportViewFactory.createSilentImportInteractor() {

            let username = settings.string(for: KeystoreTag.legacyUsername.rawValue) ?? ""
            let request = AccountImportMnemonicRequest(mnemonic: mnemonic.toString(),
                                                       username: username,
                                                       networkType: .sora,
                                                       derivationPath: "",
                                                       cryptoType: .sr25519)
            legacyImportInteractor = importInteractor
            importInteractor.importAccountWithMnemonic(request: request)
        }
    }
}

extension RootInteractor: RootInteractorInputProtocol {
    func decideModuleSynchroniously() {
        do {
            if !settings.hasSelectedAccount {
                try keystore.deleteKeyIfExists(for: KeystoreTag.pincode.rawValue)

                presenter?.didDecideOnboarding()
                return
            } else {
                try? keystore.deleteKeyIfExists(for: KeystoreTag.legacyEntropy.rawValue)
            }

            let pincodeExists = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)

            if pincodeExists {
                presenter?.didDecideLocalAuthentication()
            } else {
                presenter?.didDecidePincodeSetup()
            }

        } catch {
            presenter?.didDecideBroken()
        }
    }

    private func runMigrators() {
        migrators.forEach { migrator in
            do {
                try migrator.migrate()
            } catch {
                Logger.shared.error(error.localizedDescription)
            }
        }
    }

    func setup() {
        setupURLHandlingService()
        configureSecurityService()
        configureNetworkAvailabilityService()
        configureDeepLinkService()
        runMigrators()
    }
}
