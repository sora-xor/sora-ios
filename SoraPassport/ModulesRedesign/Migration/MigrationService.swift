// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import SoraKeystore
import RobinHood
import IrohaCrypto
import SSFUtils

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

    var engine: JSONRPCEngine? {
        ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())
    }
    private(set) var settings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    var runtimeRegistry: RuntimeCodingServiceProtocol? {
        ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())
    }
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol
    let keystore: KeystoreProtocol

    init(eventCenter: EventCenterProtocol,
         keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.logger = logger
        self.operationManager = operationManager
        self.keystore = keystore
    }

    lazy var irohaKeyPair: IRCryptoKeypairProtocol? = createIrohaKeyPair()

    lazy var did: String = createDid()

    func checkMigration() {
        irohaKeyPair = createIrohaKeyPair()
        did = createDid()
        if !settings.hasMigrated {
            _ = try? engine?.callMethod(RPCMethod.needsMigration,
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
        guard let account = SelectedWalletSettings.shared.currentAccount else {
            logger.error("Migration account not found")
            return
        }
        guard let engine = engine else {
            logger.error("Migration connection not found")
            return
        }

        guard let irohaKeyPair = irohaKeyPair else {
            logger.error("IrohaKeyPair failed")
            return
        }

        let signer = SigningWrapper(keystore: self.keystore, account: account)
        let irohaSigner = IRSigningDecorator(keystore: self.keystore, identifier: "iroha")

        let extrinsicService = ExtrinsicService(address: account.address,
                                                cryptoType: account.cryptoType,
                                                runtimeRegistry: runtimeRegistry!,
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
        extrinsicService.submit(closure, signer: signer, watch: true, runningIn: .main) { [weak self] result, extrinsicHash, extrinsic in
            guard let extrinsic = extrinsic else { return }
            
            switch result {
            case .success(let hash):
                self?.logger.info("Did receive extrinsic hash: \(extrinsicHash), subscription \(hash)")
                let requestId = engine.generateRequestId()

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
                                                    extrinsicHash: extrinsicHash ?? "",
                                                    extrinsic: extrinsic,
                                                    extrinsicProcessor: extrinsicProcessor,
                                                    engine: engine,
                                                    coderOperation: self.runtimeRegistry!.fetchCoderFactoryOperation(),
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
                                extrinsic: Extrinsic,
                                extrinsicProcessor: ExtrinsicProcessing,
                                engine: JSONRPCEngine,
                                coderOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
                                completion completionClosure: @escaping MigrationResultClosure) {
        let storageFactory = StorageKeyFactory()
        let operationQueue = OperationQueue()
        let path = StorageCodingPath.events
        let remoteKey = try? storageFactory.createStorageKey(moduleName: path.moduleName, storageName: path.itemName)
        let operationManager = OperationManagerFacade.sharedManager
        let requestFactory = StorageRequestFactory(remoteFactory: storageFactory as! StorageKeyFactoryProtocol, operationManager: operationManager)

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

                if let processingResult = extrinsicProcessor.process(
                    extrinsicIndex: UInt32(eventIndex!),
                    extrinsic: extrinsic,
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
    
    private func createIrohaKeyPair() -> IRCryptoKeypairProtocol? {
        if let address = SelectedWalletSettings.shared.currentAccount?.address,
            let entropy = try? keystore.fetchEntropyForAddress(address),
            let mnemonic = try? IRMnemonicCreator().mnemonic(fromEntropy: entropy),
            let irohaKey = try? IRKeypairFacade().deriveKeypair(from: mnemonic.toString()) {
            return irohaKey
        }
        return nil
    }
    
    private func createDid() -> String {
        return "did_sora_\(irohaKeyPair?.publicKey().decentralizedUsername ?? "")@sora"
    }
}
