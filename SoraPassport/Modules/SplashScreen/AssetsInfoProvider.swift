/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import FearlessUtils

struct AssetInfoDto: ScaleCodable {
    let symbol: String
    let name: String
    let precision: UInt8
    let isMintable: Bool

    init(scaleDecoder: ScaleDecoding) throws {
        symbol = try String(scaleDecoder: scaleDecoder)
        name = try String(scaleDecoder: scaleDecoder)
        precision = try UInt8(scaleDecoder: scaleDecoder)
        isMintable = try Bool(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try symbol.encode(scaleEncoder: scaleEncoder)
        try name.encode(scaleEncoder: scaleEncoder)
        try precision.encode(scaleEncoder: scaleEncoder)
        try isMintable.encode(scaleEncoder: scaleEncoder)
    }
}

protocol AssetsInfoProviderProtocol {
    func load(completion: ([AssetInfo]) -> Void)
}

final class AssetsInfoProvider: AssetsInfoProviderProtocol {
    let engine: JSONRPCEngine
    let storageKeyFactory: StorageKeyFactoryProtocol
    let operationQueue = OperationQueue()
    let assetInfoKey: String
    let chainId: String?

    let keysPageSize: UInt32 = 100

    var keysOnCurrentPageCount = 0
    var currentLastKey: String? = nil
    var currentGetKeysOperation: JSONRPCOperation<[JSONAny], [String]>?

    var keys: [String] = []
    var assetsInfo: [AssetInfo] = []

    init(engine: JSONRPCEngine, storageKeyFactory: StorageKeyFactoryProtocol, chainId: String? = nil) {
        self.engine = engine
        self.storageKeyFactory = storageKeyFactory
        assetInfoKey = try! storageKeyFactory.assetsInfoKeysPaged().toHex(includePrefix: true)
        self.chainId = chainId
    }

    func load(completion: ([AssetInfo]) -> Void) {
        loadAssetsInfoKeys()
        loadAssetsInfo()
        completion(assetsInfo)
    }

    //MARK: - Load Keys

    func loadAssetsInfoKeys() {
        currentGetKeysOperation = nextGetKeysOperation()
        while(currentGetKeysOperation != nil) {
            guard let currentGetKeysOperation = currentGetKeysOperation else { break }
            performGetKeysOperation(currentGetKeysOperation)
            self.currentGetKeysOperation = nextGetKeysOperation()
        }
    }

    func nextGetKeysOperation() -> JSONRPCOperation<[JSONAny], [String]>? {
        if didLoadAllKeys() {
            return nil
        }

        var paramsArray: [JSONAny] = [JSONAny(assetInfoKey), JSONAny(keysPageSize)]
        if let currentLastKey = currentLastKey {
            paramsArray.append(JSONAny(currentLastKey))
        }

        return JSONRPCOperation<[JSONAny], [String]>(
            engine: engine,
            method: SoraPassport.RPCMethod.getStorageKeysPaged,
            parameters: paramsArray)
    }

    func didLoadAllKeys() -> Bool {
        let didStartLoading = currentGetKeysOperation != nil
        let didNotReceiveKeysInLastResponse = keysOnCurrentPageCount == 0
        return didStartLoading && didNotReceiveKeysInLastResponse
    }

    func performGetKeysOperation(_ operation:JSONRPCOperation<[JSONAny], [String]>) {
        operationQueue.addOperations([operation], waitUntilFinished: true)
        do {
            try operation.extractResultData()
        } catch let error {
            Logger.shared.error("ASSET KEYS FAIL \(error)")
        }
        guard let page = try? operation.extractResultData() else { return }
        didReceive(page: page)
    }

    func didReceive(page: [String]) {
        currentLastKey = page.last
        keysOnCurrentPageCount = page.count
        keys.append(contentsOf: page)
    }

    //MARK: - Load AssetInfo

    func loadAssetsInfo() {
        let operation = JSONRPCOperation<[[String]], [StorageUpdate]>(
            engine: engine,
            method: SoraPassport.RPCMethod.queryStorageAt,
            parameters: [keys])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        do {
            try operation.extractResultData()
        } catch let error {
            Logger.shared.error("ASSET FAIL \(error)")
        }

        guard let storageUpdate = try? operation.extractResultData()?.first
        else {
            Logger.shared.error("failed to load asset info with keys: \(keys)")
            self.assetsInfo = []
            return
        }

        didReceive(update: storageUpdate)
    }

    func didReceive(update storageUpdate: StorageUpdate) {
        let storageUpdateData = StorageUpdateData(update: storageUpdate)
        assetsInfo = storageUpdateData.changes.compactMap { change in
            return self.assetInfo(from: change)
        }
    }

    func assetInfo(from change: StorageUpdateData.StorageUpdateChangeData) -> AssetInfo? {
        guard let assetInfoDto = assetInfoDto(from: change.value) else { return nil }
        let assetId = assetId(from: change.key)
        return AssetInfo(id: assetId,
                         symbol: assetInfoDto.symbol,
                         chainId: chainId ?? "",
                         precision: UInt32(assetInfoDto.precision),
                         icon: nil,
                         displayName: assetInfoDto.name,
                         visible: true)
    }

    func assetId(from assetKey: Data) -> String {
        let hexPrefix = "0x"
        let assetIdWithoutPrefix = assetKey.toHex(includePrefix: true).suffix(64)
        return hexPrefix + assetIdWithoutPrefix
    }

    func assetInfoDto(from data: Data?) -> AssetInfoDto? {
        guard let data = data else { return nil }
        guard let scaleDecoder = try? ScaleDecoder(data: data) else { return nil }
        return try? AssetInfoDto(scaleDecoder: scaleDecoder)
    }
}
