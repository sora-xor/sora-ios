/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import IrohaCrypto
import FearlessUtils
import RobinHood

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    var settings: SettingsManagerProtocol
    var keystore: KeystoreProtocol
    var securityLayerInteractor: SecurityLayerInteractorInputProtocol
    var networkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol?

    init(settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         securityLayerInteractor: SecurityLayerInteractorInputProtocol,
         networkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol?) {
        self.settings = settings
        self.keystore = keystore
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

    private func setupChainData() {
        let connectionItem = settings.selectedConnection
        let engine = WebSocketEngine(url: connectionItem.url, logger: Logger.shared)
        let genesisOperation = createGenesisOperation(engine: engine)
        genesisOperation.completionBlock = {
            if let genesis = try? genesisOperation.extractResultData() {
                self.settings.set(value: genesis, for: SettingsKey.externalGenesis.rawValue)
            }
        }
        let metadataOperation = createMetadataOperation(engine: engine)
        metadataOperation.completionBlock = {
            if let metadata = try? metadataOperation.extractResultData()?.underlyingValue {
                let prefixCoding = ConstantCodingPath.chainPrefix
                let depositCoding = ConstantCodingPath.existentialDeposit
                let assetsCoding = ConstantCodingPath.assetInfos

                let prefixData = metadata.getConstant(in: prefixCoding.moduleName, constantName: prefixCoding.constantName)
                let existentialDepositData = metadata.getConstant(in: depositCoding.moduleName, constantName: depositCoding.constantName)
                let assetInfo = metadata.getStorageMetadata(in: assetsCoding.moduleName, storageName: assetsCoding.constantName)

                let prefix = try? UInt8(scaleDecoder: ScaleDecoder(data: prefixData!.value))
                let deposit = try? UInt16(scaleDecoder: ScaleDecoder(data: existentialDepositData!.value))
//                let assets = try? MapEntry(scaleDecoder: ScaleDecoder(data: assetInfo!.defaultValue))

                self.settings.set(value: prefix, for: SettingsKey.externalPrefix.rawValue)
                self.settings.set(value: deposit, for: SettingsKey.externalExistentialDeposit.rawValue)
                //should've saved metadata, but dont' want to bring all the file operations here
            }
        }
        metadataOperation.addDependency(genesisOperation)
        OperationQueue().addOperations([ genesisOperation, metadataOperation], waitUntilFinished: true)

    }

    private func createGenesisOperation(engine: JSONRPCEngine) -> BaseOperation<String> {
        var currentBlock = 0
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(engine: engine,
                                            method: RPCMethod.getBlockHash,
                                            parameters: [param])
    }

    private func createMetadataOperation(engine: JSONRPCEngine) -> BaseOperation<JSONScaleDecodable<RuntimeMetadata>> {
        let method = RPCMethod.getRuntimeMetadata

        let metaOperation = JSONRPCListOperation<JSONScaleDecodable<RuntimeMetadata>>(engine: engine,
                                                               method: method)
        return metaOperation
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

    func setup() {
        setupURLHandlingService()
        configureSecurityService()
        configureNetworkAvailabilityService()
        configureDeepLinkService()
        setupChainData()
    }
}
