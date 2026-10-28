// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class PortfolioBalanceReadFlowTests: XCTestCase {
    private var fixtures = [PortfolioReadFixture]()
    override func tearDown(){ fixtures.forEach{$0.queue.cancelAllOperations()}; fixtures = []; super.tearDown() }
    private func make() throws -> PortfolioReadFixture { let f = try PortfolioReadFixture(); fixtures.append(f); return f }
    private func equal<T:Equatable>(_ a:T,_ b:T,file:StaticString = #filePath,line:UInt = #line){ XCTAssertEqual(a,b,file:file,line:line) }
    private func rejected(_ run:() async throws -> Void,file:StaticString = #filePath,line:UInt = #line) async { do{ try await run(); XCTFail("Unverified balance was accepted",file:file,line:line) }catch{} }
    func testTokenBalanceDecodesFreeFrozenAndReservedInWireOrder() async throws { let f = try make(); let values = try await f.read(); equal(values[f.val],PortfolioRawBalance(free:1,reserved:0.3,frozen:0.2)); equal(values[f.val]?.total,1.3); equal(values[f.val]?.transferable,0.8) }
    func testNativeBalanceUsesRuntimeMetadataAndTheLockedFreePart() async throws { let f = try make(); let values = try await f.read([(f.xor,2)]); equal(values[f.xor],PortfolioRawBalance(free:1,reserved:0.3,frozen:0.2)); equal(f.runtime.calls,1) }
    func testMixedNativeAndTokenReadRetainsBothAssets() async throws { let f = try make(); let values = try await f.read([(f.xor,2),(f.val,2)]); equal(Set(values.keys),Set([f.xor,f.val])); equal(f.engine.queries.count,2) }
    func testMultipleTokensAreQueriedAsOneExactKeyBatch() async throws { let f = try make(); let values = try await f.read([(f.val,2),(f.pswap,2)]); equal(values.count,2); equal(f.engine.queries.count,1); equal(Set(f.engine.queries[0]),Set([try f.key(f.val),try f.key(f.pswap)])) }
    func testTokenResponseOrderDoesNotChangeAssetIdentity() async throws { let f = try make(); f.engine.reverse = true; f.engine.values[try f.key(f.pswap)] = PortfolioReadFixture.token(200,30,40); let values = try await f.read([(f.val,2),(f.pswap,2)]); equal(values[f.val]?.free,1); equal(values[f.pswap]?.free,2) }
    func testExplicitNullTokenStorageIsAnAuthoritativeZero() async throws { let f = try make(); f.engine.nullValues = true; equal(try await f.read()[f.val],.zero) }
    func testExplicitNullNativeStorageIsAnAuthoritativeZero() async throws { let f = try make(); f.engine.nullValues = true; equal(try await f.read([(f.xor,2)])[f.xor],.zero) }
    func testEmptyAssetSelectionNeedsNoStorageRequest() async throws { let f = try make(); equal(try await f.read([]),[:]); equal(f.engine.queries.count,0) }
    func testUnavailableConnectionCannotProduceZeroBalances() async throws { let f = try make(); let r = PortfolioSora2BalanceReader(engine:{nil},runtime:{f.runtime},queue:f.queue); await rejected{ _ = try await r.balances(address:f.address,assets:[(f.val,2)]) } }
    func testMissingRuntimeCannotProduceZeroBalances() async throws { let f = try make(); let r = PortfolioSora2BalanceReader(engine:{f.engine},runtime:{nil},queue:f.queue); await rejected{ _ = try await r.balances(address:f.address,assets:[(f.val,2)]) }; equal(f.engine.queries.count,0) }
    func testMalformedWalletAddressCannotReadStorage() async throws { let f = try make(); await rejected{ _ = try await f.subject.balances(address:"not-an-address",assets:[(f.val,2)]) }; equal(f.engine.queries.count,0) }
    func testMalformedTokenIdentifierFailsInsteadOfOmittingTheAsset() async throws { let f = try make(); await rejected{ _ = try await f.read([("invalid",2)]) }; equal(f.engine.queries.count,0) }
    func testOneMalformedTokenPreventsAPartialSuccessfulPortfolio() async throws { let f = try make(); await rejected{ _ = try await f.read([(f.val,2),("invalid",2)]) } }
    func testNegativeTokenPrecisionIsRejectedBeforeStorage() async throws { let f = try make(); await rejected{ _ = try await f.read([(f.val,-1)]) }; equal(f.engine.queries.count,0) }
    func testDuplicateTokenWithDifferentPrecisionIsRejected() async throws { let f = try make(); await rejected{ _ = try await f.read([(f.val,2),(f.val,3)]) } }
    func testStorageTransportFailureIsNotConvertedToZero() async throws { let f = try make(); f.engine.failure = PortfolioReadError.offline; await rejected{ _ = try await f.read() } }
    func testCancelledStorageReadIsNotConvertedToZero() async throws { let f = try make(); f.engine.failure = CancellationError(); do { _ = try await f.read(); XCTFail("Cancelled read succeeded") } catch { XCTAssertTrue(error is CancellationError) } }
    func testMissingResponseKeyIsUnavailableInsteadOfZero() async throws { let f = try make(); f.engine.omitLast = true; await rejected{ _ = try await f.read() } }
    func testMissingOneOfTwoResponseKeysDoesNotReturnPartialBalances() async throws { let f = try make(); f.engine.omitLast = true; await rejected{ _ = try await f.read([(f.val,2),(f.pswap,2)]) } }
    func testDuplicateResponseKeyCannotOverwriteAnEarlierBalance() async throws { let f = try make(); f.engine.duplicate = true; await rejected{ _ = try await f.read() } }
    func testUnexpectedResponseKeyIsRejected() async throws { let f = try make(); f.engine.extra = true; await rejected{ _ = try await f.read() } }
    func testMalformedHexStorageIsUnavailableInsteadOfZero() async throws { let f = try make(); f.engine.values[try f.key(f.val)] = "0xgg"; await rejected{ _ = try await f.read() } }
    func testTruncatedTokenStorageCannotReturnABalance() async throws { let f = try make(); f.engine.values[try f.key(f.val)] = "0x01"; await rejected{ _ = try await f.read() } }
    func testTrailingTokenStorageBytesAreRejected() async throws { let f = try make(); f.engine.values[try f.key(f.val)] = PortfolioReadFixture.token(100,20,30)+"00"; await rejected{ _ = try await f.read() } }
    func testOneCorruptTokenMakesTheWholeReadUnavailable() async throws { let f = try make(); f.engine.values[try f.key(f.pswap)] = "0x01"; await rejected{ _ = try await f.read([(f.val,2),(f.pswap,2)]) } }
    func testPrecisionConversionCannotSilentlyUnderflowToZero() async throws { let f = try make(); await rejected{ _ = try await f.read([(f.val,255)]) } }
    func testExactHighPrecisionTokenBalanceRetainsEveryDigit() async throws { let f = try make(); f.engine.values[try f.key(f.val)] = PortfolioReadFixture.token(123456789,2,3); let r = try await f.read([(f.val,23)]); equal(r[f.val]?.free,Decimal(string:"0.00000000000000123456789")) }
    func testFrozenAboveFreeClampsTransferableWithoutReducingTotal() async throws { let f = try make(); f.engine.values[try f.key(f.val)] = PortfolioReadFixture.token(100,200,30); let b = try await f.read()[f.val]; equal(b?.transferable,0); equal(b?.total,1.3) }
    func testNativeMetadataFailureIsPropagated() async throws { let f = try make(); f.runtime.failure = PortfolioReadError.offline; await rejected{ _ = try await f.read([(f.xor,2)]) }; equal(f.engine.queries.count,0) }
    func testMissingNativeResponseDoesNotPretendTheAccountIsEmpty() async throws { let f = try make(); f.engine.omitLast = true; await rejected{ _ = try await f.read([(f.xor,2)]) } }
    func testMalformedNativeStorageIsUnavailableInsteadOfZero() async throws { let f = try make(); f.engine.nativeBytes = "0xgg"; await rejected{ _ = try await f.read([(f.xor,2)]) } }
    func testTrailingNativeStorageBytesAreRejected() async throws { let f = try make(); f.engine.nativeBytes += "00"; await rejected{ _ = try await f.read([(f.xor,2)]) } }
    func testDuplicateNativeResponseIsRejected() async throws { let f = try make(); f.engine.duplicate = true; await rejected{ _ = try await f.read([(f.xor,2)]) } }
    func testForeignNativeResponseIsRejected() async throws { let f = try make(); f.engine.extra = true; await rejected{ _ = try await f.read([(f.xor,2)]) } }
    func testNegativeNativePrecisionIsRejectedBeforeStorage() async throws { let f = try make(); await rejected{ _ = try await f.read([(f.xor,-1)]) }; equal(f.engine.queries.count,0) }
    func testNativePrecisionUnderflowIsUnavailableWithoutCrashing() async throws { let f = try make(); await rejected{ _ = try await f.read([(f.xor,255)]) } }
    func testShortTokenIdentifierIsRejectedBeforeStorage() async throws { let f = try make(); await rejected{ _ = try await f.read([("0x01",2)]) }; equal(f.engine.queries.count,0) }
    func testRepeatedTokenIdentifierCannotProduceAmbiguousResponses() async throws { let f = try make(); await rejected{ _ = try await f.read([(f.val,2),(f.val,2)]) }; equal(f.engine.queries.count,0) }
    func testEmptyStorageUpdateListIsUnavailable() async throws { let f = try make(); f.engine.emptyUpdates = true; await rejected{ _ = try await f.read() } }
    func testStorageUpdateWithoutChangesIsUnavailable() async throws { let f = try make(); f.engine.missingChanges = true; await rejected{ _ = try await f.read() } }
    func testMalformedResponseKeyIsRejected() async throws { let f = try make(); f.engine.malformedKey = true; await rejected{ _ = try await f.read() } }
    func testMaximumU128RetainsItsExactIntegerValue() async throws { let f = try make(); f.engine.values[try f.key(f.val)] = "0x"+String(repeating:"ff",count:16)+String(repeating:"00",count:32); let value = try await f.read([(f.val,0)])[f.val]; equal(value?.free.stringWithPointSeparator,"340282366920938463463374607431768211455") }
    func testZeroBalanceIsExactEvenAtLargeSupportedScale() async throws { let f = try make(); f.engine.values[try f.key(f.val)] = PortfolioReadFixture.token(0,0,0); equal(try await f.read([(f.val,255)])[f.val],.zero) }
    func testPreCancelledReadDoesNotIssueStorageRequests() async throws { let f = try make(); let task = Task { withUnsafeCurrentTask { $0?.cancel() }; return try await f.read() }; do { _ = try await task.value; XCTFail("Cancelled read succeeded") } catch {} ; equal(f.engine.queries.count,0) }
}
private enum PortfolioReadError: Error { case offline }
@MainActor
private final class PortfolioReadFixture {
    let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue, pswap = WalletAssetId.pswap.rawValue
    let keyData = Data(repeating:3,count:32), queue = OperationQueue(), engine = PortfolioReadEngine(), runtime: PortfolioReadRuntime
    let address: String; var subject: PortfolioSora2BalanceReader!
    static let coder: Result<RuntimeCoderFactory,Error> = Result {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(chainId:PIIndexerClient.soraMainnetGenesis,runtimeMetadataItem:SoraPassport.RuntimeMetadataItem(chain:PIIndexerClient.soraMainnetGenesis,version:133,txVersion:131,metadata:Data(contentsOf:root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec133.scale")),resolver:nil),ownTypes:Data(contentsOf:root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")),dataHasher:.twox256)
        return RuntimeCoderFactory(catalog:snapshot.typeRegistryCatalog,specVersion:133,txVersion:131,metadata:snapshot.metadata)
    }
    init() throws {
        runtime = PortfolioReadRuntime(coder:try Self.coder.get()); address = try SS58AddressFactory().addressFromAccountId(data:keyData,type:Chain.sora.addressType())
        let engine = engine, runtime = runtime; subject = PortfolioSora2BalanceReader(engine:{engine},runtime:{runtime},queue:queue)
        engine.values[try key(val)] = Self.token(100,20,30); engine.values[try key(pswap)] = Self.token(100,20,30)
        engine.nativeBytes = "0x" + String(repeating:"00",count:16) + Self.u128(100) + Self.u128(30) + Self.u128(50) + Self.u128(0)
    }
    func key(_ asset:String) throws -> String { try StorageKeyFactory().accountsKey(account:keyData,asset:Data.sora(hex:asset)).toHex(includePrefix:true) }
    func read(_ assets:[(String,Int16)]? = nil) async throws -> [String:PortfolioRawBalance] { try await subject.balances(address:address,assets:assets ?? [(val,2)]) }
    nonisolated static func u128(_ value:UInt64)->String { var little = value.littleEndian; return withUnsafeBytes(of:&little){Data($0)}.toHex()+String(repeating:"00",count:8) }
    nonisolated static func token(_ free:UInt64,_ frozen:UInt64,_ reserved:UInt64)->String { "0x"+u128(free)+u128(frozen)+u128(reserved) }
}
private final class PortfolioReadRuntime: SoraPassport.RuntimeCodingServiceProtocol {
    let coder:RuntimeCoderFactoryProtocol; var calls = 0, failure:Error?
    init(coder:RuntimeCoderFactoryProtocol){self.coder = coder}
    func fetchCoderFactoryOperation(with timeout:TimeInterval,closure:SoraPassport.RuntimeMetadataClosure?)->BaseOperation<RuntimeCoderFactoryProtocol>{ calls += 1; return ClosureOperation { if let failure = self.failure {throw failure}; return self.coder } }
}
private final class PortfolioReadEngine: JSONRPCEngine {
    var url:URL?; var pendingEngineRequests:[JSONRPCRequest]{[]}
    var emptyUpdates = false, missingChanges = false, malformedKey = false
    var values = [String:String](), nativeBytes = "", nullValues = false, reverse = false, omitLast = false, duplicate = false, extra = false, failure:Error?
    private let lock = NSLock(); private var recorded = [[String]]()
    var queries:[[String]]{ lock.lock();defer{lock.unlock()};return recorded }
    func callMethod<P:Codable,T:Decodable>(_ method:String,params:P?,options:JSONRPCOptions,completion closure:((Result<T,Error>)->Void)?) throws -> UInt16 {
        XCTAssertEqual(method,SoraPassport.RPCMethod.queryStorageAt)
        let params = try JSONSerialization.jsonObject(with:JSONEncoder().encode(params)) as? [Any]; let keys = try XCTUnwrap(params?.first as? [String]); lock.lock();recorded.append(keys);lock.unlock()
        let result = Result<T,Error> {
            if let failure {throw failure}
            var changes:[[Any]] = keys.map { [$0, nullValues ? NSNull() : values[$0] ?? nativeBytes] }
            if reverse {changes.reverse()}; if omitLast {changes = Array(changes.dropLast())}; if duplicate,let first = changes.first {changes.append(first)}; if extra {changes.append(["0x0102",PortfolioReadFixture.token(1,2,3)])}
            if malformedKey, !changes.isEmpty { changes[0][0] = "0xgg" }
            var update:[String:Any] = ["block":"0x"+String(repeating:"ab",count:32)]
            if !missingChanges {update["changes"] = changes}
            let body:[[String:Any]] = emptyUpdates ? [] : [update]
            return try JSONDecoder().decode(T.self,from:JSONSerialization.data(withJSONObject:body))
        }
        DispatchQueue.global().async{closure?(result)};return 1
    }
    func subscribe<P:Codable,T:Decodable>(_ method:String,params:P?,updateClosure:@escaping(T)->Void,failureClosure:@escaping(Error,Bool)->Void)throws->UInt16{throw PortfolioReadError.offline}
    func cancelForIdentifier(_ identifier:UInt16){};func generateRequestId()->UInt16{1};func addSubscription(_ subscription:JSONRPCSubscribing){};func connectIfNeeded(){};func disconnectIfNeeded(){};func unsubsribe(_ identifier:UInt16)throws{}
}
