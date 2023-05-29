import XCTest
@testable import SoraPassport
import FearlessUtils
import RobinHood
import IrohaCrypto
import BigInt
import xxHash_Swift
import SoraKeystore
import SoraFoundation
//
class JSONRPCTests: NetworkBaseTests {
//    struct RpcInterface: Decodable {
//        let version: Int
//        let methods: [String]
//    }
//
//    func testGetMethods() {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let operation = JSONRPCListOperation<RpcInterface>(engine: engine,
//                                                           method: "rpc_methods")
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result.methods)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testGetBlockHash() throws {
//        // given
//
//        var block: UInt32 = 10000
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//
//        let data = Data(Data(bytes: &block, count: MemoryLayout<UInt32>.size).reversed())
//
//        // when
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        let operation = JSONRPCListOperation<String?>(engine: engine,
//                                                      method: RPCMethod.getBlockHash,
//                                                      parameters: [data.toHex(includePrefix: true)])
//
//        OperationQueue().addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result!)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testFinalizedHead() {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//
//        // when
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        let operation = JSONRPCListOperation<String?>(engine: engine,
//                                                      method: "chain_getFinalizedHead",
//                                                      parameters: nil)
//
//        let headOperation = JSONRPCListOperation<String?>(engine: engine,
//                                                          method: "chain_getHeader",
//                                                          parameters: nil)
//
//        OperationQueue().addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result!)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testNetworkType() {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let operation = JSONRPCListOperation<String>(engine: engine,
//                                                     method: "system_chain")
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testHelthCheck() {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let operation = JSONRPCListOperation<Health>(engine: engine,
//                                                     method: "system_health")
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func doNottestAssetList() {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let operation = JSONRPCListOperation<[[String: String]]>(engine: engine,
//                                                     method: "assets_listAssetInfos")
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
    let mlem = [
        "keep private jewel raven party outer trim gloom excess trend fossil heart clay shell tennis",
        "spoil sing silver slam skate identify now weird happy oven build erase ostrich problem tuna",
        "region canvas define skirt grunt motion media maple bubble soul post ahead busy tackle option",
        "disagree cannon basket curve neglect safe electric goose example laugh finger cause audit afford dirt",
        "sound dove deliver gravity mother dog tobacco tray legend track hand warm electric include public",
        "pistol ordinary please comfort column office prison weird coffee flat puzzle flash parade purchase tank",
        "range nose valve kiwi fantasy food exit night paper second minor cute gloom will average",
        "truly tunnel illegal taxi drill oxygen rebel wide dwarf zoo aunt token ball volume hotel",
        "whisper cactus adult jump good exclude name danger tool age gesture fog canoe wage cargo",
        "element broccoli omit festival give february version pear robust bitter scale possible junk junk whisper",
        "require swing dish case boring athlete lumber unusual intact rebuild steel ball cage flush walnut",
        "produce cost catalog ability cereal vote remind cloud erase flock ancient nature rapid question artist",
        "crunch match build noise orient tribe spike pipe shock sugar friend pretty crew because shuffle",
        "laugh reject one holiday summer yellow neglect puzzle replace absurd stay vocal journey glow silver",
        "hover find list sorry firm shadow knife robot custom cram ranch bean term join blue",
        "syrup leopard brush field wink grocery page silk pear mail emotion carry hand blast cancel",
        "gift simple vital praise youth brisk panel perfect protect math zebra struggle rubber parrot area",
        "tent bulb element portion web lesson notable visual recall winter economy joy element length tell",
        "alpha surge crouch wide buddy robust boring desk rifle snake axis consider design top stamp",
        "remind clog laugh universe gauge upgrade settle radio sound arrange equip struggle pigeon outside consider",
        "gain next demand neglect make brand resemble rally bread giant just ill depth alley rather",
        "gas hidden dress resist fold ugly business acquire ensure vacuum boil swallow gloom angry refuse",
        "step drive gown icon identify almost solution tumble second salmon chief galaxy insane phrase female",
        "steel long film ability toward possible prosper loyal fish long elite melt bar theme fuel",
        "dwarf tree list grit twin pistol vicious notable clown occur adapt wrestle narrow twin silver",
        "empty click affair wait tuna trophy impulse science real luxury online visual erode agent mixture",
        "skirt exhaust approve animal jealous quick foster bench bottom vivid magnet hope pole arrange margin",
        "wheat trip mail loud earn lawn museum aspect attitude junior token lend idea tent cereal",
        "gown kid wagon weird giraffe congress orphan motion rally snake sweet adult relax sun honey",
        "upgrade shift penalty dinner palace empty pudding rate faint village sail oak used moon hard",
        "trash dilemma describe prevent latin sunny warrior festival addict fatal casual cigar hole search bachelor",
        "amazing warfare buyer north hover sick cupboard best machine grass dry shove net grab beauty",
        "foot tower recipe distance lion genuine neck cruel chest cash piece process tail goose bargain",
        "critic peanut ostrich ahead approve intact purity air unfair course nothing blame nature narrow crater",
        "easily child rent uncle december gospel sweet skirt envelope stuff salon surge rail road truth",
        "mixed life holiday amount loyal client label verify inhale hamster cool render science farm help",
        "erase rug vocal useless furnace emerge gold tenant biology domain phrase repeat answer machine huge",
        "napkin rookie flat property project front there vacant joke decrease stairs slim weird auto seek",
        "monitor coil portion dolphin van fan remove paper ability any enrich bring olive master absurd",
        "coral alley become renew effort blue bundle west husband vault monster direct brand discover grief",
        "during magic crane loud style impose more message stairs alone inspire cost snake suffer close",
        "prefer buyer luxury average rally runway supply kiss skate smart leg month save inhale ocean",
        "neck setup account become fringe submit genre island invest actor knee pistol mountain mix unique",
        "spare usual decline wear harsh convince achieve impact camera example slam inherit creek sunny tone",
        "panda remember timber page glory snake express joke uncover mixture trade caught film spice diesel",
        "good knee nose pull square medal faculty average father banana exist pink slight energy woman",
        "damage ethics silk saddle humor face course awake vessel lake word find exotic canvas oven",
        "style street denial tape duty slender total crucial quiz book wrap buddy pond solution shed",
        "junk glove blood access two lift luggage balcony faith mango surface purpose flavor pizza provide",
        "trash document august inch rescue saddle involve motor admit lunar enroll high forum cable casino",
        "galaxy flight champion custom jeans category number card tent hover taste bracket apart episode grab",
        "prize pudding moon inside crop general intact sketch scout novel erosion under view crouch grass",
        "canyon secret host rain miss escape issue insect catch broom appear dismiss scatter blood absorb",
        "cup prefer logic fatal immense sting opera orphan mixture slush parade whip snack pupil logic",
        "banner trip winner mass resist toddler leg helmet miracle arch common will need prepare protect",
        "alien vendor stool creek shiver sibling garden trade eagle unaware relief issue evil people stick",
        "nasty lift whip slim embrace erosion tomorrow exhibit pill tattoo enemy aisle repeat feature frog",
        "exercise swing firm mixed fine amateur sniff another march marble planet trouble gorilla volume soul",
        "effort topic deny silly ranch wide expect holiday page napkin reflect jazz asthma horse blue",
        "suggest attend number gas myth chuckle digital weekend axis drop opera brown brown parade park",
        "estate toe escape color lamp connect involve conduct design utility either sting sound twice promote",
        "detail calm april cake broken yellow normal lunch slam feel aspect lucky together fox solution",
        "basic seat couch stay unveil draft oven just boat light sail sand nice throw miss",
        "chief opinion female throw calm top blossom era track lamp hollow cupboard gap window twin",
        "peanut rug elegant anchor aspect spare popular lounge girl offer run fault able elder lobster",
        "mystery rapid knee cement model dwarf absurd olympic exact identify south panic depart trouble announce",
        "sudden soccer tuition pepper fetch abuse theory first ten else dumb recall entire victory infant",
        "destroy west render bitter depend urge poverty start olympic ship ghost kiwi kitchen split remain",
        "nature humble need chief buddy napkin bundle example build item weapon pact theme save ordinary",
        "become bracket junior engage acoustic almost salute knife image call fuel gravity canvas hour lamp",
        "human tomato alter reflect right innocent autumn sock almost clock blossom tank cube exile vessel",
        "bargain boost mushroom admit flavor auto infant venue sausage tube elite outer crystal quantum author",
        "poem vanish debris truth deputy accident annual reveal afford put current grab agree pistol believe",
        "name away diet ceiling absurd boat indoor glue audit welcome survey car gate jealous boat",
        "business load change view casual blind atom loop despair cliff dilemma ankle funny neither patrol",
        "casual cigar gesture proud minute repeat rack rural speak right throw wide ribbon engage bus",
        "annual noble build venue match reason symbol shallow rose culture supply coast female cube cousin",
        "inner light cake group old dinosaur duck pattern kangaroo update story strong pattern beyond napkin",
        "trumpet guitar day fatigue bargain fault come miss rocket load time scan clap hazard verb",
        "absurd end elegant motion spawn assume worth carry want siren lab box shine custom lobster",
        "payment female collect sugar work erupt hungry indoor match camera husband jeans tiny permit stick",
        "aware salad august squeeze weekend army embrace midnight brother critic accuse danger off merge glass",
        "garlic job language carbon soul boost evidence pizza exit velvet solar coach clerk journey front",
        "gospel render later wing orbit sheriff home leisure garlic crowd print fever quick tiny amused"
    ]
    func testNeedsMigration() throws{
        for mnem in mlem {
          try performMigrationTest(mnemonic: mnem)
        }
    }

    func performMigrationTest(mnemonic: String) throws {
        let devUrl = "wss://ws.framenode-2.r0.dev.sora2.soramitsu.co.jp"
        let url = URL(string: devUrl)!
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        let keystore = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        try AccountCreationHelper.createAccountFromMnemonic(mnemonic,
                                                            cryptoType: .sr25519,
                                                            networkType: .sora,
                                                            keychain: keystore,
                                                            settings: settings)
        guard let account = settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue) else {
            XCTFail("Can't find address")
            return
        }
        let irohaFacade: IRKeypairFacadeProtocol = IRKeypairFacade()
        let keypair = try irohaFacade.deriveKeypair(from: mnemonic)

        // when
        let address = "did_sora_\(keypair.publicKey().decentralizedUsername)@sora"//account.address
//        let str = account.publicKeyData.prefix(20).hexEncodedString()
        /*account.publicKeyData.toHex().prefix(20)*/
        let operation = JSONRPCListOperation<Bool>(engine: engine,
                                                     method: "irohaMigration_needsMigration",
                                                     parameters: [address])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            logger.debug("\(mnemonic) Received response: \(result)")
            if(result == true) {
//                try testMigrationService(mnemonic)
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
//
//    func NotestBalance() {
//        let devUrl = "wss://ws.framenode-1.s1.dev.sora2.soramitsu.co.jp/"
//
//        let url = URL(string: devUrl)!//URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        let keystore = InMemoryKeychain()
//        let settings = InMemorySettingsManager()
//
//        let accountId = "5CRrhU9z7CuKnMsVm9bW9JzMWJCihPzsJexbrMuNxgJk5zdu"
//        let assetId = "0x0200040000000000000000000000000000000000000000000000000000000000"
//
//        let operation = JSONRPCListOperation<BalanceInfo>(engine: engine,
//                                            method: RPCMethod.freeBalance,
//                                            parameters: [accountId, assetId])
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testNonceFetch() {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let address = "5DfCSrkgzUAsCtsugSbQRgAqbRk2p3L39oxRRvhLsywHPR37"
//        let operation = JSONRPCListOperation<UInt32>(engine: engine,
//                                                     method: RPCMethod.getExtrinsicNonce,
//                                                     parameters: [address])
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func DoNotTestHeader() {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let storageFacade = SubstrateDataStorageFacade.shared
//        let eventCenter = EventCenter()//MockEventCenterProtocol()
//        let operationManager = OperationManager()
//
//        let runtimeRegistry = createDefaultService(storageFacade: storageFacade,
//                                           eventCenter: eventCenter,
//                                           operationManager: operationManager)
//
//        runtimeRegistry.setup()
//
//        let settings = WebSocketServiceSettings(url: url,
//                                                addressType: 42,
//                                                address: "5DfCSrkgzUAsCtsugSbQRgAqbRk2p3L39oxRRvhLsywHPR37")
//
//        let webSocketService = WebSocketServiceFactory.createService()
//
//
//        webSocketService.update(settings: settings)
//
//        webSocketService.setup()
//
//
////        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let blockHash = "0x6328538452255a177f1abb7b4b9757aad7b3bcb76eb87c11e3d16bc8e452801f"
//
//        let operation = JSONRPCListOperation<Block.Header>(engine: webSocketService.connection!,
//                                                           method: RPCMethod.getHeader,
//                                                           parameters: [blockHash])
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//
//            let blockNumber = BigUInt(hexString: result.number, radix: 16)//UInt64(BigUInt(blockNumberData))
//            logger.info("blockNumber: \(blockNumber?.description)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testBlockExtraction() throws {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let blockHash = "0x6328538452255a177f1abb7b4b9757aad7b3bcb76eb87c11e3d16bc8e452801f"
//
//        let operation = JSONRPCListOperation<JSON>(engine: engine,
//                                                               method: "chain_getBlock",
//                                                               parameters: [blockHash])
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testPolkadotExistentialDeposit() throws {
//        let balanceData = try Data(hexString: "0x00e40b54020000000000000000000000")
//
//        let scaleDecoder = try ScaleDecoder(data: balanceData)
//        let balance = try Balance(scaleDecoder: scaleDecoder)
//
//        let decimalBalance = Decimal.fromSubstrateAmount(balance.value, precision: 10)!
//        Logger.shared.debug("Existential deposit on polkadot: \(decimalBalance.stringWithPointSeparator)")
//    }
//
//    func doNottestAccountInfoPolkadot() throws {
//        try performAccountInfoTest(url: URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!,
//                                   address: "5DfCSrkgzUAsCtsugSbQRgAqbRk2p3L39oxRRvhLsywHPR37",
//                                   type: UInt16(42),
//                                   precision: 10)
//    }
//
//    func performAccountInfoTest(url: URL, address: String, type: UInt16, precision: Int16) throws {
//        // given
//
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let identifier = try SS58AddressFactory().accountId(fromAddress: address,
//                                                            type: type)
//
//        let key = try StorageKeyFactory().accountInfoKeyForId(identifier).toHex(includePrefix: true)
//
//        let operation = JSONRPCListOperation<JSONScaleDecodable<AccountInfo>>(engine: engine,
//                                                                              method: RPCMethod.getStorage,
//                                                                              parameters: [key])
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//
//            guard let accountData = result.underlyingValue?.data else {
//                XCTFail("Empty account id")
//                return
//            }
//
//            Logger.shared.debug("Free: \(Decimal.fromSubstrateAmount(accountData.free.value, precision: precision)!)")
//            Logger.shared.debug("Reserved: \(Decimal.fromSubstrateAmount(accountData.reserved.value, precision: precision)!)")
//            Logger.shared.debug("Misc Frozen: \(Decimal.fromSubstrateAmount(accountData.miscFrozen.value, precision: precision)!)")
//            Logger.shared.debug("Fee Frozen: \(Decimal.fromSubstrateAmount(accountData.feeFrozen.value, precision: precision)!)")
//
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func DoNotTestStakingLedgerPolkadot() throws {
//        try performStakingInfoTest(url: URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!,
//                                   address: "5DfCSrkgzUAsCtsugSbQRgAqbRk2p3L39oxRRvhLsywHPR37",
//                                   type: SNAddressType(42),
//                                   precision: 10)
//    }
//
//    func performStakingInfoTest(url: URL, address: String, type: UInt16, precision: Int16) throws {
//        // given
//
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let identifier = try SS58AddressFactory().accountId(fromAddress: address,
//                                                            type: type)
//
//        let key = try StorageKeyFactory().stakingInfoForControllerId(identifier).toHex(includePrefix: true)
//
//        let operation = JSONRPCListOperation<JSONScaleDecodable<StakingLedger>>(engine: engine,
//                                                                                method: RPCMethod.getStorage,
//                                                                                parameters: [key])
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//
//            guard let stakingLedger = result.underlyingValue else {
//                XCTFail("Empty account id")
//                return
//            }
//
//            Logger.shared.debug("Total: \(Decimal.fromSubstrateAmount(stakingLedger.total, precision: precision)!)")
//            Logger.shared.debug("Active: \(Decimal.fromSubstrateAmount(stakingLedger.active, precision: precision)!)")
//
//            for unlocking in stakingLedger.unlocking {
//                Logger.shared.debug("Unlocking: \(Decimal.fromSubstrateAmount(unlocking.value, precision: precision)!) at: \(unlocking.era)")
//            }
//
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func doNottestPolkadotActiveEra() {
//        performGetActiveEra(url: URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!)
//    }
//
//    func performGetActiveEra(url: URL) {
//        // given
//
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let storageFactory = StorageKeyFactory()
//        let key = try! storageFactory
//            .createStorageKey(moduleName: "Staking", storageName: "ActiveEra")
//            .toHex(includePrefix: true)
//
//        let operation = JSONRPCListOperation<JSONScaleDecodable<Era>>(engine: engine,
//                                                                         method: RPCMethod.getStorage,
//                                                                         parameters: [key])
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//
//            guard let activeEra = result.underlyingValue else {
//                XCTFail("Empty account id")
//                return
//            }
//
//            Logger.shared.debug("Active Era: \(activeEra)")
//
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func doNottestGetMetaData() {
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//        let engine = WebSocketEngine(url: URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!, logger: logger)
//        let method = RPCMethod.getRuntimeMetadata
//
//        let metaOperation = JSONRPCListOperation<JSONScaleDecodable<RuntimeMetadata>>(engine: engine,
//                                                               method: method)
//
//        operationQueue.addOperations([metaOperation], waitUntilFinished: true)
//
//        do {
//            let result = try metaOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            let metadata = result.underlyingValue!
//            let prefixCoding = ConstantCodingPath.chainPrefix
//            let depositCoding = ConstantCodingPath.existentialDeposit
//            let assetsCoding = ConstantCodingPath.assetInfos
//
//            let prefix = metadata.getConstant(in: prefixCoding.moduleName, constantName: prefixCoding.constantName)
//            let existentialDeposit = metadata.getConstant(in: depositCoding.moduleName, constantName: depositCoding.constantName)
//            let assetInfo = metadata.getConstant(in: assetsCoding.moduleName, constantName: assetsCoding.constantName)
//            //"System".constants"SS58Prefix", "Balances".constants."ExistencialDeposit", "Assets" "AssetInfos"
//            print(prefix)
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func doNottestGetRuntimeVersion() {
//        // given
//
//        let url = URL(string: "wss://ws.validator.dev.polkadot-rust.soramitsu.co.jp:443")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let operation = JSONRPCListOperation<RuntimeVersion>(engine: engine,
//                                                             method: "chain_getRuntimeVersion",
//                                                             parameters: [])
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testMigrationService(_ passphrase: String = "spoil sing silver slam skate identify now weird happy oven build erase ostrich problem tuna") throws{
//        // given
//        let url = URL(string: "wss://ws.framenode-1.s1.dev.sora2.soramitsu.co.jp/")!
//        let logger = Logger.shared
//        let keystore = InMemoryKeychain()
//        var settings = InMemorySettingsManager()
//        settings.externalGenesis = "0xab0b7eee8390fc6cd50efd697fc3cde23ecd7a80469ffcb6457111f82a0c4a22"
//        SettingsManager.shared.set(value: settings.externalGenesis, for: SettingsKey.externalGenesis.rawValue)
//        let eventCenter = EventCenter()
//        let operationManager = OperationManager()
//        let storageFacade = SubstrateStorageTestFacade()
//
//        try AccountCreationHelper.createAccountFromMnemonic(passphrase,
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
//        let expectation = XCTestExpectation()
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
//        let runtimeRegistry = createDefaultService(storageFacade: storageFacade,
//                                           eventCenter: eventCenter,
//                                           operationManager: operationManager)
//
//        runtimeRegistry.setup()
//
//        wait(for: [], timeout: 60)
//
//        let migrationService = MigrationService(eventCenter: eventCenter,
//                                                keystore: keystore,
//                                                settings: settings,
//                                                webSocketService: webSocketService,
//                                                runtimeService: runtimeRegistry,
//                                                operationManager: operationManager,
//                                                logger: logger)
//        migrationService.requestMigration { (result) in
//            switch result {
//            case .failure(let error):
//                logger.error(error.localizedDescription)
//                XCTFail("Did receive error: \(error)")
//            case .success(let res):
//                logger.info(res)
//                expectation.fulfill()
//            }
//        }
//
//        wait(for: [expectation], timeout: 545.0)
//    }
//
//    func MigrationExtrinsic() throws {
//        // given
//
//        let logger = Logger.shared
//        let keystore = InMemoryKeychain()
//        let settings = InMemorySettingsManager()
//        let passphrase = "keep private jewel raven party outer trim gloom excess trend fossil heart clay shell tennis"
//        let url = URL(string: "wss://ws.framenode-1.s1.dev.sora2.soramitsu.co.jp/")!
//
//        try AccountCreationHelper.createAccountFromMnemonic(passphrase,
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
//        let entropy = try keystore.fetchEntropyForAddress(account.address)
//        let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy!)
//        let irohaKey = try IRKeypairFacade().deriveKeypair(from: mnemonic.toString())
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
//        let data = try NSData.init(data: message!).sha3(IRSha3Variant.variant256)
//        let signature = try irohaSigner.sign(data, privateKey: irohaKey.privateKey())
//        logger.debug(did)
//
//        let closure: ExtrinsicBuilderClosure = { builder in
//            let callFactory = SubstrateCallFactory()
//
//            let migrateCall = try callFactory.migrate(irohaAddress: did,
//                                                      irohaKey: irohaKey.publicKey().rawData().toHex(),
//                                                      signature: signature.rawData().toHex())
//
//            return try builder
//                .adding(call: migrateCall)
//        }
//
//        let expectation = XCTestExpectation()
//
//        let operationQueue = OperationQueue()
//
//        extrinsicService.submit(closure, signer: signer, watch: true, runningIn: .main) { result, extrinsicHash in
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
//                        self.getBlockEvents(block, extrinsicHash: extrinsicHash!, engine: engine, coderOperation: runtimeRegistry.fetchCoderFactoryOperation())
//                        expectation.fulfill()
//                    default:
//                        logger.info("extrinsic status \(state)")
//                    }
////
//                } failureClosure: { (error, unsubscribed) in
//                    XCTFail("Did receive error: \(error)")
//                }
//                subscription.remoteId = hash
//
//                webSocketService.engine?.addSubscription(subscription)
//            case .failure(let error):
//                XCTFail("Did receive error: \(error)")
//            }
//
//
//        }
//
//        wait(for: [expectation], timeout: 545.0)
//        /*
//         val did = "did:sora:${Hex.toHexString(keys.public.encoded).substring(0, 20)}"
//               val irohaAddress = did.didToAccountId()
//               val message = irohaAddress + Hex.toHexString(keys.public.encoded).toUpperCase()
//
//               val signature = cryptoAssistant.signEd25519(message.toByteArray(charset("UTF-8")), keys)
//         */
//    }
//
//    func testSubqueryParsing() {
//       let testJson = """
//        {
//                  "id": "0xa76fbd7dc3454410b3deefccd2fca87c296f5233edcf350db9eadeda7de9a078",
//                  "blockHash": "0xc63154d2fc97b6055457ca8e1618bd3b9f6e71f5c252edb04c0c7d55bdb1d9c5",
//                  "module": "assets",
//                  "method": "transfer",
//                  "address": "cnX6qoYnFwxnxkVxi5LQQ45i6DQDr1rXUwjtEG3YLTaV7wz3q",
//                  "timestamp": 1638535974,
//                  "networkFee": "0.000700000000000000",
//                  "data": {
//                    "to": "cnUnqLks1ccNbtVLrVW3Ss8VfoUBuKvjBNbqmLhHUtBY24Rp5",
//                    "from": "cnX6qoYnFwxnxkVxi5LQQ45i6DQDr1rXUwjtEG3YLTaV7wz3q",
//                    "amount": "30.000000000000000000",
//                    "assetId": "0x003f5efd70ab473210c0fda782996c1fd8a4cba182cb3cdc994ef7effd5b90ed"
//                  },
//                  "error": null,
//                  "execution": {
//                    "success": true
//                  }
//                }
//        """.data(using: .utf8)
//        let testJson2 = """
//         {
//                   "id": "0xa76fbd7dc3454410b3deefccd2fca87c296f5233edcf350db9eadeda7de9a078",
//                   "blockHash": "0xc63154d2fc97b6055457ca8e1618bd3b9f6e71f5c252edb04c0c7d55bdb1d9c5",
//                   "module": "assets",
//                   "method": "transfer",
//                   "address": "cnX6qoYnFwxnxkVxi5LQQ45i6DQDr1rXUwjtEG3YLTaV7wz3q",
//                   "timestamp": "1638535974",
//                   "networkFee": "0.000700000000000000",
//                   "data": {
//                     "to": "cnUnqLks1ccNbtVLrVW3Ss8VfoUBuKvjBNbqmLhHUtBY24Rp5",
//                     "from": "cnX6qoYnFwxnxkVxi5LQQ45i6DQDr1rXUwjtEG3YLTaV7wz3q",
//                     "amount": "30.000000000000000000",
//                     "assetId": "0x003f5efd70ab473210c0fda782996c1fd8a4cba182cb3cdc994ef7effd5b90ed"
//                   },
//                   "error": null,
//                   "execution": {
//                     "success": true
//                   }
//                 }
//         """.data(using: .utf8)
//        do {
//            let result = try JSONDecoder().decode(
//                SubqueryHistoryElement.self,
//                from: testJson!
//            )
//            let result2 = try JSONDecoder().decode(
//                SubqueryHistoryElement.self,
//                from: testJson2!
//            )
//            print(result, result2)
//        }
//        catch {
//            print("e")
//        }
//    }
//
//    func doNottestEvents() throws {
//        let hash = "0x27b8348fb35acccee0e78b8bed674178903f60bb94efa9643882916a74c8ca99"
//        let ext = "0x3d0584902be1eecbee9592a57da5fec4c8d246fbed0890f9db12dcce68ac6bf66a712c0118ed519f2e12a1af67c2007911ff2c742c1bbee84d44400eb45853736fa3c97b92cfeff4ee5c8ec883923a57b78096ddb532e8d0d1d27aa72f6bd79f9dfcd58a050300002200886469645f736f72615f383733363038343665663035303538306363663240736f726101013930326265316565636265653935393261353764613566656334633864323436666265643038393066396462313264636365363861633662663636613731326301023164643162343733353230363465313232316465623438613139343763333134623832626238333230623036326266363132383736396162343765646161633331303834316231333133646161313664663339303936326438666239323233336339346132346539613633323831653837306330646437333431393436303036"
////        let logger = Logger.shared
//        let keystore = InMemoryKeychain()
//        let settings = InMemorySettingsManager()
//        let passphrase = "keep private jewel raven party outer trim gloom excess trend fossil heart clay shell tennis"
//        let url = URL(string: "wss://ws.framenode-1.s1.dev.sora2.soramitsu.co.jp/")!//URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!//
//
//        try AccountCreationHelper.createAccountFromMnemonic(passphrase,
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
//        let storageFacade = SubstrateStorageTestFacade()
//        let eventCenter = EventCenter()
//        let operationManager = OperationManager()
//
//        let runtimeRegistry = createDefaultService(storageFacade: storageFacade,
//                                                   eventCenter: eventCenter,
//                                                   operationManager: operationManager)
//
//        runtimeRegistry.setup()
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
//
//        getBlockEvents(hash, extrinsicHash: ext, engine: engine, coderOperation: runtimeRegistry.fetchCoderFactoryOperation())
//    }
//
//    private func getBlockEvents(_ hash: String, extrinsicHash: String, engine: JSONRPCEngine, coderOperation: BaseOperation<RuntimeCoderFactoryProtocol>) {
//        let logger = Logger.shared
//        let storageFactory = StorageKeyFactory()
//        let operationQueue = OperationQueue()
//        let path = StorageCodingPath(moduleName: "System", itemName: "Events")
//        let remoteKey = try! storageFactory.createStorageKey(moduleName: path.moduleName, storageName: path.itemName)
//
//        let requestFactory = StorageRequestFactory(remoteFactory: storageFactory, operationManager: OperationManager())
//        let block = try? Data(hex: hash)
//        let wrapper: CompoundOperationWrapper<[StorageResponse<[EventRecord]>]> =
//            requestFactory.queryItems(engine: engine,
//                                      keys: { [remoteKey] },
//                                      factory: { try coderOperation.extractNoCancellableResultData() },
//                                      storagePath: path,
//                                      at: block)
//        wrapper.allOperations.forEach { $0.addDependency(coderOperation) }
//
//        let fetchBlockOperation: JSONRPCOperation<[String], SignedBlock> =
//            JSONRPCOperation(engine: engine,
//                             method: RPCMethod.getChainBlock,
//                             parameters: [hash])
//
//        let parseOperation = createParseOperation(dependingOn: fetchBlockOperation)
//
//        parseOperation.addDependency(fetchBlockOperation)
//
//        let operations = [coderOperation] + wrapper.allOperations + [fetchBlockOperation, parseOperation]
//
//        operationQueue.addOperations(operations, waitUntilFinished: true)
//        do {
//            if let records = try wrapper.targetOperation.extractNoCancellableResultData().first?.value {
//                // here we get list of event records as json objects, we can try to map to target event we are searching
//                let metadata = try coderOperation.extractNoCancellableResultData().metadata
//
//                let blockExtrinsics = try parseOperation.extractResultData()
//
//                let eventIndex = blockExtrinsics?.firstIndex(of: extrinsicHash)!
//
//                let record = records[eventIndex!]
//
//                Logger.shared.info("Extrinsic events found: \(records)")
//            } else {
//                Logger.shared.info("No events found")
//            }
//        } catch {
//            XCTFail("Did receive error: \(error)")
//        }
//    }
//
//    private func createParseOperation(dependingOn fetchOperation: BaseOperation<SignedBlock>)
//    -> BaseOperation<[String]> {
//
//        return ClosureOperation {
//            let block = try fetchOperation
//                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//                .block
//
//            return block.extrinsics
//        }
//    }
//
//    private func createDefaultService(storageFacade: StorageFacadeProtocol,
//                              eventCenter: EventCenterProtocol,
//                              operationManager: OperationManagerProtocol) -> RuntimeRegistryService {
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
//
//    //MARK: - Polkaswap tests
//
//    struct isSwapAvailableParams: Encodable {
//        let dexId: UInt32
//        let inputAssetId: String
//        let outputAssetId: String
//    }
//
//    func testIsSwapAvailable() throws {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let dexId: UInt32 = 0
//        let VALId: String = "0x0200040000000000000000000000000000000000000000000000000000000000"
//        let PSWAPId: String = "0x0200040000000000000000000000000000000000000000000000000000000000"
//
//        let paramsArray: [JSONAny] = [JSONAny(dexId),
//                                      JSONAny(VALId),
//                                      JSONAny(PSWAPId)]
//
//        let operation = JSONRPCOperation<[JSONAny], Bool>(engine: engine,
//                                                             method: RPCMethod.checkIsSwapPossible,
//                                                             parameters: paramsArray)
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testObtainingAvailableMarketAlgorithms() throws {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let dexId: UInt32 = 0
//        let XORId: String = "0x0200000000000000000000000000000000000000000000000000000000000000"
//        let VALId: String = "0x0200040000000000000000000000000000000000000000000000000000000000"
//        let PSWAPId: String = "0x0200040000000000000000000000000000000000000000000000000000000000"
//
//        let paramsArray: [JSONAny] = [JSONAny(dexId),
//                                      JSONAny(XORId),
//                                      JSONAny(PSWAPId)]
//
//        let operation = JSONRPCOperation<[JSONAny], [String]>(engine: engine,
//                                                             method: RPCMethod.availableMarketAlgorithms,
//                                                             parameters: paramsArray)
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    struct SwapValues: Decodable {
//        let amount: String
//        let fee: String
//        let rewards: [String]
//        let amount_without_impact: String
//    }
//
//    func testRecalculationOfSwapValuesWithDesiredInput() throws {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let dexId: UInt32 = 0
//        let XORId: String = "0x0200000000000000000000000000000000000000000000000000000000000000"
////        let VALId: String = "0x0200040000000000000000000000000000000000000000000000000000000000"
//        let PSWAPId: String = "0x0200040000000000000000000000000000000000000000000000000000000000"
//        let amount: String = "11"
//        let swapVariant = "WithDesiredInput"
//        let liquiditySourceType = "MulticollateralBondingCurvePool"
//        let filterMode = "Disabled"
//
//        let paramsArray: [JSONAny] = [JSONAny(dexId),
//                                      JSONAny(XORId),
//                                      JSONAny(PSWAPId),
//                                      JSONAny(amount),
//                                      JSONAny(swapVariant),
//                                      JSONAny([liquiditySourceType]),
//                                      JSONAny(filterMode)
//        ]
//
//        let operation = JSONRPCOperation<[JSONAny], SwapValues>(engine: engine,
//                                                             method: RPCMethod.recalculateSwapValues,
//                                                             parameters: paramsArray)
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testRecalculationOfSwapValuesWithDesiredOutput() throws {
//        // given
//
//        let url = URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!
//        let logger = Logger.shared
//        let operationQueue = OperationQueue()
//
//        let engine = WebSocketEngine(url: url, logger: logger)
//
//        // when
//
//        let dexId: UInt32 = 0
//        let XORId: String = "0x0200000000000000000000000000000000000000000000000000000000000000"
////        let VALId: String = "0x0200040000000000000000000000000000000000000000000000000000000000"
//        let PSWAPId: String = "0x0200040000000000000000000000000000000000000000000000000000000000"
//        let amount: String = "11"
//        let swapVariant = "WithDesiredOutput"
//        let liquiditySourceType = "MulticollateralBondingCurvePool"
//        let filterMode = "Disabled"
//
//        let paramsArray: [JSONAny] = [JSONAny(dexId),
//                                      JSONAny(XORId),
//                                      JSONAny(PSWAPId),
//                                      JSONAny(amount),
//                                      JSONAny(swapVariant),
//                                      JSONAny([liquiditySourceType]),
//                                      JSONAny(filterMode)
//        ]
//
//        let operation = JSONRPCOperation<[JSONAny], SwapValues>(engine: engine,
//                                                             method: RPCMethod.recalculateSwapValues,
//                                                             parameters: paramsArray)
//
//        operationQueue.addOperations([operation], waitUntilFinished: true)
//
//        // then
//
//        do {
//            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//            logger.debug("Received response: \(result)")
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
}
