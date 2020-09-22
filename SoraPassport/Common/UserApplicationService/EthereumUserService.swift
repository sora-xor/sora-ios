import Foundation
import RobinHood
import web3swift
import SoraKeystore
import BigInt

final class EthereumUserService {
    let registrationFactory: EthereumRegistrationFactoryProtocol
    let serviceUnit: ServiceUnit
    let requestSigner: NetworkRequestModifierProtocol
    let repository: AnyDataProviderRepository<EthereumInit>
    let repositoryObserver: CoreDataContextObservable<EthereumInit, CDSidechainInit>
    let operationManager: OperationManagerProtocol
    let keystore: Keychain
    let logger: LoggerProtocol

    init(registrationFactory: EthereumRegistrationFactoryProtocol,
         serviceUnit: ServiceUnit,
         requestSigner: NetworkRequestModifierProtocol,
         repository: AnyDataProviderRepository<EthereumInit>,
         repositoryObserver: CoreDataContextObservable<EthereumInit, CDSidechainInit>,
         operationManager: OperationManagerProtocol,
         keystore: Keychain,
         logger: LoggerProtocol) {
        self.registrationFactory = registrationFactory
        self.serviceUnit = serviceUnit
        self.requestSigner = requestSigner
        self.repository = repository
        self.repositoryObserver = repositoryObserver
        self.operationManager = operationManager
        self.keystore = keystore
        self.logger = logger
    }

    // MARK: Private

    private func updateRegistration() {
        logger.debug("Will start registration update")

        let preparation = createPreparationWrapper()
        let registration = createRegistrationWrapper(dependingOn: preparation.targetOperation)
        let saving = createSaveResultWrapper(dependingOn: preparation.targetOperation,
                                                    registrationOperation: registration.targetOperation)

        registration.allOperations.forEach { registrationOperation in
            preparation.allOperations.forEach { registrationOperation.addDependency($0) }
        }

        saving.allOperations.forEach { savingOperation in
            registration.allOperations.forEach { savingOperation.addDependency($0) }
        }

        saving.targetOperation.completionBlock = {
            do {
                try saving.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                switch registration.targetOperation.result {
                case .success(let transactionId):
                    self.logger.debug("Did start ethereum address registration: \(transactionId.soraHex)")
                case .failure(let error):
                    self.logger.error("Did receive ethereum address registration error: \(error)")
                case .none:
                    self.logger.debug("No need in ethereum address registration")
                }
            } catch {
                self.logger.error("Did receive ethereum state save error: \(error)")
            }
        }

        let operations = preparation.allOperations + registration.allOperations + saving.allOperations

        operationManager.enqueue(operations: operations,
                                 in: .byIdentifier(SidechainId.eth.rawValue))
    }

    private func createPreparationWrapper() -> CompoundOperationWrapper<EthereumInit> {
        guard
            let stateUrlTemplate = serviceUnit
                .service(for: WalletServiceType.ethereumState.rawValue)?.serviceEndpoint else {

            logger.error("Ethereum address registration state endpoint missing")

            let operation = BaseOperation<EthereumInit>()
            operation.result = .failure(NetworkUnitError.brokenServiceEndpoint)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let localFetchOperation = repository.fetchOperation(by: SidechainId.eth.rawValue,
                                                            options: RepositoryFetchOptions())

        let remoteFetchOperation = registrationFactory.createRegistrationStateOperation(stateUrlTemplate)
        remoteFetchOperation.requestModifier = requestSigner

        remoteFetchOperation.configurationBlock = {
            do {
                guard let localItem = try localFetchOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                    return
                }

                if localItem.state != .needsRegister && localItem.state != .needsUpdatePending {
                    remoteFetchOperation.cancel()
                }

            } catch {
                remoteFetchOperation.result = .failure(error)
            }
        }

        remoteFetchOperation.addDependency(localFetchOperation)

        let mergeOperation = ClosureOperation<EthereumInit> {
            if let remoteResult = remoteFetchOperation.result {
                switch remoteResult {
                case .success(let data):
                    return SidechainInit(data: data)
                case .failure(let error):
                    if let initError = error as? EthereumInitDataError, initError == .notFound {
                        return EthereumInit(sidechainId: SidechainId.eth,
                                            state: .needsRegister,
                                            userInfo: nil)
                    } else {
                        throw error
                    }
                }
            }

            if let localItem = try localFetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) {
                return localItem
            }

            return EthereumInit(sidechainId: SidechainId.eth,
                                state: .needsRegister,
                                userInfo: nil)
        }

