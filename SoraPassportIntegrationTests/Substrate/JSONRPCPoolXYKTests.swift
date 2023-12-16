import BigInt
import SSFUtils
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraKeystore
@testable import SoraPassport
import XCTest
import xxHash_Swift
import CommonWallet

import XCTest

class JSONRPCPoolXYKTests: NetworkBaseTests {

    func testBalance() {
        let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
        let address: AccountAddress = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
        let asset = "0x0200040000000000000000000000000000000000000000000000000000000000"
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        let key = try! StorageKeyFactory().accountsKey(
            account: address.accountId!,
            asset: Data(hex: asset)
        ).toHex(includePrefix: true)

        let operation = JSONRPCListOperation<JSONScaleDecodable<OrmlAccountData>>(
            engine: engine,
            method: SoraPassport.RPCMethod.getStorage,
            parameters: [key]
        )

        operationQueue.addOperations([operation], waitUntilFinished: true)

        do {
            guard let data = try operation.extractResultData(),
                  let balances = data.underlyingValue
            else {
                XCTFail("No account balance")
                return
            }

            Logger.shared.debug("balance: \(balances)")

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBalances() {
        let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
        let address: AccountAddress = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        let key = try! StorageKeyFactory().accountsKey(
            account: address.accountId!,
            asset: Data(hex: WalletAssetId.val.rawValue)
        ).toHex(includePrefix: true)

        let operation = JSONRPCListOperation<JSONScaleDecodable<OrmlAccountData>>(
            engine: engine,
            method: SoraPassport.RPCMethod.getStorage,
            parameters: [key]
        )

        operationQueue.addOperations([operation], waitUntilFinished: true)

        do {
            guard let data = try operation.extractResultData(),
                  let balances = data.underlyingValue
            else {
                XCTFail("No account balances")
                return
            }

            Logger.shared.debug("balances: \(balances)")

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testXorPools() {
        let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
        let address: AccountAddress = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        let storageFactory = StorageKeyFactory()

        let xorIdData = try! Data(hexStringSSF: WalletAssetId.xor.rawValue)
        let keyXorPools = try! storageFactory.accountPoolsKeyForId(address.accountId!, baseAssetId: xorIdData).toHex(includePrefix: true)

        let operation = JSONRPCListOperation<JSONScaleDecodable<AccountPools>>(
            engine: engine,
            method: SoraPassport.RPCMethod.getStorage,
            parameters: [keyXorPools]
        )

        operationQueue.addOperations([operation], waitUntilFinished: true)

        do {
            guard let pools = try operation.extractResultData()?.underlyingValue else {
                XCTFail("No account pools")
                return
            }

            XCTAssertFalse(pools.assetIds.isEmpty)
            Logger.shared.debug("Account pools: \(pools)")

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testXstusdPools() {
        let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
        let address: AccountAddress = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        let storageFactory = StorageKeyFactory()
        let xstusdIdData = try! Data(hexStringSSF: WalletAssetId.xstusd.rawValue)
        let keyXstusdPools = try! storageFactory.accountPoolsKeyForId(address.accountId!, baseAssetId: xstusdIdData).toHex(includePrefix: true)

        let operation = JSONRPCListOperation<JSONScaleDecodable<AccountPools>>(
            engine: engine,
            method: SoraPassport.RPCMethod.getStorage,
            parameters: [keyXstusdPools]
        )

        operationQueue.addOperations([operation], waitUntilFinished: true)

        do {
            guard let pools = try operation.extractResultData()?.underlyingValue else {
                XCTFail("No account pools")
                return
            }

            XCTAssertFalse(pools.assetIds.isEmpty)
            Logger.shared.debug("Account pools: \(pools)")

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    //TODO: try to get all account's pools in one request (now 1 request for XOR-pools and 1 request for XSTUSD-pools)
//    func testPools() {
//        let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
//        let address: AccountAddress = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        let storageFactory = StorageKeyFactory()
//
//        let xorIdData = try! Data(hexStringSSF: WalletAssetId.xor.rawValue)
//        let xstIdData = try! Data(hexStringSSF: WalletAssetId.xstusd.rawValue)
//
//        let keyXor = try! storageFactory.createStorageKey(moduleName: "PoolXYK", storageName: "AccountPools", key1: address.accountId!, hasher1: .identity, key2: xorIdData, hasher2: .blake128Concat).toHex(includePrefix: true)
//        let keyXst = try! storageFactory.createStorageKey(moduleName: "PoolXYK", storageName: "AccountPools", key1: address.accountId!, hasher1: .identity, key2: xstIdData, hasher2: .blake128Concat).toHex(includePrefix: true)
//
//        let operation = JSONRPCOperation<[[String]], JSONScaleDecodable<AccountAssetPools>>(
//            engine: engine,
//            method: SoraPassport.RPCMethod.queryStorageAt,
//            parameters: [[keyXor, keyXst]]
//        )
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        do {
//            guard let pools = try operation.extractResultData()?.underlyingValue else {
//                XCTFail("No account pools")
//                return
//            }
//
////            XCTAssertFalse(pools.assetIds.isEmpty)
//            Logger.shared.debug("Account pools: \(pools)")
//
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }

    //    poolXYK
    //    properties(AssetId, AssetId): Option<(AccountId,AccountId)>
    //    Properties of particular pool. Base Asset => Target Asset => (Reserves Account Id, Fees Account Id)
    func testPoolProperties() {
        let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
        let baseAsset = "0x0200000000000000000000000000000000000000000000000000000000000000"
        let targetAsset = "0x0200040000000000000000000000000000000000000000000000000000000000"
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        let storageFactory = StorageKeyFactory()

        let key = try! storageFactory.poolPropertiesKey(
            baseAssetId: Data(hex: baseAsset),
            targetAssetId: Data(hex: targetAsset)
        )
        .toHex(includePrefix: true)

        let operation = JSONRPCListOperation<JSONScaleDecodable<PoolProperties>>(
            engine: engine,
            method: SoraPassport.RPCMethod.getStorage,
            parameters: [key]
        )

        operationQueue.addOperations([operation], waitUntilFinished: true)

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let poolProperties = result.underlyingValue else {
                XCTFail("No PoolProperties")
                return
            }
            Logger.shared.debug("PoolProperties: \(poolProperties)")
            Logger.shared.debug("reservesAccount address: \(poolProperties.reservesAccountId)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPoolReserves() {
        let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
        let baseAsset = "0200000000000000000000000000000000000000000000000000000000000000"
        let targetAsset = "0200040000000000000000000000000000000000000000000000000000000000"
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        let storageFactory = StorageKeyFactory()

        // reserves(AssetId, AssetId): (Balance,Balance) Updated after last liquidity change operation.
        let key = try! storageFactory.poolReservesKey(
            baseAssetId: Data(hex: baseAsset),
            targetAssetId: Data(hex: targetAsset)
        )
        .toHex(includePrefix: true)

        let operation = JSONRPCListOperation<JSONScaleDecodable<PoolReserves>>(
            engine: engine,
            method: SoraPassport.RPCMethod.getStorage,
            parameters: [key]
        )

        operationQueue.addOperations([operation], waitUntilFinished: true)

        do {
            guard let poolReserves = try operation.extractResultData()?.underlyingValue else {
                XCTFail("No Pool Reserves")
                return
            }

            Logger.shared.debug("poolReserves: \(poolReserves)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

//    func testPoolProviders() {
//        let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
//        let reservesAccount = "cnTQ1kbv7PBNNQrEb1tZpmK7f4sMKaWQF583on92JL48B9kjq"
//        let account = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        let storageFactory = StorageKeyFactory()
//
//        // poolProviders(AccountIdOf, AccountIdOf): Option<Balance> Liquidity providers of particular pool.
//        let key = try! storageFactory.poolProvidersKey(
//            reservesAccountId: reservesAccount.accountId!,
//            accountId: account.accountId!
//        )
//        .toHex(includePrefix: true)
//
//        let operation = JSONRPCListOperation<JSONScaleDecodable<Balance>>(
//            engine: engine,
//            method: SoraPassport.RPCMethod.getStorage,
//            parameters: [key]
//        )
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        do {
//            guard let poolProviders = try operation.extractResultData()?.underlyingValue else {
//                XCTFail("No PoolProviders")
//                return
//            }
//
//            Logger.shared.debug("PoolProviders: \(poolProviders)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    //    poolXYK
//    //    totalIssuances(AccountIdOf): Option<Balance>
//    //    Total issuance of particular pool.
//    func testPoolTotalIssuances() {
//        let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
//        let reservesAccount: AccountAddress = "cnTQ1kbv7PBNNQrEb1tZpmK7f4sMKaWQF583on92JL48B9kjq"
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        let storageFactory = StorageKeyFactory()
//
//        let key = try! storageFactory.accountPoolTotalIssuancesKeyForId(reservesAccount.accountId!)
//            .toHex(includePrefix: true)
//
//        let operation = JSONRPCListOperation<JSONScaleDecodable<Balance>>(
//            engine: engine,
//            method: RPCMethod.getStorage,
//            parameters: [key]
//        )
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        do {
//            guard let poolTotalIssuances = try operation.extractResultData()?.underlyingValue else {
//                XCTFail("No PoolTotalIssuances")
//                return
//            }
//
//            Logger.shared.debug("PoolTotalIssuances: \(poolTotalIssuances)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    // YOUR POOL SHARE      2.1165251%
//    // STRATEGIC BONUS APY  55.1515303%
//    // XOR POOLED           2300
//    // VAL POOLED           233.14852941
//    //totalIssuances:
//    //    XOR Pooled:
//    //    {{ Receiving the reserves first return }} *
//    //    {{ Receiving account's pool balance return }}
//    //    / {{  Receiving total issuances return }}
//    //
//    //    {second asset} Pooled:
//    //    {{ Receiving the reserves second return }} *
//    //    {{ Receiving account's pool balance return }}
//    //    / {{  Receiving total issuances return }}
//    //
//    //    Your pool share:
//    //    {{ Receiving account's pool balance return }} / {{  Receiving total issuances return }} * 100%
//    func testPoolsDetails() {
//        let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
//        let baseAsset = "0200000000000000000000000000000000000000000000000000000000000000"
//        let address: AccountAddress = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//        let engine = WebSocketEngine(url: url, logger: logger)
//        let storageFactory = StorageKeyFactory()
//
//        // accountPoolsOperation
//        let accountPoolsOperation = JSONRPCListOperation<JSONScaleDecodable<AccountPools>>(engine: engine, method: RPCMethod.getStorage, parameters: [
//            try! storageFactory.accountPoolsKeyForId(address.accountId!).toHex(includePrefix: true),
//        ])
//        operationQueue.addOperations([accountPoolsOperation], waitUntilFinished: true)
//
//        guard let pools = try? accountPoolsOperation.extractResultData()?.underlyingValue?.assetIds else {
//            XCTFail("No pools")
//            return
//        }
//
//        let selectedAsset = pools.first!
//
//        // poolProperties
//
//        let key = try! storageFactory.poolPropertiesKey(baseAssetId: Data(hex: baseAsset), targetAssetId: Data(hex: selectedAsset)).toHex(includePrefix: true)
//        let operation = JSONRPCListOperation<JSONScaleDecodable<PoolProperties>>(
//            engine: engine,
//            method: RPCMethod.getStorage,
//            parameters: [key]
//        )
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        guard let reservesAccountId = try? operation.extractResultData()?.underlyingValue?.reservesAccountId else {
//            XCTFail("No reservesAccount")
//            return
//        }
//
//        // poolProviders
//
//        let poolProvidersBalanceOperation = JSONRPCListOperation<JSONScaleDecodable<Balance>>(engine: engine, method: RPCMethod.getStorage, parameters: [
//            try! storageFactory.poolProvidersKey(reservesAccountId: reservesAccountId.value, accountId: address.accountId!).toHex(includePrefix: true),
//        ]
//        )
//
//        operationQueue.addOperations([poolProvidersBalanceOperation], waitUntilFinished: true)
//
//        guard let accountPoolBalance = try? poolProvidersBalanceOperation.extractResultData()?.underlyingValue else {
//            XCTFail("No poolProvidersBalance")
//            return
//        }
//
//        print("poolProvidersBalance:\(accountPoolBalance)")
//
//        // totalIssuances
//        let accountPoolTotalIssuancesOperation = JSONRPCListOperation<JSONScaleDecodable<Balance>>(engine: engine, method: RPCMethod.getStorage, parameters: [
//            try! storageFactory.accountPoolTotalIssuancesKeyForId(reservesAccountId.value).toHex(includePrefix: true),
//        ])
//
//        operationQueue.addOperations([accountPoolTotalIssuancesOperation], waitUntilFinished: true)
//
//        guard let totalIssuances = try? accountPoolTotalIssuancesOperation.extractResultData()?.underlyingValue else {
//            XCTFail("No totalIssuances")
//            return
//        }
//
//        let reservesOperation = JSONRPCListOperation<JSONScaleDecodable<PoolReserves>>(engine: engine, method: RPCMethod.getStorage, parameters: [
//            try! storageFactory.poolReservesKey(baseAssetId: Data(hex: baseAsset), targetAssetId: Data(hex: selectedAsset)).toHex(includePrefix: true),
//        ])
//
//        operationQueue.addOperations([reservesOperation], waitUntilFinished: true)
//
//        guard let reserves = try? reservesOperation.extractResultData()?.underlyingValue else {
//            XCTFail("No reserves")
//            return
//        }
//
//        // XOR Pooled
//        let yourPoolShare = Double(accountPoolBalance.value) / Double(totalIssuances.value) * 100
//        let xorPooled = Double(reserves.reserves.value * accountPoolBalance.value) / Double(totalIssuances.value)
//        let targetPooled = Double(reserves.fees.value * accountPoolBalance.value) / Double(totalIssuances.value)
//
//        print("yourPoolShare: \(yourPoolShare)")
//        print("xorPooled: \(xorPooled)")
//        print("targetPooled: \(targetPooled)")
//    }
//
//    func testPoolsDetails2() {
//        let operationQueue = OperationQueue()
//        let operation = getPoolList()
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        let poolsDetails = try? operation.extractResultData()
//        XCTAssertNotNil(poolsDetails)
//    }
//
//    func getPoolList() -> BaseOperation<[PoolDetails]> {
//        let processingOperation: BaseOperation<[PoolDetails]> = ClosureOperation {
//            let url: URL = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
//            let baseAsset = "0200000000000000000000000000000000000000000000000000000000000000"
//            let address: AccountAddress = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
//            let operationQueue = OperationQueue()
//            let engine = WebSocketEngine(url: url, logger: Logger.shared)
//            let storageFactory = StorageKeyFactory()
//
//            var poolsDetails: [PoolDetails] = []
//
//            // accountPoolsOperation
//            let accountPoolsOperation = JSONRPCListOperation<JSONScaleDecodable<AccountPools>>(engine: engine, method: RPCMethod.getStorage, parameters: [
//                try! storageFactory.accountPoolsKeyForId(address.accountId!).toHex(includePrefix: true),
//            ])
//            operationQueue.addOperations([accountPoolsOperation], waitUntilFinished: true)
//
//            guard let pools = try? accountPoolsOperation.extractResultData()?.underlyingValue?.assetIds else {
//                return []
//            }
//
//            for targetAsset in pools {
//
//                // poolProperties
//
//                let key = try! storageFactory.poolPropertiesKey(baseAssetId: Data(hex: baseAsset), targetAssetId: Data(hex: targetAsset)).toHex(includePrefix: true)
//                let operation = JSONRPCListOperation<JSONScaleDecodable<PoolProperties>>(
//                    engine: engine,
//                    method: RPCMethod.getStorage,
//                    parameters: [key]
//                )
//
//                operationQueue.addOperations([operation], waitUntilFinished: true)
//
//                guard let reservesAccountId = try? operation.extractResultData()?.underlyingValue?.reservesAccountId else {
//                    return []
//                }
//
//                // poolProviders
//
//                let poolProvidersBalanceOperation = JSONRPCListOperation<JSONScaleDecodable<Balance>>(engine: engine, method: RPCMethod.getStorage, parameters: [
//                    try! storageFactory.poolProvidersKey(reservesAccountId: reservesAccountId.value, accountId: address.accountId!).toHex(includePrefix: true),
//                ])
//
//                operationQueue.addOperations([poolProvidersBalanceOperation], waitUntilFinished: true)
//
//                guard let accountPoolBalance = try? poolProvidersBalanceOperation.extractResultData()?.underlyingValue else {
//                    return []
//                }
//
//                print("poolProvidersBalance:\(accountPoolBalance)")
//
//                // totalIssuances
//                let accountPoolTotalIssuancesOperation = JSONRPCListOperation<JSONScaleDecodable<Balance>>(engine: engine, method: RPCMethod.getStorage, parameters: [
//                    try! storageFactory.accountPoolTotalIssuancesKeyForId(reservesAccountId.value).toHex(includePrefix: true),
//                ])
//
//                operationQueue.addOperations([accountPoolTotalIssuancesOperation], waitUntilFinished: true)
//
//                guard let totalIssuances = try? accountPoolTotalIssuancesOperation.extractResultData()?.underlyingValue else {
//                    return []
//                }
//
//                let reservesOperation = JSONRPCListOperation<JSONScaleDecodable<PoolReserves>>(engine: engine, method: RPCMethod.getStorage, parameters: [
//                    try! storageFactory.poolReservesKey(baseAssetId: Data(hex: baseAsset), targetAssetId: Data(hex: targetAsset)).toHex(includePrefix: true),
//                ])
//
//                operationQueue.addOperations([reservesOperation], waitUntilFinished: true)
//
//                guard let reserves = try? reservesOperation.extractResultData()?.underlyingValue else {
//                    return []
//                }
//
//                // XOR Pooled
//                let yourPoolShare = Double(accountPoolBalance.value) / Double(totalIssuances.value) * 100
//                let xorPooledByAccount = Decimal.fromSubstrateAmount(reserves.reserves.value * accountPoolBalance.value / totalIssuances.value, precision: 18)
//                let targetPooledByAccount = Decimal.fromSubstrateAmount(reserves.fees.value * accountPoolBalance.value / totalIssuances.value, precision: 18)
//
//                let service = SubqueryPoolsFactory(url: WalletAssetId.subqueryHistoryUrl, filter: [])
//                let strategicBonusAPYOperation = service.getStrategicBonusAPYOperation()
//                strategicBonusAPYOperation.start()
//
//                var sbAPYL: Double = 0.0
//                if let result = try? strategicBonusAPYOperation.extractNoCancellableResultData() {
//                    sbAPYL = Double(result.edges.first(where: { $0.node.targetAssetId == targetAsset })?.node.strategicBonusApy ?? "0.0")!
//                }
//
//                let xorPooledTotal = Decimal.fromSubstrateAmount(reserves.reserves.value, precision: 18)
//                let targetAssetPooledTotal = Decimal.fromSubstrateAmount(reserves.fees.value, precision: 18)
//                let totalIssuancesDecimal = Decimal.fromSubstrateAmount(totalIssuances.value, precision: 18)
//                let reservesDecimal = Decimal.fromSubstrateAmount(reserves.reserves.value, precision: 18)
//
//
//                print("yourPoolShare: \(yourPoolShare)")
//                print("sbAPYL: \(sbAPYL)")
//                print("xorPooledByAccount: \(xorPooledByAccount)")
//                print("targetPooledByAccount: \(targetPooledByAccount)")
//                print("xorPooledTotal: \(xorPooledTotal)")
//                print("targetAssetPooledTotal: \(targetAssetPooledTotal)")
//
//                let poolDetails = PoolDetails(
//                    targetAsset: targetAsset,
//                    yourPoolShare: yourPoolShare,
//                    sbAPYL: sbAPYL,
//                    xorPooledByAccount: xorPooledByAccount!,
//                    targetAssetPooledByAccount: targetPooledByAccount!,
//                    xorPooledTotal: xorPooledTotal!,
//                    targetAssetPooledTotal: targetAssetPooledTotal!,
//                    totalIssuances: totalIssuancesDecimal,
//                    reserves: reservesDecimal
//                )
//                poolsDetails.append(poolDetails)
//
//            }
//
//            return poolsDetails
//        }
//
//        return processingOperation
//    }
//
//    func testDepositLiquidity() {
//    }
//
//
//    func testCreatePair() {
//        let baseAsset = "0x0200000000000000000000000000000000000000000000000000000000000000"
//        // 0x0200000000000000000000000000000000000000000000000000000000000000 sor
//        // 0x0200040000000000000000000000000000000000000000000000000000000000 val
//        // 0x0200050000000000000000000000000000000000000000000000000000000000 pswap
//        // 0x0200060000000000000000000000000000000000000000000000000000000000 dai
//        // 0x0200070000000000000000000000000000000000000000000000000000000000 eth
//        // 0x0200080000000000000000000000000000000000000000000000000000000000 xstusd
//        // 0x008bcfd2387d3fc453333557eecb0efe59fcba128769b2feefdd306e98e66440 ceres
//
//        let targetAsset = "0x0200040000000000000000000000000000000000000000000000000000000000"
//
//        let logger = Logger.shared
//        let keystore = InMemoryKeychain()
//        let settings = InMemorySettingsManager()
//        let passphrase = "street firm worth record skin taste legend lobster magnet stove drive side"
//        let url = URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp/")!
//
//        try! AccountCreationHelper.createAccountFromMnemonic(passphrase,
//                                                            cryptoType: .sr25519,
//                                                            networkType: .sora,
//                                                            keychain: keystore,
//                                                            settings: settings)
//
//        guard let account = settings.selectedAccount else {
//            XCTFail("Can't find address")
//            return
//        }
//
//        let entropy = try! keystore.fetchEntropyForAddress(account.address)
//        let mnemonic = try! IRMnemonicCreator().mnemonic(fromEntropy: entropy!)
//        let irohaKey = try! IRKeypairFacade().deriveKeypair(from: mnemonic.toString())
//        let irohaSigner = IRSigningDecorator(keystore: keystore, identifier: "iroha")
//
//        let storageFacade = SubstrateStorageTestFacade()
//        let eventCenter = EventCenter()
//        let operationManager = OperationManager()
//
//        let runtimeRegistry = createDefaultService(storageFacade: storageFacade,
//                                           eventCenter: eventCenter,
//                                           operationManager: operationManager)
//
//        runtimeRegistry.setup()
//
//        let signer = SigningWrapper(keystore: keystore, settings: settings)
//
//        let connectionItem = settings.selectedConnection
//
//        let serviceSettings = WebSocketServiceSettings(url: url, //connectionItem.url,
//                                                       addressType: connectionItem.type,
//                                                       address: account.address)
//
//        let subscriptionFactory = WebSocketSubscriptionFactory(storageFacade: storageFacade)
//        let webSocketService = WebSocketService(settings: serviceSettings,
//                                                connectionFactory: WebSocketEngineFactory(),
//                                                subscriptionsFactory: subscriptionFactory,
//                                                applicationHandler: ApplicationHandler())
//        webSocketService.setup()
//
//        guard let engine = webSocketService.connection else {
//            XCTFail("Can't find connection")
//            return
//        }
//
//        let extrinsicService = ExtrinsicService(address: account.address,
//                                                cryptoType: account.cryptoType,
//                                                runtimeRegistry: runtimeRegistry,
//                                                engine: engine,
//                                                operationManager: operationManager)
//
//        let did = "did_sora_\(irohaKey.publicKey().decentralizedUsername)@sora"
//        let message = (did + irohaKey.publicKey().rawData().toHex()).data(using: .utf8)
//        let data = try! NSData.init(data: message!).sha3(IRSha3Variant.variant256)
//        let signature = try! irohaSigner.sign(data, privateKey: irohaKey.privateKey())
//        logger.debug(did)
//
//        let closure: ExtrinsicBuilderClosure = { builder in
//            let callFactory = SubstrateCallFactory()
//
//            let desiredA = Decimal(0.0015).toSubstrateAmount(precision: 18)! // 0.00162167745
//            let desiredB = Decimal(0.0014).toSubstrateAmount(precision: 18)! // 0.0025
//            let minA = Decimal(0.0012).toSubstrateAmount(precision: 18)! // 0.00161356906275
//            let minB = Decimal(0.0011).toSubstrateAmount(precision: 18)! // 0.0024875
//
//
//            let registerCall = try callFactory.register(baseAssetId: baseAsset, targetAssetId: targetAsset)
//            let initializeCall = try callFactory.initializePool(baseAssetId: baseAsset, targetAssetId: targetAsset)
//            let depositCall = try callFactory.depositLiquidity(
//                assetA: baseAsset,
//                assetB: targetAsset,
//                desiredA: desiredA,
//                desiredB: desiredB,
//                minA: minA,
//                minB: minB
//            )
//
//            return try builder
//                .with(shouldUseAtomicBatch: true)
//                .adding(call: registerCall)
//                .adding(call: initializeCall)
//                .adding(call: depositCall)
//        }
//
//        let expectation = XCTestExpectation()
//
//        let operationQueue = OperationQueue()
//
//        extrinsicService.estimateFee(closure, runningIn: .main) { result in //: Result<RuntimeDispatchInfo, Error> in
//            let extrinsicHash = "extrinsicHash"
//            switch result {
//            case .success(let hash):
//                logger.info("Did receive extrinsic hash: \(extrinsicHash), subscription \(hash)")
//                let engine = webSocketService.engine!
//                let id = engine.generateRequestId()
//
//                let subscription = JSONRPCSubscription<JSONRPCSubscriptionUpdate<ExtrinsicStatus>>(requestId: id, requestData: Data(), requestOptions: JSONRPCOptions(resendOnReconnect: true)) { data in
//                    logger.info("extrinsic \(data.params.result)")
//                    let state = data.params.result
//                    switch state {
//                    case .finalized(let block):
//                        expectation.fulfill()
//                    default:
//                        logger.info("extrinsic status \(state)")
//                    }
//                } failureClosure: { (error, unsubscribed) in
//                    XCTFail("Did receive error: \(error)")
//                }
//
//                webSocketService.engine?.addSubscription(subscription)
//            case .failure(let error):
//                XCTFail("Did receive error: \(error)")
//            }
//        }
//
//        wait(for: [expectation], timeout: 60)
//    }
//
//    private func createDefaultService(
//        storageFacade: StorageFacadeProtocol,
//        eventCenter: EventCenterProtocol,
//        operationManager: OperationManagerProtocol
//    ) -> RuntimeRegistryService {
//        let chain = Chain.sora
//        TypeDefFileMock.register(mock: .soraDefault, url: chain.typeDefDefaultFileURL()!)
//        TypeDefFileMock.register(mock: .soraNetwork, url: chain.typeDefNetworkFileURL()!)
//
//        let logger = Logger.shared
//        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
//                                                           operationManager: operationManager,
//                                                           logger: logger)
//
//        let directoryPath = FileManager.default.temporaryDirectory.appendingPathComponent("runtime").path
//        let filesFacade = RuntimeFilesOperationFacade(repository: FileRepository(),
//                                                      directoryPath: directoryPath)
//
//        let service = RuntimeRegistryService(chain: .sora,
//                                             metadataProviderFactory: providerFactory,
//                                             dataOperationFactory: DataOperationFactory(),
//                                             filesOperationFacade: filesFacade,
//                                             operationManager: operationManager,
//                                             eventCenter: eventCenter,
//                                             logger: Logger.shared)
//
//        return service
//    }
}
