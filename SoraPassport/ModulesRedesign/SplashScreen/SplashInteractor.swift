import Foundation
import SoraKeystore
import FearlessUtils

typealias RuntimeServiceProtocol = RuntimeRegistryServiceProtocol & RuntimeCodingServiceProtocol

final class SplashInteractor: SplashInteractorProtocol {
    weak var presenter: SplashPresenterProtocol!
    let settings: SettingsManagerProtocol
    let socketService: WebSocketServiceProtocol
    let configService: ConfigServiceProtocol

    init(settings: SettingsManagerProtocol,
         socketService: WebSocketServiceProtocol,
         configService: ConfigServiceProtocol) {
        self.settings = settings
        self.socketService = socketService
        self.configService = configService
    }

    func setup() {
        configService.setupConfig { [weak self] in
            self?.socketService.setup()
            self?.loadGenesis()
        }
    }

    private func loadGenesis() {
        let provider = GenesisProvider(engine: socketService.connection!)
        provider.load(completion: { [weak self] genesis in
            self?.didLoadGenesis(genesis)
        })
    }

    private func didLoadGenesis(_ genesis: String?) {
        if let genesis = genesis {
            self.settings.set(value: genesis, for: SettingsKey.externalGenesis.rawValue)
            Logger.shared.info("Runtime update gen: " + genesis)
        }
        loadAssetsInfo(chainId: genesis)
    }

    private func loadAssetsInfo(chainId: String?) {
        let provider = AssetsInfoProvider(engine: socketService.connection!, storageKeyFactory: StorageKeyFactory(), chainId: chainId)
        provider.load { [weak self] assetsInfo in
            self?.didLoadAssetsInfo(assetsInfo)
        }
    }

    private func didLoadAssetsInfo(_ assetsInfo: [AssetInfo]) {
        AssetManager.networkAssets = assetsInfo

        socketService.throttle()

        DispatchQueue.main.async {
            self.startChain()
        }
    }

    private func startChain() {
        let dbMigrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: UserStorageParams.storageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: Keychain(),
            settings: settings,
            fileManager: FileManager.default
        )
        let logger = Logger.shared
//it should not be here, but since we're trying to limit chain sync to the splash screen, we need working settings and have to migrate them because robinhood does not support lightweight migration (yet?)
        do {
            try dbMigrator.migrate()
        } catch {
            logger.error(error.localizedDescription)
        }

        let settings = SelectedWalletSettings.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        settings.setup(runningCompletionIn: .main) { result in
            switch result {
            case let .success(maybeAccount):
                if let metaAccount = maybeAccount {
                    chainRegistry.performHotBoot()
                    logger.debug("Selected account: \(metaAccount.address)")
                } else {
                    chainRegistry.performColdBoot()
                    logger.debug("No selected account")
                }
            case let .failure(error):
                logger.error("Selected account setup failed: \(error)")
            }
        }

        self.presenter.setupComplete()
    }
}
