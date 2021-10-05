import Foundation
import SoraKeystore
import RobinHood
import IrohaCrypto
import FearlessUtils

typealias MigrationResultClosure = (Result<String, Error>) -> Void

enum MigrationServiceError: Error {
    case startMigrationFail
    case confirmMigrationFail
    case typeMappingMissing
}

protocol MigrationServiceProtocol {
    func checkMigration()
    func requestMigration(completion completionClosure: @escaping MigrationResultClosure)
}

class MigrationService: MigrationServiceProtocol {

    let webSocketService: WebSocketServiceProtocol
    private(set) var settings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    let runtimeRegistry: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol
    let keystore: KeystoreProtocol

    init(eventCenter: EventCenterProtocol,
         keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         webSocketService: WebSocketServiceProtocol,
         runtimeService: RuntimeCodingServiceProtocol,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.webSocketService = webSocketService
        self.settings = settings
        self.eventCenter = eventCenter
        self.logger = logger
        self.runtimeRegistry = runtimeService
        self.operationManager = operationManager
        self.keystore = keystore
        //
    }

    lazy var irohaKeyPair: IRCryptoKeypairProtocol? = {
//        let keystore = Keychain()
        if let address = settings.selectedAccount?.address,
            let entropy = try? keystore.fetchEntropyForAddress(address),
            let mnemonic = try? IRMnemonicCreator().mnemonic(fromEntropy: entropy),
            let irohaKey = try? IRKeypairFacade().deriveKeypair(from: mnemonic.toString()) {
            return irohaKey
        }
        return nil
    }()

    lazy var did: String = {
        "did_sora_\(irohaKeyPair?.publicKey().decentralizedUsername ?? "")@sora"
    }()

    func checkMigration() {
        if !settings.hasMigrated {
            _ = try? webSocketService.connection?.callMethod(RPCMethod.needsMigration,
                                                             params: [did],
                                                             completion: { [weak self] (result: Result<Bool, Error>) in
                switch result {
                case .success(let migrationNeeded):
                    self?.logger.info("migration needed \(migrationNeeded)")
                    if migrationNeeded {
                        DispatchQueue.main.async {
                            self?.decideMigration()
                        }
                    }
                case .failure(let error):
                    self?.logger.error("migration check fail, \(error)")
                }
            })
        }
    }

    private func decideMigration() {
        eventCenter.notify(with: MigrationEvent(service: self))
    }

    private func migrationSuccess() {
        settings.hasMigrated = true
        eventCenter.notify(with: MigrationSuccsessEvent(service: self))
    }