        mergeOperation.addDependency(remoteFetchOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation,
                                        dependencies: [localFetchOperation, remoteFetchOperation])
    }

    private func createRegistrationWrapper(
        dependingOn stateOperation: BaseOperation<EthereumInit>)
        -> CompoundOperationWrapper<Data> {

        guard
            let registrationUrlTemplate = serviceUnit
                .service(for: WalletServiceType.ethereumRegistration.rawValue)?.serviceEndpoint else {

            logger.error("Ethereum address registration endpoint missing")

            let operation = BaseOperation<Data>()
            operation.result = .failure(NetworkUnitError.brokenServiceEndpoint)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let registrationConfig = createIntentionConfigClosure()

        let registrationOperation = registrationFactory.createIntentionOperation(registrationUrlTemplate,
                                                                                 config: registrationConfig)
        registrationOperation.requestModifier = requestSigner

        registrationOperation.configurationBlock = {
            do {
                let currentItem = try stateOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                if currentItem.state != .needsRegister {
                    registrationOperation.cancel()
                }
            } catch {
                registrationOperation.result = .failure(error)
            }
        }

        return CompoundOperationWrapper(targetOperation: registrationOperation)
    }

    private func createSaveResultWrapper(dependingOn stateOperation: BaseOperation<EthereumInit>,
                                         registrationOperation: BaseOperation<Data>)
        -> CompoundOperationWrapper<Void> {

        let saveClosure: () -> [EthereumInit] = {
            do {
                let currentItem = try stateOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                switch registrationOperation.result {
                case .success:
                    let changed = EthereumInit(sidechainId: .eth,
                                               state: .inProgress,
                                               userInfo: currentItem.userInfo)
                    return [changed]
                case .failure:
                    let changed = EthereumInit(sidechainId: .eth,
                                               state: .failed,
                                               userInfo: currentItem.userInfo)
                    return [changed]
                case .none:
                    return [currentItem]
                }

            } catch {
                return []
            }
        }

        let saveOperation = repository.saveOperation(saveClosure, { [] })

        return CompoundOperationWrapper(targetOperation: saveOperation)
    }

    private func createIntentionConfigClosure() -> EthereumIntentionInfoConfig {
        let registrationConfig: EthereumIntentionInfoConfig = {
            let privateKey = try self.keystore.fetchKey(for: KeystoreKey.ethKey.rawValue)
            guard let publicKey = SECP256K1.privateToPublic(privateKey: privateKey, compressed: false) else {
                throw EthereumRegistrationServiceError.publicKeyDeriviationFailed
            }

            guard let publicKeyInfo = BigInt(publicKey[1...].soraHex, radix: 16) else {
                throw EthereumRegistrationServiceError.publicKeyDecodingFailed
            }

            guard let address = Web3Utils.publicToAddress(publicKey) else {
                throw EthereumRegistrationServiceError.addressDeriviationFailed
            }

            guard let signatureData = try Web3Signer.signPersonalMessage(address.addressData,
                                                                         keystore: self.keystore,
                                                                         account: address,
                                                                         password: "") else {
                throw EthereumRegistrationServiceError.signingFailed
            }

            guard let signature = SECP256K1.unmarshalSignature(signatureData: signatureData) else {
                throw EthereumRegistrationServiceError.signatureDeserializationFailed
            }

            let signatureInfo = EthereumSignature(vPart: signature.v, rPart: signature.r, sPart: signature.s)

            return EthereumRegistrationInfo(publicKey: publicKeyInfo, signature: signatureInfo)
        }

        return registrationConfig
    }
}

extension EthereumUserService: UserApplicationServiceProtocol {
    func setup() {
        repositoryObserver.addObserver(self, deliverOn: .main) { [weak self] changes in
            for change in changes {
                switch change {
                case .insert(let newItem), .update(let newItem):
                    if
                        (newItem.identifier == SidechainId.eth.rawValue) &&
                        (newItem.state == .needsRegister || newItem.state == .needsUpdatePending) {
                        self?.updateRegistration()
                    }
                default:
                    break
                }
            }
        }

        updateRegistration()
    }

    func throttle() {
        repositoryObserver.removeObserver(self)
    }
}
