import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import FearlessUtils

protocol ServiceCoordinatorProtocol: ApplicationServiceProtocol {
    func updateOnAccountChange()
    func updateOnNetworkChange()
    func checkMigration()
}

final class ServiceCoordinator {
    let webSocketService: WebSocketServiceProtocol
    let runtimeService: RuntimeRegistryServiceProtocol
    let migrationService: MigrationServiceProtocol
    let settings: SettingsManagerProtocol

    init(webSocketService: WebSocketServiceProtocol,
         runtimeService: RuntimeRegistryServiceProtocol,
         migrationService: MigrationServiceProtocol,
         settings: SettingsManagerProtocol) {
        self.webSocketService = webSocketService
        self.runtimeService = runtimeService
        self.migrationService = migrationService
        self.settings = settings
    }

    private func updateWebSocketSettings() {
        let connectionItem = settings.selectedConnection
        let account = settings.selectedAccount

        let settings = WebSocketServiceSettings(url: connectionItem.url,
                                                addressType: connectionItem.type,
                                                address: account?.address)
        webSocketService.update(settings: settings)
    }

    private func updateRuntimeService() {
        let connectionItem = settings.selectedConnection
        runtimeService.update(to: connectionItem.type.chain, forced: false)
    }

    private func updateValidatorService() {
//        if let engine = webSocketService.connection {
//            let chain = settings.selectedConnection.type.chain
//            validatorService.update(to: chain, engine: engine)
//        }
    }

    private func updateRewardCalculatorService() {
//        let chain = settings.selectedConnection.type.chain
//        rewardCalculatorService.update(to: chain)
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnAccountChange() {
        updateWebSocketSettings()
        updateRuntimeService()
        updateValidatorService()
        updateRewardCalculatorService()
    }

    func updateOnNetworkChange() {
        updateWebSocketSettings()
        updateRuntimeService()
        updateValidatorService()
        updateRewardCalculatorService()
    }

    func setup() {
        webSocketService.setup()
        runtimeService.setup()
    }

    func throttle() {
        webSocketService.throttle()
        runtimeService.throttle()
    }

    func checkMigration() {
        self.migrationService.checkMigration()
    }
}

extension ServiceCoordinator {
    static func createDefault() -> ServiceCoordinatorProtocol {
        let webSocketService = WebSocketServiceFactory.createService()
        let runtimeService = RuntimeRegistryFacade.sharedService
        let migrationService = MigrationService(eventCenter: EventCenter.shared,
                                                keystore: Keychain(),
                                                settings: SettingsManager.shared,
                                                webSocketService: webSocketService,
                                                runtimeService: RuntimeRegistryFacade.sharedService,
                                                operationManager: OperationManagerFacade.sharedManager,
                                                logger: Logger.shared)

        return ServiceCoordinator(webSocketService: webSocketService,
                                  runtimeService: runtimeService,
                                  migrationService: migrationService,
                                  settings: SettingsManager.shared)
    }
}