    func requestMigration(completion completionClosure: @escaping MigrationResultClosure) {
        guard let account = settings.selectedAccount else {
            logger.error("Migration account not found")
            return
        }
        guard let engine = webSocketService.connection else {
            logger.error("Migration connection not found")
            return
        }

        guard let irohaKeyPair = irohaKeyPair else {
            logger.error("IrohaKeyPair failed")
            return
        }

        let signer = SigningWrapper(keystore: self.keystore, settings: settings)
        let irohaSigner = IRSigningDecorator(keystore: self.keystore, identifier: "iroha")

        let extrinsicService = ExtrinsicService(address: account.address,
                                                cryptoType: account.cryptoType,
                                                runtimeRegistry: runtimeRegistry,
                                                engine: engine,
                                                operationManager: operationManager)

        let accountId = try? SS58AddressFactory().accountId(from: account.address).toHex(includePrefix: true)
        let extrinsicProcessor = ExtrinsicProcessor(accountId: accountId!)

        let irohaKey = irohaKeyPair.publicKey().rawData().toHex()
        let message = (self.did + irohaKey).data(using: .utf8)
        let data = try? NSData.init(data: message!).sha3(IRSha3Variant.variant256) //sha3 per backend request
        guard let signature = try? irohaSigner.sign(data!, privateKey: irohaKeyPair.privateKey()) else {
            logger.error("Migration signing fail")
            return
        }

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()
            let migrateCall = try callFactory.migrate(irohaAddress: self.did,
                                                      irohaKey: irohaKey,
                                                      signature: signature.rawData().toHex())
            return try builder.adding(call: migrateCall)
        }
        extrinsicService.submit(closure, signer: signer, watch: true, runningIn: .main) { [weak self] result, extrinsicHash in
            switch result {
            case .success(let hash):
                self?.logger.info("Did receive extrinsic hash: \(extrinsicHash), subscription \(hash)")
                let requestId = engine.generateIdentifier()

                let subscription = JSONRPCSubscription<JSONRPCSubscriptionUpdate<ExtrinsicStatus>>(requestId: requestId, requestData: Data(),
                                                                                                   requestOptions: JSONRPCOptions(resendOnReconnect: true)) { data in
                    self?.logger.info("extrinsic \(data.params.result)")
                    let state = data.params.result
                    switch state {
                    case .finalized(let block):
                        self?.logger.info("extrinsic finalized \(block)")
                        if let self = self {
                            DispatchQueue.main.async {
                                self.getBlockEvents(block,
                                                    extrinsicHash: extrinsicHash!,
                                                    extrinsicProcessor: extrinsicProcessor,
                                                    engine: engine,
                                                    coderOperation: self.runtimeRegistry.fetchCoderFactoryOperation(),
                                                    completion: completionClosure)
                            }
                        }
                    default:
                        self?.logger.info("extrinsic status \(state)")
                    }

                } failureClosure: { (error, _) in
                    self?.logger.error("Extrisinc status error: \(error)")
                    completionClosure(.failure(error))
                }

                subscription.remoteId = hash
                engine.addSubscription(subscription)

            case .failure(let error):
                self?.logger.error("Extrisinc submit error: \(error)")
                completionClosure(.failure(error))
            }
        }
    }

    private func getBlockEvents(_ hash: String,
                                extrinsicHash: String,
                                extrinsicProcessor: ExtrinsicProcessing,
                                engine: JSONRPCEngine,
                                coderOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
                                completion completionClosure: @escaping MigrationResultClosure) {
        let storageFactory = StorageKeyFactory()
        let operationQueue = OperationQueue()
        let path = StorageCodingPath.events
        let remoteKey = try? storageFactory.createStorageKey(moduleName: path.moduleName, storageName: path.itemName)
        let operationManager = OperationManagerFacade.sharedManager
        let requestFactory = StorageRequestFactory(remoteFactory: storageFactory, operationManager: operationManager)

        let block = try? Data(hex: hash)
        let wrapper: CompoundOperationWrapper<[StorageResponse<[EventRecord]>]> =
            requestFactory.queryItems(engine: engine,
                                      keys: { [remoteKey!] },
                                      factory: { try coderOperation.extractNoCancellableResultData() },
                                      storagePath: path,
                                      at: block)
        wrapper.allOperations.forEach { $0.addDependency(coderOperation) }

        let fetchBlockOperation: JSONRPCOperation<[String], SignedBlock> =
            JSONRPCOperation(engine: engine,
                             method: RPCMethod.getChainBlock,
                             parameters: [hash])

        let parseOperation = createParseOperation(dependingOn: fetchBlockOperation)

        parseOperation.addDependency(fetchBlockOperation)

        let operations = [coderOperation] + wrapper.allOperations + [fetchBlockOperation, parseOperation]

        operationQueue.addOperations(operations, waitUntilFinished: true)
        do {
            if let records = try wrapper.targetOperation.extractNoCancellableResultData().first?.value {
                let coderFactory = try coderOperation.extractNoCancellableResultData()
                let metadata = coderFactory.metadata

                let blockExtrinsics = try parseOperation.extractResultData()

                let eventIndex = blockExtrinsics?.firstIndex(of: extrinsicHash)!
                let extrinsicData = try Data(hex: extrinsicHash)

                if let processingResult = extrinsicProcessor.process(
                    extrinsicIndex: UInt32(eventIndex!),
                    extrinsicData: extrinsicData,
                    eventRecords: records,
                    coderFactory: coderFactory
                    ),
                    processingResult.isSuccess {
                    self.migrationSuccess()
                    completionClosure(.success(""))
                } else {
                    throw MigrationServiceError.confirmMigrationFail
                }
            } else {
                logger.info("No events found")
                completionClosure(.failure(MigrationServiceError.confirmMigrationFail))
            }
        } catch {
            logger.error("Did receive error: \(error)")
            completionClosure(.failure(error))
        }
    }

    private func createParseOperation(dependingOn fetchOperation: BaseOperation<SignedBlock>)
    -> BaseOperation<[String]> {

        return ClosureOperation {
            let block = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .block

            return block.extrinsics
        }
    }
}
