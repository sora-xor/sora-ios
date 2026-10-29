// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import CoreData
import CoreImage
import UIKit
import IrohaCrypto
import RobinHood
import SoraKeystore
import SoraFoundation
import SSFUtils
import SSFCrypto
import XCTest
@testable import SoraPassport

final class LegacyStorageAndFormattingTests: XCTestCase {
    func testScryptHeaderUsesTheArchiveLittleEndianWireLayout() throws {
        let salt = Data(0..<32)
        let parameters = try SoraPassport.ScryptParameters(salt: salt, scryptN: 0x01020304, scryptP: 0x05060708, scryptR: 0x090a0b0c)
        let expected = salt + Data([4, 3, 2, 1, 8, 7, 6, 5, 12, 11, 10, 9])
        XCTAssertEqual(parameters.encode(), expected)
        let decoded = try SoraPassport.ScryptParameters(data: expected + Data([0xde, 0xad]))
        XCTAssertEqual(decoded.salt, salt); XCTAssertEqual(decoded.scryptN, 0x01020304)
        XCTAssertEqual(decoded.scryptP, 0x05060708); XCTAssertEqual(decoded.scryptR, 0x090a0b0c)
    }
    func testScryptRejectsTruncatedHeadersAndInvalidSaltSizes() {
        for length in [0, 1, 31, 32, 43] { XCTAssertThrowsError(try SoraPassport.ScryptParameters(data: Data(repeating: 0, count: length))) }
        for length in [0, 31, 33] { XCTAssertThrowsError(try SoraPassport.ScryptParameters(salt: Data(repeating: 0, count: length), scryptN: 1, scryptP: 1, scryptR: 1)) }
    }
    func testGeneratedScryptHeadersHaveIndependentSaltsAndDocumentedDefaults() throws {
        let first = try SoraPassport.ScryptParameters(), second = try SoraPassport.ScryptParameters()
        XCTAssertEqual(first.salt.count, 32); XCTAssertEqual(second.salt.count, 32); XCTAssertNotEqual(first.salt, second.salt)
        XCTAssertEqual(first.scryptN, 32768); XCTAssertEqual(first.scryptP, 1); XCTAssertEqual(first.scryptR, 8)
        XCTAssertEqual(first.encode().count, 44)
    }
    func testExtrinsicCryptoDiscriminantsAndSignatureSizesMatchTheirWireContract() {
        let vectors: [(UInt8, CryptoType, Int)] = [(0, .ed25519, 64), (1, .sr25519, 64), (2, .ecdsa, 65)]
        for (byte, crypto, length) in vectors {
            XCTAssertEqual(CryptoType(version: byte), crypto); XCTAssertEqual(crypto.version, byte); XCTAssertEqual(crypto.signatureLength, length)
        }
        for byte in [UInt8(3), 127, 255] { XCTAssertNil(CryptoType(version: byte)) }
    }
    func testRewardDestinationsRoundTripTheirExactTaggedArrays() throws {
        let vectors: [(RewardDestinationArg, String)] = [(.staked, "Staked"), (.stash, "Stash"), (.controller, "Controller")]
        for (destination, name) in vectors {
            let bytes = try JSONEncoder().encode(destination)
            let values = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [Any])
            XCTAssertEqual(values.count, 2); XCTAssertEqual(values[0] as? String, name); XCTAssertTrue(values[1] is NSNull)
            let decoded = try JSONDecoder().decode(RewardDestinationArg.self, from: bytes)
            XCTAssertEqual(try JSONEncoder().encode(decoded), bytes)
        }
        let bytes = try JSONEncoder().encode(RewardDestinationArg.account(Data([1, 2, 3])))
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String])
        XCTAssertEqual(values, ["Account", "AQID"])
        guard case let .account(account) = try JSONDecoder().decode(RewardDestinationArg.self, from: bytes) else { return XCTFail("Lost account destination") }
        XCTAssertEqual(account, Data([1, 2, 3]))
    }
    func testRewardDestinationsRejectUnknownTagsAndMissingAccounts() {
        for json in [#"["Unknown",null]"#, #"["Account"]"#, #"["Account",1]"#, "[]", "{}"] {
            XCTAssertThrowsError(try JSONDecoder().decode(RewardDestinationArg.self, from: Data(json.utf8)), json)
        }
    }
    func testLocalStorageKeysSeparateChainsRemoteKeysAndAssetNamespaces() throws {
        let factory = LocalStorageKeyFactory(), remote = Data([1, 2, 3])
        let first = try factory.createKey(from: remote, key: "sora-mainnet")
        XCTAssertEqual(first.count, 64); XCTAssertEqual(first, try factory.createKey(from: remote, key: "sora-mainnet"))
        XCTAssertNotEqual(first, try factory.createKey(from: remote, key: "sora-testnet"))
        XCTAssertNotEqual(first, try factory.createKey(from: Data([1, 2, 4]), key: "sora-mainnet"))
        let path: StorageCodingPath = .account
        XCTAssertNotEqual(try factory.createFromStoragePath(path, chainId: "mainnet"), try factory.createFromStoragePath(path, chainAssetKey: "mainnet-XOR"))
        XCTAssertNotEqual(try factory.createFromStoragePath(path, encodableElement: UInt32(1), chainId: "mainnet"), try factory.createFromStoragePath(path, encodableElement: UInt32(2), chainId: "mainnet"))
    }
    private var asset: WalletAsset { WalletAsset(identifier: "fixture-XOR", name: LocalizableResource { _ in "SORA" }, symbol: "XOR", precision: 2) }
    func testInputFormattingDoesNotRoundUpAnAmountBeyondTheAssetPrecision() {
        let formatter = NumberFormatterFactory().createInputFormatter(for: asset).value(for: Locale(identifier: "en_US"))
        XCTAssertEqual(formatter.string(from: NSDecimalNumber(string: "1234.569")), "1,234.56")
        XCTAssertEqual(formatter.maximumFractionDigits, 2)
    }
    func testDisplayFormattingUsesTheRequestedLocaleAndAssetPrecision() {
        let resource = NumberFormatterFactory().createDisplayFormatter(for: asset)
        XCTAssertEqual(resource.value(for: Locale(identifier: "en_US")).stringFromDecimal(Decimal(string: "1234.569")!), "1,234.56")
        XCTAssertEqual(resource.value(for: Locale(identifier: "de_DE")).stringFromDecimal(Decimal(string: "1234.569")!), "1.234,56")
    }
    func testMissingAssetFormattingStillProducesAReadableNumber() {
        let factory = NumberFormatterFactory(), locale = Locale(identifier: "en_US")
        XCTAssertEqual(factory.createInputFormatter(for: nil).value(for: locale).string(from: 12), "12")
        XCTAssertEqual(factory.createDisplayFormatter(for: nil).value(for: locale).stringFromDecimal(12), "12")
    }
    func testTokenAndFeeFormattingCarryTheSameSymbolAndPrecision() {
        let factory = NumberFormatterFactory(), locale = Locale(identifier: "en_US")
        let token = factory.createTokenFormatter(for: asset).value(for: locale).stringFromDecimal(Decimal(string: "12.349")!)
        let fee = factory.createFeeTokenFormatter(for: asset).value(for: locale).stringFromDecimal(Decimal(string: "12.349")!)
        XCTAssertEqual(token, fee); XCTAssertTrue(token?.contains("12.34") == true); XCTAssertTrue(token?.contains("XOR") == true)
        XCTAssertNotNil(factory.createTokenFormatter(for: nil).value(for: locale).stringFromDecimal(12))
    }
    func testWalletDateFormattingUsesEachRequestedLocaleAndTimeZone() {
        let date = Date(timeIntervalSince1970: 0)
        let status = DateFormatter.statusDateFormatter; status.locale = Locale(identifier: "en_US_POSIX"); status.timeZone = TimeZone(secondsFromGMT: 0)
        XCTAssertEqual(status.string(from: date), "01 Jan 1970, 00:00:00")
        for resource in [DateFormatter.friends, DateFormatter.history, DateFormatter.transactionDetails] {
            for identifier in ["en_US", "de_DE", "ja_JP"] {
                let formatter = resource.value(for: Locale(identifier: identifier)); formatter.timeZone = TimeZone(secondsFromGMT: 0)
                XCTAssertEqual(formatter.locale.identifier, identifier); XCTAssertFalse(formatter.string(from: date).isEmpty)
                XCTAssertNotNil(formatter.date(from: formatter.string(from: date)))
            }
        }
    }
    func testInputFieldPreservesThePreviousValueWhenAnEditViolatesItsBudget() {
        let model = InputFieldViewModel(title: "Name", hint: "Wallet name", cancelActionTitle: "Cancel", doneActionTitle: "Done")
        model.maximumLength = 4
        XCTAssertTrue(model.didReceive(replacement: "Test", in: NSRange(location: 0, length: 0)))
        XCTAssertFalse(model.didReceive(replacement: "!", in: NSRange(location: 4, length: 0))); XCTAssertEqual(model.value, "Test")
        XCTAssertTrue(model.didReceive(replacement: "", in: NSRange(location: 3, length: 1))); XCTAssertEqual(model.value, "Tes")
        XCTAssertEqual(model.title, "Name"); XCTAssertEqual(model.hint, "Wallet name")
    }
    func testInputFieldAppliesCharacterPolicyAndCompletionSeparately() {
        let model = InputFieldViewModel(title: "", hint: "", cancelActionTitle: "Cancel", doneActionTitle: "Done")
        XCTAssertTrue(model.isComplete)
        model.invalidCharacters = .decimalDigits; model.completionPredicate = NSPredicate { value, _ in (value as? String)?.count == 3 }
        XCTAssertFalse(model.isComplete)
        XCTAssertFalse(model.didReceive(replacement: "a1", in: NSRange(location: 0, length: 0))); XCTAssertEqual(model.value, "")
        XCTAssertTrue(model.didReceive(replacement: "abc", in: NSRange(location: 0, length: 0))); XCTAssertTrue(model.isComplete)
        XCTAssertTrue(model.didReceive(replacement: "d", in: NSRange(location: 0, length: 3))); XCTAssertFalse(model.isComplete)
    }
    func testInputFieldUsesUTF16ReplacementRangesWithoutSplittingEmoji() {
        let model = InputFieldViewModel(title: "", hint: "", cancelActionTitle: "", doneActionTitle: "")
        XCTAssertTrue(model.didReceive(replacement: "🦊a", in: NSRange(location: 0, length: 0)))
        XCTAssertTrue(model.didReceive(replacement: "b", in: NSRange(location: 2, length: 1))); XCTAssertEqual(model.value, "🦊b")
    }
    func testDisplayNamesKeepTheLastComponentAndAddressAbbreviationIsBounded() {
        XCTAssertEqual("Ada Lovelace".firstName, "Ada"); XCTAssertEqual("Ada Lovelace".lastName, "Lovelace")
        XCTAssertEqual("Mary Jane Watson".firstName, "Mary Jane"); XCTAssertEqual("Mary Jane Watson".lastName, "Watson")
        XCTAssertEqual("SORA".firstName, "SORA"); XCTAssertNil("SORA".lastName)
        XCTAssertEqual("1234567890".soraConcat, "1234567890"); XCTAssertEqual("12345678901".soraConcat, "12345…78901")
        XCTAssertEqual("🦊🦊🦊🦊🦊🦊🦊🦊🦊🦊🦊".soraConcat, "🦊🦊🦊🦊🦊…🦊🦊🦊🦊🦊")
    }
    func testManagedMetadataEditsPreserveWalletIdentityAndSelection() {
        let original = ManagedAccountItem(address: "fixture", cryptoType: .sr25519, networkType: Chain.sora.addressType(), username: "Before", publicKeyData: Data([1, 2, 3]), order: 5, settings: AccountSettings(visibleAssetIds: ["XOR"], orderedAssetIds: ["XOR"]), isSelected: true)
        let renamed = original.replacingUsername("After"), reordered = original.replacingOrder(8)
        let settings = AccountSettings(visibleAssetIds: [], orderedAssetIds: [])
        let changed = original.replacingSettings(settings)
        for value in [renamed, reordered, changed] { XCTAssertEqual(value.address, original.address); XCTAssertEqual(value.publicKeyData, original.publicKeyData); XCTAssertEqual(value.cryptoType, original.cryptoType); XCTAssertEqual(value.networkType, original.networkType); XCTAssertTrue(value.isSelected) }
        XCTAssertEqual(renamed.username, "After"); XCTAssertEqual(renamed.order, 5); XCTAssertEqual(renamed.settings, original.settings)
        XCTAssertEqual(reordered.order, 8); XCTAssertEqual(reordered.username, "Before")
        XCTAssertEqual(changed.settings, settings); XCTAssertEqual(changed.username, "Before"); XCTAssertEqual(changed.order, 5)
    }
    func testEmptySourceRefreshAndHistoryCompleteSynchronouslyWithoutAQueue() throws {
        let source = SoraPassport.EmptyStreamableSource<ChainStorageItem>(); var values: [Int] = []
        source.refresh(runningIn: nil) { result in values.append((try? result?.get()) ?? -1) }
        source.fetchHistory(runningIn: nil) { result in values.append((try? result?.get()) ?? -1) }
        XCTAssertEqual(values, [0, 0]); source.refresh(runningIn: nil, commitNotificationBlock: nil); source.fetchHistory(runningIn: nil, commitNotificationBlock: nil)
    }
    func testEmptySourceDeliversBothCallbacksOnTheRequestedQueue() {
        let queue = DispatchQueue(label: "sora.fixture.empty-source"), key = DispatchSpecificKey<String>(); queue.setSpecific(key: key, value: "fixture")
        let source = SoraPassport.EmptyStreamableSource<ChainStorageItem>(), done = expectation(description: "callbacks"); done.expectedFulfillmentCount = 2
        let completion: (Result<Int, Error>?) -> Void = { result in XCTAssertEqual(DispatchQueue.getSpecific(key: key), "fixture"); XCTAssertEqual(try? result?.get(), 0); done.fulfill() }
        source.refresh(runningIn: queue, commitNotificationBlock: completion); source.fetchHistory(runningIn: queue, commitNotificationBlock: completion)
        wait(for: [done], timeout: 2)
    }
}

@MainActor
final class LegacyPersistenceBoundaryTests: XCTestCase {
    private func context(_ modelName: String) throws -> NSManagedObjectContext {
        let url = try XCTUnwrap(Bundle.main.url(forResource: modelName, withExtension: "momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: url))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType); context.persistentStoreCoordinator = coordinator
        return context
    }
    private func history(block: UInt64? = 42, index: UInt16? = 7, receiver: String? = "receiver") -> TransactionHistoryItem {
        TransactionHistoryItem(sender: "sender", receiver: receiver, status: .success, txHash: "transaction", timestamp: 1234567890123, fee: "123456789012345678901", blockNumber: block, txIndex: index, callPath: CallCodingPath(moduleName: "Assets", callName: "transfer"), call: Data([1,0,255]))
    }
    func testTransactionStorageRoundTripRetainsEveryReceiptField() throws {
        let c = try context("SubstrateDataModel"), entity = CDTransactionHistoryItem(context: c), expected = history()
        let mapper = CodableCoreDataMapper<TransactionHistoryItem, CDTransactionHistoryItem>()
        try mapper.populate(entity: entity, from: expected, using: c)
        let result = try mapper.transform(entity: entity)
        XCTAssertEqual(result.txHash, expected.txHash); XCTAssertEqual(result.sender, expected.sender); XCTAssertEqual(result.receiver, expected.receiver)
        XCTAssertEqual(result.status, .success); XCTAssertEqual(result.timestamp, expected.timestamp); XCTAssertEqual(result.fee, expected.fee)
        XCTAssertEqual(result.blockNumber, 42); XCTAssertEqual(result.txIndex, 7); XCTAssertEqual(result.call, expected.call)
        XCTAssertEqual(result.callPath.moduleName, "Assets"); XCTAssertEqual(result.callPath.callName, "transfer")
    }
    func testReplacingPendingTransactionClearsStaleOptionalReceiptFields() throws {
        let c = try context("SubstrateDataModel"), entity = CDTransactionHistoryItem(context: c)
        let mapper = CodableCoreDataMapper<TransactionHistoryItem, CDTransactionHistoryItem>()
        try mapper.populate(entity: entity, from: history(), using: c)
        try mapper.populate(entity: entity, from: history(block: nil, index: nil, receiver: nil), using: c)
        let result = try mapper.transform(entity: entity)
        XCTAssertNil(entity.blockNumber); XCTAssertNil(entity.txIndex); XCTAssertNil(entity.receiver)
        XCTAssertNil(result.blockNumber); XCTAssertNil(result.txIndex); XCTAssertNil(result.receiver)
    }
    func testTransactionStoragePreservesTheFullUnsignedBlockHeight() throws {
        let c = try context("SubstrateDataModel"), entity = CDTransactionHistoryItem(context: c)
        let mapper = CodableCoreDataMapper<TransactionHistoryItem, CDTransactionHistoryItem>()
        try mapper.populate(entity: entity, from: history(block: UInt64.max, index: UInt16(Int16.max)), using: c)
        let result = try mapper.transform(entity: entity)
        XCTAssertEqual(result.blockNumber, UInt64.max); XCTAssertEqual(result.txIndex, UInt16(Int16.max))
    }
    func testTransactionStorageRejectsAnIndexOutsideItsStoredSignedRange() throws {
        let c = try context("SubstrateDataModel"), entity = CDTransactionHistoryItem(context: c)
        XCTAssertThrowsError(try CodableCoreDataMapper<TransactionHistoryItem, CDTransactionHistoryItem>().populate(entity: entity, from: history(index: UInt16.max), using: c))
    }
    func testIncompleteStoredCallCannotDecodeIntoAnInventedTransaction() throws {
        let c = try context("SubstrateDataModel"), entity = CDTransactionHistoryItem(context: c)
        let mapper = CodableCoreDataMapper<TransactionHistoryItem, CDTransactionHistoryItem>()
        try mapper.populate(entity: entity, from: history(), using: c); entity.callName = nil
        XCTAssertThrowsError(try mapper.transform(entity: entity))
    }
    private func account(_ byte: UInt8, name: String = "wallet") throws -> AccountItem {
        let key = Data(repeating: byte, count: 32)
        return AccountItem(address: try SS58AddressFactory().addressFromAccountId(data: key, type: 69), cryptoType: .sr25519, networkType: 69, username: name, publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: false)
    }
    func testLegacyAccountInsertionAppendsAfterTheHighestPositiveOrder() throws {
        let c = try context("UserDataModel"), mapper = CodableCoreDataMapper<AccountItem, CDAccountItem>()
        let first = CDAccountItem(context: c); try mapper.populate(entity: first, from: account(3), using: c)
        XCTAssertEqual(first.order, 1)
        first.order = 9
        let ignored = CDAccountItem(context: c); ignored.identifier = "not-ordered"; ignored.order = -1
        let second = CDAccountItem(context: c); try mapper.populate(entity: second, from: account(4), using: c)
        XCTAssertEqual(second.order, 10); XCTAssertEqual(second.networkType, 69)
    }
    func testLegacyAccountRenamePreservesItsExistingOrderAndIdentity() throws {
        let c = try context("UserDataModel"), mapper = CodableCoreDataMapper<AccountItem, CDAccountItem>(), entity = CDAccountItem(context: c)
        let initial = try account(3); try mapper.populate(entity: entity, from: initial, using: c); entity.order = 17
        try mapper.populate(entity: entity, from: account(3, name: "Renamed wallet"), using: c)
        XCTAssertEqual(entity.order, 17); XCTAssertEqual(entity.identifier, initial.address); XCTAssertEqual(entity.publicKey, initial.publicKeyData)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(entity)) as! [String: Any]
        XCTAssertEqual(encoded["address"] as? String, initial.address); XCTAssertEqual(encoded["username"] as? String, "Renamed wallet")
        XCTAssertEqual(encoded["publicKeyData"] as? String, initial.publicKeyData.base64EncodedString()); XCTAssertEqual(encoded["cryptoType"] as? Int, 0)
    }
    func testReferendumRoundTripPreservesDomainVotesAndEveryStatus() throws {
        let c = try context("Entities"), mapper = ReferendumDataMapper(domain: "governance-test")
        XCTAssertEqual(mapper.entityIdentifierFieldName, "identifier")
        for status in [ReferendumDataStatus.open, .accepted, .rejected] {
            let expected = ReferendumData(identifier: "proposal", name: "A proposal", shortDescription: "Brief", detailedDescription: "Full proposal", fundingDeadline: 1234, statusUpdateTime: 5678, imageLink: URL(string: "https://fixture.invalid/image.png"), status: status, supportVotes: "12345678901234567890", opposeVotes: "1", userSupportVotes: "2", userOpposeVotes: "0")
            let entity = CDReferendum(context: c); try mapper.populate(entity: entity, from: expected, using: c)
            XCTAssertEqual(try mapper.transform(entity: entity), expected); XCTAssertEqual(entity.domain, "governance-test")
        }
    }
    func testReferendumWithoutAnImageDoesNotInventALink() throws {
        let c = try context("Entities"), entity = CDReferendum(context: c), mapper = ReferendumDataMapper(domain: "test")
        let expected = ReferendumData(identifier: "proposal", name: "Name", shortDescription: "Short", detailedDescription: "Long", fundingDeadline: 1, statusUpdateTime: 2, imageLink: nil, status: .open, supportVotes: "0", opposeVotes: "0", userSupportVotes: "0", userOpposeVotes: "0")
        try mapper.populate(entity: entity, from: expected, using: c)
        XCTAssertNil(entity.imageLink); XCTAssertEqual(try mapper.transform(entity: entity), expected)
    }
}

final class QRImageExtractionBoundaryTests: XCTestCase {
    private func qr(_ text: String) throws -> UIImage {
        let filter = try XCTUnwrap(CIFilter(name: "CIQRCodeGenerator"))
        filter.setValue(Data(text.utf8), forKey: "inputMessage"); filter.setValue("M", forKey: "inputCorrectionLevel")
        let raw = try XCTUnwrap(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let image = try XCTUnwrap(CIContext().createCGImage(raw, from: raw.extent))
        return UIImage(cgImage: image)
    }
    private func extract(_ image: UIImage, matching: String, delivery: DispatchQueue? = nil) async throws -> Result<String, Error> {
        let completed = expectation(description: "image extraction")
        let matcher = QRImageMatcher(expected: matching), service = WalletQRExtractionService(processingQueue: DispatchQueue(label: "qr-extraction-test"))
        var result: Result<String, Error>?
        service.extract(from: image, using: matcher, dispatchCompletionIn: delivery) { result = $0; completed.fulfill() }
        await fulfillment(of: [completed], timeout: 4)
        return try XCTUnwrap(result)
    }
    func testGeneratedQRImageRoundTripsTheExactPayload() async throws {
        let text = "substrate:public-account:69?amount=1.000000000000000001"
        let result = try await extract(qr(text), matching: text)
        XCTAssertEqual(try result.get(), text)
    }
    func testDecodedImageMustPassTheWalletMatcher() async throws {
        let result = try await extract(qr("untrusted-payload"), matching: "expected-wallet")
        guard case let .failure(error) = result, case WalletQRExtractionServiceError.noFeatures = error else { return XCTFail("Unmatched payload was accepted") }
    }
    func testEmptyImageReportsInvalidImage() async throws {
        let result = try await extract(UIImage(), matching: "wallet")
        guard case let .failure(error) = result, case WalletQRExtractionServiceError.invalidImage = error else { return XCTFail("Empty image was accepted") }
    }
    func testImageWithoutQRReportsNoFeatures() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: format).image { context in UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 100, height: 100)) }
        let result = try await extract(image, matching: "wallet")
        guard case let .failure(error) = result, case WalletQRExtractionServiceError.noFeatures = error else { return XCTFail("Blank image produced a wallet") }
    }
    func testExplicitDeliveryQueueOwnsTheCompletion() async throws {
        let queue = DispatchQueue(label: "qr-delivery-test"), key = DispatchSpecificKey<String>(); queue.setSpecific(key: key, value: "delivery")
        let service = WalletQRExtractionService(processingQueue: DispatchQueue(label: "qr-processing-test")), done = expectation(description: "delivered")
        let matcher = QRImageMatcher(expected: "wallet"), image = try qr("wallet")
        service.extract(from: image, using: matcher, dispatchCompletionIn: queue) { result in
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), "delivery"); XCTAssertEqual(try? result.get(), "wallet"); done.fulfill()
        }
        await fulfillment(of: [done], timeout: 4)
    }
}
private final class QRImageMatcher: WalletQRMatcherProtocol {
    let expected: String
    init(expected: String) { self.expected = expected }
    func match(code: String) -> Bool { code == expected }
}

final class SwapMarketSourceBoundaryTests: XCTestCase {
    private func source() -> SwapMarketSourcer { SwapMarketSourcer(fromAssetId: WalletAssetId.xor.rawValue, toAssetId: WalletAssetId.val.rawValue) }
    func testUnloadedSourcesAreDistinctFromAnEmptyServerResponse() {
        let value = source(); XCTAssertFalse(value.isLoaded()); XCTAssertTrue(value.isEmpty())
        XCTAssertTrue(value.getMarketSources().isEmpty); XCTAssertTrue(value.getServerMarketSources().isEmpty)
        XCTAssertNil(value.getMarketSource(at: 0)); XCTAssertNil(value.index(of: .xyk)); XCTAssertFalse(value.contains(.smart))
        value.didLoad([]); XCTAssertTrue(value.isLoaded()); XCTAssertFalse(value.isEmpty()); XCTAssertEqual(value.getMarketSources(), [.smart])
        XCTAssertTrue(value.getServerMarketSources().isEmpty)
    }
    func testRecognizedServerSourcesKeepTheirOrderAndAppendSmartOnce() {
        let value = source(); value.didLoad([LiquiditySourceType.xyk.rawValue, LiquiditySourceType.tbc.rawValue])
        XCTAssertEqual(value.getMarketSources(), [.xyk, .tbc, .smart]); XCTAssertEqual(value.getServerMarketSources(), [LiquiditySourceType.xyk.rawValue, LiquiditySourceType.tbc.rawValue])
        XCTAssertEqual(value.index(of: .tbc), 1); XCTAssertTrue(value.contains(.xyk)); XCTAssertEqual(value.getMarketSource(at: 2), .smart)
        value.addSmartIfNotEmpty(); XCTAssertEqual(value.getMarketSources(), [.xyk, .tbc, .smart])
    }
    func testUnknownServerSourcesCannotBecomeASelectableMarket() {
        let value = source(); value.didLoad(["unknown", "XYKPool_typo"])
        XCTAssertEqual(value.getMarketSources(), [.smart]); XCTAssertTrue(value.getServerMarketSources().isEmpty)
    }
    func testReloadReplacesPreviousServerMarkets() {
        let value = source(); value.didLoad([LiquiditySourceType.xyk.rawValue]); value.didLoad([LiquiditySourceType.tbc.rawValue])
        XCTAssertEqual(value.getMarketSources(), [.tbc, .smart]); XCTAssertFalse(value.contains(.xyk))
    }
    func testSmartServerEntryIsNotDuplicatedOrSentAsASourceFilter() {
        let value = source(); value.didLoad([LiquiditySourceType.smart.rawValue, LiquiditySourceType.xyk.rawValue])
        XCTAssertEqual(value.getMarketSources(), [.smart, .xyk]); XCTAssertEqual(value.getServerMarketSources(), [LiquiditySourceType.xyk.rawValue])
        XCTAssertFalse(value.shouldSendToServer(.smart)); XCTAssertTrue(value.shouldSendToServer(.xyk))
    }
    func testSourceLookupRejectsNegativeAndOutOfRangeIndices() {
        let value = source(); value.didLoad([LiquiditySourceType.xyk.rawValue])
        for index in [Int.min, -1, 2, Int.max] { XCTAssertNil(value.getMarketSource(at: index)) }
        XCTAssertEqual(value.getMarketSource(at: 0), .xyk)
    }
    func testExplicitSourcesAndSyntheticAssetRecognitionPreserveTheirMeaning() {
        let value = source(); value.setMarketSources([.xyk]); value.add(.tbc)
        XCTAssertEqual(value.getMarketSources(), [.xyk, .tbc]); XCTAssertTrue(value.isXSTUSD(WalletAssetId.xstusd.rawValue))
        XCTAssertFalse(value.isXSTUSD(WalletAssetId.xor.rawValue)); value.setMarketSources([]); XCTAssertTrue(value.isEmpty())
        value.forceAddSmartMarketSourceIfNecessary(); XCTAssertEqual(value.getMarketSources(), [.smart])
    }
    func testAddingSmartBeforeServerLoadingDoesNotPretendSourcesHaveLoaded() {
        let value = source(); value.addSmartIfNotEmpty(); value.add(.xyk)
        XCTAssertFalse(value.isLoaded()); XCTAssertTrue(value.isEmpty())
    }
}

final class StartupDiagnosticBoundaryTests: XCTestCase {
    private func diagnostic(_ error: Error) throws -> WalletStartupDiagnostic {
        let settings = InMemorySettingsManager(); settings.setWalletMigrationRecovery(reason: "diagnostic fixture")
        WalletStartupDiagnostic.record(error, phase: .networkSnapshot, settings: settings)
        return try XCTUnwrap(WalletStartupDiagnostic.current(settings))
    }
    func testKeychainFailuresKeepTheirDistinctSafeDiagnosticCodes() throws {
        let values: [(KeystoreError, WalletStartupDiagnostic.Cause)] = [(.invalidIdentifierFormat, .keychainIdentifier), (.noKeyFound, .keychainMissing), (.duplicatedItem, .keychainDuplicate), (.unexpectedFail, .keychainResult)]
        for (error, cause) in values {
            let d = try diagnostic(error); XCTAssertEqual(d.cause, cause); XCTAssertNil(d.systemCode)
            XCTAssertEqual(d.phase, .networkSnapshot); XCTAssertNotNil(d.recordedAt)
        }
    }
    func testAmbiguousAccountInventoryIsNotMisclassifiedAsMissingKeys() throws {
        let values: [(SelectedWalletSettingsError, WalletStartupDiagnostic.Cause)] = [(.duplicateAccountIdentifiers, .duplicateAccounts), (.multipleSelectedAccounts, .multipleSelections), (.missingSelectedAccount, .missingSelection)]
        for (error, cause) in values { XCTAssertEqual(try diagnostic(error).cause, cause) }
    }
    func testInvalidDerivationAndRemovalFailuresRetainOnlyFixedCodes() throws {
        let values: [(WalletNetworkMigrationError, WalletStartupDiagnostic.Cause)] = [(.invalidDerivationPath, .invalidDerivation), (.nonHardenedDerivationComponent, .invalidDerivation), (.invalidDerivationIndex, .invalidDerivation), (.explicitRemovalTargetMissing("private-address-fixture"), .removalMismatch), (.explicitRemovalInventoryMismatch, .removalMismatch), (.explicitRemovalSelectionMismatch, .removalMismatch), (.legacyIdentityMismatch("private-address-fixture"), .legacyIdentityMismatch)]
        for (error, cause) in values {
            let d = try diagnostic(error); XCTAssertEqual(d.cause, cause)
            XCTAssertFalse(d.summary.contains("private-address-fixture"))
            XCTAssertFalse(String(decoding: try JSONEncoder().encode(d), as: UTF8.self).contains("private-address-fixture"))
        }
    }
    func testEmptySigningMaterialIsExplainedWithoutClaimingTheWalletWasDeleted() throws {
        let d = try diagnostic(UserStorageMigrationError.emptyWalletSecret("private-tag-fixture"))
        XCTAssertEqual(d.userMessage, WalletUX.text("A matching wallet key record was found, but it was empty. Existing account data and other keys have been preserved."))
        XCTAssertFalse(d.summary.contains("private-tag-fixture"))
    }
    func testKeychainEntitlementFailureIsDistinguishedFromAMissingSecret() throws {
        let d = try diagnostic(KeystoreSystemError(status: -34018))
        XCTAssertEqual(d.cause, .keychainSystem); XCTAssertEqual(d.systemCode, -34018)
        XCTAssertEqual(d.userMessage, WalletUX.text("iOS rejected this app’s Keychain access. The error details include the system status; no wallet data was replaced."))
    }
    func testUnknownKeychainSystemFailureDoesNotClaimAKeyWasMissing() throws {
        let d = try diagnostic(KeystoreSystemError(status: -50))
        XCTAssertEqual(d.systemCode, -50)
        XCTAssertEqual(d.userMessage, WalletUX.text("iOS returned an error while SORA was checking a wallet key. No missing-key conclusion was made for that failed operation."))
    }
    func testUnavailableStoreAndModelUseTheDatabaseRecoveryMessage() throws {
        let values: [UserStorageMigrationError] = [.missingWalletStore, .unknownStoreVersion, .unavailableModel("private-model-fixture")]
        for e in values {
            let d = try diagnostic(e)
            XCTAssertEqual(d.userMessage, WalletUX.text("SORA could not verify the saved wallet database. Existing files and recovery copies have been preserved."))
            XCTAssertFalse(d.summary.contains("private-model-fixture"))
        }
    }
    func testRecoveryExportErrorsDescribeWhatWasPreservedAndWhetherAnythingWasPublished() {
        let values: [(WalletRecoveryExportError, String)] = [
            (.unavailableStore, "The preserved wallet database is unavailable."),
            (.unsafeSource("wallet.sqlite"), "The preserved wallet file wallet.sqlite could not be verified."),
            (.sourceChanged("wallet.sqlite"), "The preserved wallet file wallet.sqlite changed while it was being exported. Nothing was published."),
            (.invalidSettings, "The protected wallet settings could not be safely exported."),
            (.exportTooLarge, "The preserved wallet data exceeds the bounded recovery export size."),
            (.publicationFailed, "The protected recovery package could not be published."),
            (.publicationWithdrawalFailed, "The recovery package could not be safely withdrawn after publication verification failed.")]
        for (error, text) in values { XCTAssertEqual(error.localizedDescription, text) }
    }
    func testAccountSelectionErrorsDescribeTheBrokenInventoryInvariant() {
        let values: [(SelectedWalletSettingsError, String)] = [
            (.duplicateAccountIdentifiers, "The wallet database contains duplicate account identifiers."),
            (.multipleSelectedAccounts, "The wallet database contains more than one selected account."),
            (.missingSelectedAccount, "Existing wallet accounts were found, but no verified selected account is available.")]
        for (error, text) in values { XCTAssertEqual(error.localizedDescription, text) }
    }
}

@MainActor
final class AppEventLifecycleBoundaryTests: XCTestCase {
    private var services = [AppEventService]()
    private var priorWindow: UIWindow?
    override func setUp() {
        super.setUp(); priorWindow = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
    }
    override func tearDown() async throws {
        for service in services {
            await withCheckedContinuation { continuation in service.stop { continuation.resume() } }
        }
        services = []; priorWindow?.makeKeyAndVisible(); priorWindow = nil
        try await super.tearDown()
    }
    private func subject(_ mode: AppEventService.HideMode = .never) -> AppEventService {
        let s = AppEventService(hideMode: mode); services.append(s); return s
    }
    private func waitFor(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 { if condition() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTFail("Toast lifecycle did not settle", file: file, line: line)
    }
    func testShowingAToastAttachesItToAPassthroughWindow() async {
        let s = subject(), view = BoundaryToastController(); s.showToasterIfNeeded(viewController: view)
        await waitFor { view.shows == 1 }; XCTAssertTrue(view.view.window is SilentWindow)
        XCTAssertFalse(view.view.window?.point(inside: .zero, with: nil) ?? true)
    }
    func testRepeatedShowDoesNotCreateADuplicateVisibleToast() async {
        let s = subject(), a = BoundaryToastController(), b = BoundaryToastController()
        s.showToasterIfNeeded(viewController: a); await waitFor { a.shows == 1 }
        s.showToasterIfNeeded(viewController: b); try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(a.shows, 1); XCTAssertEqual(b.shows, 0); XCTAssertNil(b.viewIfLoaded?.window)
    }
    func testImmediateHideCompletionReleasesTheToastWindowBeforeReportingCompletion() async {
        let s = subject(), view = BoundaryToastController(); s.showToasterIfNeeded(viewController: view)
        await waitFor { view.shows == 1 }; var flag: Bool?
        s.hideToasterIfNeeded(with: false) { flag = $0; XCTAssertNil(view.view.window) }
        await waitFor { flag != nil }; XCTAssertEqual(flag, false); XCTAssertEqual(view.hides, 1)
    }
    func testHideBeforeAnyShowStillCallsItsCompletion() async {
        let s = subject(); var completed = false
        s.hideToasterIfNeeded { value in XCTAssertTrue(value); completed = true }
        await waitFor { completed }
    }
    func testStopReportsCompletionAndPreventsSubsequentShowUntilRestarted() async {
        let s = subject(), view = BoundaryToastController(); s.showToasterIfNeeded(viewController: view)
        await waitFor { view.shows == 1 }; var stopped = false
        s.stop { stopped = true }; await waitFor { stopped }
        s.showToasterIfNeeded(viewController: view); try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(view.shows, 1); XCTAssertNil(view.view.window)
        s.start(); await waitFor { view.shows == 2 }
    }
    func testStopCancelsAQueuedFirstShow() async {
        let s = subject(), view = BoundaryToastController(); s.showToasterIfNeeded(viewController: view)
        var stopped = false; s.stop { stopped = true }; await waitFor { stopped }
        XCTAssertEqual(view.shows, 0); XCTAssertNil(view.viewIfLoaded?.window)
    }
    func testConfiguredAutomaticHideDelayIsHonored() async {
        let s = subject(.after(delay: 0.05)), view = BoundaryToastController()
        s.showToasterIfNeeded(viewController: view); await waitFor { view.hides == 1 }
        XCTAssertEqual(view.shows, 1); XCTAssertNil(view.view.window)
    }
    func testExplicitPersistentShowDisablesAutomaticHide() async {
        let s = subject(.after(delay: 0.01)), view = BoundaryToastController()
        s.showToasterIfNeeded(viewController: view, isNeedHide: false); await waitFor { view.shows == 1 }
        try? await Task.sleep(nanoseconds: 400_000_000); XCTAssertEqual(view.hides, 0)
    }
    func testForcedUpdateHidesThePreviousToastAndShowsTheReplacement() async {
        let s = subject(), a = BoundaryToastController(), b = BoundaryToastController()
        s.showToasterIfNeeded(viewController: a); await waitFor { a.shows == 1 }
        s.showToasterIfNeeded(viewController: b, isNeedHide: false, isNeedForceUpdate: true)
        await waitFor { b.shows == 1 }; XCTAssertEqual(a.hides, 1); XCTAssertNil(a.view.window)
        XCTAssertNotNil(b.view.window)
    }
    func testForcedFirstShowWorksWithoutAnExistingToast() async {
        let s = subject(), view = BoundaryToastController()
        s.showToasterIfNeeded(viewController: view, isNeedForceUpdate: true)
        await waitFor { view.shows == 1 }; XCTAssertEqual(view.hides, 0)
    }
    func testStartWithoutAnyPreviousToastDoesNotCreateAWindow() {
        let s = subject(); s.start()
        XCTAssertTrue(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).allSatisfy { !($0.rootViewController is BoundaryToastController) })
    }
    func testSilentWindowAcceptsOnlyTouchesInsideItsExplicitTappableView() {
        let view = BoundaryToastController(); view.target = UIView(frame: CGRect(x: 20, y: 30, width: 60, height: 70))
        view.view.addSubview(view.target!); let window = SilentWindow(root: view)
        defer { window.isHidden = true; window.rootViewController = nil }
        window.frame = CGRect(x: 0, y: 0, width: 300, height: 400); view.view.frame = window.bounds
        XCTAssertTrue(window.point(inside: CGPoint(x: 30, y: 40), with: nil))
        XCTAssertFalse(window.point(inside: CGPoint(x: 10, y: 10), with: nil))
    }
}
private final class BoundaryToastController: UIViewController, AppEventDisplayLogic {
    var shows = 0, hides = 0; var target: UIView?
    var deferredHide = false, finishHide: (() -> Void)?
    var tappableView: UIView? { target }
    func show() { shows += 1 }
    func hide(completion: @escaping () -> Void) { hides += 1; if deferredHide { finishHide = completion } else { completion() } }
}


extension AppEventLifecycleBoundaryTests {
    func testAnOlderHideAnimationCannotRemoveANewerToastWindow() async {
        let s = subject(), old = BoundaryToastController(), current = BoundaryToastController()
        old.deferredHide = true; s.showToasterIfNeeded(viewController: old)
        await waitFor { old.shows == 1 }; s.hideToasterIfNeeded()
        await waitFor { old.hides == 1 }; s.showToasterIfNeeded(viewController: current)
        await waitFor { current.shows == 1 }; old.finishHide?(); old.finishHide = nil
        XCTAssertNotNil(current.view.window); XCTAssertNil(old.view.window)
    }
}

@MainActor
final class AttributedWalletFormattingTests: XCTestCase {
    func testDecimalCurrencyKeepsItsExactTextAndShrinksOnlyFractionDigits() throws {
        let text = "1234.000000001", font = UIFont.systemFont(ofSize: 20)
        let result = text.prettyCurrency(baseFont: font, smallSize: 11, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(result.string, text)
        XCTAssertEqual((result.attribute(.font, at: 4, effectiveRange: nil) as? UIFont)?.pointSize, 20)
        XCTAssertEqual((result.attribute(.font, at: 5, effectiveRange: nil) as? UIFont)?.pointSize, 11)
        XCTAssertEqual((result.attribute(.font, at: result.length - 1, effectiveRange: nil) as? UIFont)?.pointSize, 11)
        let paragraph = try XCTUnwrap(result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(paragraph.alignment, .right); XCTAssertEqual(paragraph.lineBreakMode, .byCharWrapping)
    }
    func testCommaDecimalLocaleKeepsGroupingAtTheOriginalFontSize() {
        let result = "1.234,56".prettyCurrency(baseFont: .systemFont(ofSize: 20), smallSize: 10, locale: Locale(identifier: "de_DE"))
        XCTAssertEqual((result.attribute(.font, at: 1, effectiveRange: nil) as? UIFont)?.pointSize, 20)
        XCTAssertEqual((result.attribute(.font, at: 6, effectiveRange: nil) as? UIFont)?.pointSize, 10)
        XCTAssertEqual(result.string, "1.234,56")
    }
    func testIntegerCurrencyDoesNotInventADecimalPart() {
        let result = "12".prettyCurrency(baseFont: .systemFont(ofSize: 19), locale: Locale(identifier: "en_US"))
        XCTAssertEqual(result.string, "12")
        for index in 0..<result.length { XCTAssertEqual((result.attribute(.font, at: index, effectiveRange: nil) as? UIFont)?.pointSize, 19) }
    }
    func testEmptyCurrencyFormattingIsSafeAndRemainsEmpty() {
        let result = "".prettyCurrency(baseFont: .systemFont(ofSize: 19), locale: Locale(identifier: "ja_JP"))
        XCTAssertEqual(result.length, 0)
    }
    func testCurrencyWithTrailingSeparatorPreservesTheDraftText() {
        let result = "1.".prettyCurrency(baseFont: .systemFont(ofSize: 20), locale: Locale(identifier: "en_US"))
        XCTAssertEqual(result.string, "1."); XCTAssertEqual((result.attribute(.font, at: 1, effectiveRange: nil) as? UIFont)?.pointSize, 20)
    }
    func testSubstringDecorationUsesUTF16RangesAfterEmoji() {
        let result = "🦊 Wallet".decoratedWith([.foregroundColor: UIColor.black], adding: [.foregroundColor: UIColor.red], to: ["Wallet"])
        XCTAssertEqual(result.string, "🦊 Wallet")
        XCTAssertEqual(result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .black)
        XCTAssertEqual(result.attribute(.foregroundColor, at: 3, effectiveRange: nil) as? UIColor, .red)
    }
    func testMissingSubstringLeavesBaseAttributesIntact() {
        let result = "Wallet".decoratedWith([.kern: 2], adding: [.underlineStyle: 1], to: ["missing"])
        XCTAssertEqual(result.attribute(.kern, at: 0, effectiveRange: nil) as? Int, 2)
        XCTAssertNil(result.attribute(.underlineStyle, at: 0, effectiveRange: nil))
    }
    func testExplicitRangeDecorationKeepsCombinedUnicodeCharactersWhole() {
        let text = "日本🦊語", start = text.index(text.startIndex, offsetBy: 2), end = text.index(start, offsetBy: 1)
        let result = text.decoratedWith([.kern: 1], adding: [.underlineStyle: 1], to: start..<end)
        XCTAssertEqual(result.string, text)
        XCTAssertNil(result.attribute(.underlineStyle, at: 1, effectiveRange: nil))
        XCTAssertEqual(result.attribute(.underlineStyle, at: 2, effectiveRange: nil) as? Int, 1)
        XCTAssertEqual(result.attribute(.underlineStyle, at: 3, effectiveRange: nil) as? Int, 1)
        XCTAssertNil(result.attribute(.underlineStyle, at: 4, effectiveRange: nil))
    }
    func testAlignmentReturnsACopyAndRetainsTextFormatting() {
        let source = NSAttributedString(string: "Wallet", attributes: [.kern: 2, .foregroundColor: UIColor.blue])
        let result = source.aligned(.center)
        XCTAssertEqual(result.string, source.string)
        XCTAssertEqual((result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment, .center)
        XCTAssertEqual(result.attribute(.kern, at: 0, effectiveRange: nil) as? Int, 2)
        XCTAssertEqual(result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .blue)
        XCTAssertNil(source.attribute(.paragraphStyle, at: 0, effectiveRange: nil))
    }
    func testWholeAttributedRangeCoversUTF16TextIncludingEmoji() {
        XCTAssertEqual(NSAttributedString(string: "🦊a").wholeRange, NSRange(location: 0, length: 3))
        XCTAssertEqual(NSAttributedString.space.string, " ")
        XCTAssertEqual(NSAttributedString(string: "").aligned(.right).length, 0)
    }
    func testBundledDesignFontsResolveForEverySupportedWeightWithoutExceedingTheirCaps() throws {
        let styles: [SoraTextStyle] = [.display1, .display2, .title1, .title2, .title3, .title4, .paragraph1, .paragraph2, .paragraph3, .paragraph4, .uppercase1, .uppercase2, .uppercase3, .button]
        for style in styles {
            for bold in [false, true] {
                XCTAssertNotNil(UIFont(name: style.fontName(isBold: bold), size: style.fontSize.base))
                let font = try XCTUnwrap(UIFont.styled(for: style, isBold: bold))
                XCTAssertGreaterThan(font.pointSize, 0)
                if let cap = style.fontSize.max { XCTAssertLessThanOrEqual(font.pointSize, cap) }
            }
        }
    }
}

final class WalletEventDispatchBoundaryTests: XCTestCase {
    func testObserverReceivesOrderedEventsOnTheRequestedQueue() {
        let center = WalletEventCenter()
        let destination = DispatchQueue(label: "wallet-event-fixture-destination")
        let key = DispatchSpecificKey<String>()
        destination.setSpecific(key: key, value: "destination")
        let done = expectation(description: "Both events arrived")
        done.expectedFulfillmentCount = 2
        let observer = EventBoundaryObserver {
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), "destination")
            done.fulfill()
        }
        center.add(observer: observer, dispatchIn: destination)
        center.notify(with: AccountUpdateEvent())
        center.notify(with: AccountUpdateEvent())
        wait(for: [done], timeout: 3)
        withExtendedLifetime(observer) {}
    }

    func testObserverWithoutDestinationReceivesEventsOnTheCentersSerialQueue() {
        let queue = DispatchQueue(label: "wallet-event-fixture-sync")
        let key = DispatchSpecificKey<String>()
        queue.setSpecific(key: key, value: "event-center")
        let center = WalletEventCenter(syncQueue: queue)
        var received = 0
        let observer = EventBoundaryObserver { received += 1; XCTAssertEqual(DispatchQueue.getSpecific(key: key), "event-center") }
        center.add(observer: observer)
        center.notify(with: AccountUpdateEvent())
        queue.sync {}
        XCTAssertEqual(received, 1)
    }

    func testDuplicateRegistrationDoesNotDeliverAnEventTwice() {
        let queue = DispatchQueue(label: "wallet-event-fixture-dedup")
        let center = WalletEventCenter(syncQueue: queue)
        var received = 0
        let observer = EventBoundaryObserver { received += 1 }
        center.add(observer: observer); center.add(observer: observer)
        center.notify(with: AccountUpdateEvent())
        queue.sync {}
        XCTAssertEqual(received, 1)
    }

    func testRemovingOneObserverPreservesOtherObservers() {
        let queue = DispatchQueue(label: "wallet-event-fixture-remove")
        let center = WalletEventCenter(syncQueue: queue)
        var removedCount = 0, retainedCount = 0
        let removed = EventBoundaryObserver { removedCount += 1 }
        let retained = EventBoundaryObserver { retainedCount += 1 }
        center.add(observer: removed); center.add(observer: retained)
        center.remove(observer: removed); center.notify(with: AccountUpdateEvent())
        queue.sync {}
        XCTAssertEqual(removedCount, 0); XCTAssertEqual(retainedCount, 1)
    }

    func testRegistrationDoesNotRetainObserversAndExpiredObserversArePruned() {
        let queue = DispatchQueue(label: "wallet-event-fixture-release")
        let center = WalletEventCenter(syncQueue: queue)
        weak var released: EventBoundaryObserver?
        autoreleasepool {
            let observer = EventBoundaryObserver { XCTFail("Released observer must not receive an event") }
            released = observer; center.add(observer: observer); queue.sync {}
        }
        XCTAssertNil(released)
        center.notify(with: AccountUpdateEvent()); queue.sync {}
        var received = 0
        let next = EventBoundaryObserver { received += 1 }
        center.add(observer: next); center.notify(with: AccountUpdateEvent()); queue.sync {}
        XCTAssertEqual(received, 1)
    }

    func testRemovedObserverCanRegisterAgainForLaterEvents() {
        let queue = DispatchQueue(label: "wallet-event-fixture-reregister")
        let center = WalletEventCenter(syncQueue: queue)
        var received = 0
        let observer = EventBoundaryObserver { received += 1 }
        center.add(observer: observer); center.remove(observer: observer)
        center.notify(with: AccountUpdateEvent()); center.add(observer: observer)
        center.notify(with: AccountUpdateEvent()); queue.sync {}
        XCTAssertEqual(received, 1)
    }
}

private final class EventBoundaryObserver: WalletEventVisitorProtocol {
    private let update: () -> Void
    init(_ update: @escaping () -> Void) { self.update = update }
    func processAccountUpdate(event: AccountUpdateEvent) { update() }
}

final class LegacyTransferWireBoundaryTests: XCTestCase {
    func testSoraAddressWireRoundTripPreservesAllThirtyTwoPublicKeyBytes() throws {
        let address = SoraAddress.address32(Data(0..<32))
        let encoded = try JSONEncoder().encode(address)
        XCTAssertEqual(try JSONDecoder().decode(SoraAddress.self, from: encoded), address)
        let container = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String])
        XCTAssertEqual(container, [Data(0..<32).base64EncodedString()])
    }
    func testSoraAddressRejectsTruncatedOrMalformedAddressContainers() {
        for text in ["[]", "{}", "[false]", "[\"not base64!\"]"] {
            XCTAssertThrowsError(try JSONDecoder().decode(SoraAddress.self, from: Data(text.utf8)))
        }
    }
    func testEverySupportedMultiAddressExposesTheExactDestinationBytes() {
        let bytes = Data([0, 1, 15, 255])
        let values: [MultiAddress] = [.accoundId(bytes), .accountTo(bytes), .raw(bytes), .address32(bytes), .address20(bytes), .indexedString(bytes), .rawString(bytes)]
        for value in values { XCTAssertEqual(value.data, bytes) }
        XCTAssertEqual(MultiAddress.accountIndex(BigUInt(0x0102)).data, Data([1, 2]))
        XCTAssertEqual(MultiAddress.accountIndex(.zero).data, Data())
    }
    func testArrayCodableCanonicalizesBytesAndPreservesLeadingZeroes() throws {
        let value = try JSONDecoder().decode(SoraPassport.ArrayCodable.self, from: Data(#"["0","15","16","255"]"#.utf8))
        XCTAssertEqual(value.wrappedValue, "0x000f10ff")
        let encoded = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(SoraPassport.ArrayCodable.self, from: encoded), value)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: encoded) as? [String], ["0", "15", "16", "255"])
    }
    func testArrayCodableRejectsOutOfRangeBytesAndInvalidHexWithoutTruncation() {
        for text in [#"["256"]"#, #"["-1"]"#, #"["not a byte"]"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(SoraPassport.ArrayCodable.self, from: Data(text.utf8)))
        }
        XCTAssertThrowsError(try JSONEncoder().encode(SoraPassport.ArrayCodable(wrappedValue: "0xgg")))
        XCTAssertThrowsError(try JSONEncoder().encode(AssetId(wrappedValue: "0xgg")))
    }
    func testEmptyArrayCodableRoundTripsWithoutInventingAZeroByte() throws {
        let value = try JSONDecoder().decode(SoraPassport.ArrayCodable.self, from: Data("[]".utf8))
        XCTAssertEqual(value.wrappedValue, "0x")
        XCTAssertEqual(try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String], [])
    }
}

final class LegacyAmountDisplayBoundaryTests: XCTestCase {
    private func render(_ value: String, with formatter: NumberFormatter) -> String? {
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSDecimalNumber(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }
    func testVoteAndIntegerCountsNeverRoundFractionalUnitsUp() {
        for formatter in [NumberFormatter.vote, NumberFormatter.anyInteger] {
            XCTAssertEqual(render("12345.999", with: formatter), "12,345")
            XCTAssertEqual(render("0.999", with: formatter), "0")
            XCTAssertEqual(render("-1.01", with: formatter), "-2")
        }
    }
    func testPoolShareDisplayTruncatesAtTwoPlacesAndOmitsZeroFraction() {
        let formatter = NumberFormatter.poolShare
        XCTAssertEqual(render("99.999", with: formatter), "99.99")
        XCTAssertEqual(render("12.5", with: formatter), "12.5")
        XCTAssertEqual(render("0", with: formatter), "0")
    }
    func testRewardCurrencyDisplayNeverOverstatesTheAvailableAmount() {
        let formatter = NumberFormatter.reward
        formatter.currencyCode = "USD"
        XCTAssertEqual(render("12.999", with: formatter), "$12.99")
        XCTAssertEqual(render("0", with: formatter), "$0")
        XCTAssertEqual(render("12.5", with: formatter), "$12.5")
    }
    func testIndependentDisplayFormattersDoNotLeakCustomizationAcrossScreens() {
        let custom = NumberFormatter.poolShare
        custom.maximumFractionDigits = 8
        XCTAssertEqual(render("1.12345678", with: custom), "1.12345678")
        XCTAssertEqual(render("1.12345678", with: .poolShare), "1.12")
    }
}

final class StorageMigrationLifecycleBoundaryTests: XCTestCase {
    func testMissingCredentialInventoryReturnsOnlyAccountsWithoutAnyScopedSource() throws {
        let entropy = Data(repeating: 16, count: 16)
        let account = try retainedEntropyAccount(entropy: entropy)
        for source in ["missing", "entropy", "secret", "seed", "watch-only"] {
            try withRetainedEntropyDatabase(accounts: [account], version: .version2,
                entropy: entropy, recovering: true) { directory, keys, settings in
                switch source {
                case "entropy": try keys.saveEntropy(entropy, address: account.address)
                case "secret": try keys.saveSecretKey(Data(repeating: 1, count: 32), address: account.address)
                case "seed": try keys.saveSeed(Data(repeating: 2, count: 32), address: account.address)
                case "watch-only": settings.set(value: true, for: "wallet.watchOnly.\(account.address)")
                default: break
                }
                let marker = WalletMigrationRecoveryMarker.capture(settings)
                let originalKeys = try retainedEntropyKeyBytes(keys)
                let gate = legacyActivationRecoveryGate(at: directory, settings: settings)
                let coordinator = WalletLifecycleCoordinator(recoveryGate: gate)
                let migrator = missingKeyRecoveryMigrator(directory: directory, keys: keys, settings: settings)
                let rows = try migrator.accountsForMissingKeyRecovery(baseURL: directory, lifecycleCoordinator: coordinator)
                XCTAssertEqual(rows.map(\.address), source == "missing" ? [account.address] : [])
                XCTAssertEqual(try retainedEntropyKeyBytes(keys), originalKeys)
                XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
                XCTAssertThrowsError(try gate.requireMutableWalletAccess())
                let lease = coordinator.tryAcquire()
                XCTAssertNotNil(lease)
                lease?.release()
            }
        }
    }

    func testMissingCredentialInventoryAcceptsRetainedOlderDatabaseSchemasWithoutMigrating() throws {
        let entropy = Data(repeating: 17, count: 16)
        let account = try retainedEntropyAccount(entropy: entropy)
        for version in [UserStorageVersion.version1] {
            try withRetainedEntropyDatabase(accounts: [account], version: version,
                entropy: entropy, recovering: true) { directory, keys, settings in
                let migrator = missingKeyRecoveryMigrator(directory: directory, keys: keys, settings: settings)
                let coordinator = WalletLifecycleCoordinator(recoveryGate:
                    legacyActivationRecoveryGate(at: directory, settings: settings))
                let rows = try migrator.accountsForMissingKeyRecovery(baseURL: directory, lifecycleCoordinator: coordinator)
                XCTAssertEqual(rows.map(\.address), [account.address])
                XCTAssertTrue(migrator.requiresMigration())
                XCTAssertFalse(FileManager.default.fileExists(atPath:
                    directory.appendingPathComponent("WalletMigrationSafety").path))
            }
        }
    }

    func testMissingCredentialInventoryRequiresAnExistingRecoveryMarker() throws {
        let entropy = Data(repeating: 18, count: 16)
        let account = try retainedEntropyAccount(entropy: entropy)
        try withRetainedEntropyDatabase(accounts: [account], version: .version2,
            entropy: entropy, recovering: false) { directory, keys, settings in
            let migrator = missingKeyRecoveryMigrator(directory: directory, keys: keys, settings: settings)
            let coordinator = WalletLifecycleCoordinator(recoveryGate:
                legacyActivationRecoveryGate(at: directory, settings: settings))
            XCTAssertThrowsError(try migrator.accountsForMissingKeyRecovery(baseURL: directory,
                lifecycleCoordinator: coordinator))
            XCTAssertFalse(settings.walletMigrationRecoveryRequired)
            let lease = coordinator.tryAcquire()
            XCTAssertNotNil(lease)
            lease?.release()
        }
    }

    func testAsynchronousStorageMigrationCompletesOnMainWithoutCreatingAnEmptyWallet() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = root.appendingPathComponent("UserDataModel.sqlite")
        let settings = InMemorySettingsManager()
        let migrator = makeUserStorageMigrator(targetVersion: .version2, storeURL: store,
            modelDirectory: UserStorageParams.modelDirectory, keystore: InMemoryKeychain(),
            settings: settings, fileManager: .default)
        let completion = expectation(description: "Migration completion on main")
        migrator.migrate {
            XCTAssertTrue(Thread.isMainThread)
            completion.fulfill()
        }
        await fulfillment(of: [completion], timeout: 10)
        XCTAssertFalse(settings.walletMigrationRecoveryRequired)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.path))
    }

    func testAsynchronousStorageMigrationRetainsUnknownDatabaseAndRecordsPrivacySafeFailure() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = root.appendingPathComponent("UserDataModel.sqlite")
        let original = Data("synthetic unsupported retained database".utf8)
        try original.write(to: store)
        let settings = InMemorySettingsManager()
        let migrator = makeUserStorageMigrator(targetVersion: .version2, storeURL: store,
            modelDirectory: UserStorageParams.modelDirectory, keystore: InMemoryKeychain(),
            settings: settings, fileManager: .default)
        let completion = expectation(description: "Failed migration still completes")
        migrator.migrate {
            XCTAssertTrue(Thread.isMainThread)
            completion.fulfill()
        }
        await fulfillment(of: [completion], timeout: 10)
        XCTAssertTrue(settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try Data(contentsOf: store), original)
        XCTAssertFalse(settings.walletMigrationRecoveryReason?.contains(root.path) ?? true)
    }

    private func makeIsolatedRecoveryGate(
        settings: SettingsManagerProtocol = InMemorySettingsManager()
    ) -> WalletRecoveryCapabilityGate {
        WalletRecoveryCapabilityGate(
            settings: settings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }
        )
    }

    private func makeUserStorageMigrator(
        targetVersion: UserStorageVersion,
        storeURL: URL,
        modelDirectory: String,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        fileManager: FileManager,
        recoveryGate: WalletRecoveryCapabilityGate? = nil,
        availableCapacity: @escaping (URL) -> Int64? = { _ in Int64.max },
        loadWalletNetworkSnapshot:
            @escaping () throws -> WalletNetworkSnapshot? = { nil },
        afterLegacyStoreCopyBeforeVerification:
            ((URL) throws -> Void)? = nil,
        beforeSafetyActivationVerification:
            ((URL) throws -> Void)? = nil
    ) -> UserStorageMigrator {
        UserStorageMigrator(
            targetVersion: targetVersion,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: keystore,
            settings: settings,
            fileManager: fileManager,
            recoveryGate: recoveryGate ??
                makeIsolatedRecoveryGate(settings: settings),
            availableCapacity: availableCapacity,
            loadWalletNetworkSnapshot: loadWalletNetworkSnapshot,
            afterLegacyStoreCopyBeforeVerification:
                afterLegacyStoreCopyBeforeVerification,
            beforeSafetyActivationVerification:
                beforeSafetyActivationVerification
        )
    }

    private func legacyActivationRecoveryGate(
        at directory: URL, settings: InMemorySettingsManager
    ) -> WalletRecoveryCapabilityGate {
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        return WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: storeURL) },
            unresolvedWalletCommitJournal: { try !WalletAccountCommitJournalStore(baseURL: directory).unresolved().isEmpty })
    }

    private func missingKeyRecoveryMigrator(directory: URL, keys: InMemoryKeychain,
        settings: InMemorySettingsManager) -> UserStorageMigrator {
        UserStorageMigrator(targetVersion: .version2, storeURL: directory.appendingPathComponent("UserDataModel.sqlite"),
            modelDirectory: UserStorageParams.modelDirectory, keystore: keys, settings: settings,
            fileManager: .default, recoveryGate: legacyActivationRecoveryGate(at: directory, settings: settings),
            availableCapacity: { _ in Int64.max },
            loadWalletNetworkSnapshot: { try WalletNetworkStore(baseURL: directory,
                recoveryGate: self.makeIsolatedRecoveryGate(settings: settings)).load() })
    }

    private func retainedEntropySeed(_ entropy: Data) throws -> Data {
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy)
        return try SeedFactory().deriveSeed(from: mnemonic.toString(), password: "").seed.miniSeed
    }

    private func retainedEntropyAccount(entropy: Data) throws -> AccountItem {
        let pair = try SR25519KeypairFactory().createKeypairFromSeed(retainedEntropySeed(entropy), chaincodeList: [])
        let publicKey = pair.publicKey().rawData()
        return AccountItem(address: try SS58AddressFactory().address(fromAccountId: publicKey,
            type: Chain.sora.addressType()), cryptoType: .sr25519, networkType: Chain.sora.addressType(),
            username: "Retained global mnemonic", publicKeyData: publicKey,
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 17, isSelected: true)
    }

    private func retainedEntropyKeyBytes(_ keys: InMemoryKeychain) throws -> [String: Data] {
        try Dictionary(uniqueKeysWithValues: keys.allKeyIdentifiers().map { ($0, try keys.fetchKey(for: $0)) })
    }

    private func withRetainedEntropyDatabase(
        accounts: [AccountItem], version: UserStorageVersion, entropy: Data, recovering: Bool,
        body: (URL, InMemoryKeychain, InMemorySettingsManager) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try writeAccounts(accounts, to: directory.appendingPathComponent("UserDataModel.sqlite"),
            model: userStorageModel(named: version.rawValue), includesSelection: version == .version2)
        let keys = InMemoryKeychain()
        try keys.addKey(entropy, with: KeystoreTag.legacyEntropy.rawValue)
        try keys.addKey(Data("Retained account name".utf8), with: KeystoreTag.legacyUsername.rawValue)
        let settings = InMemorySettingsManager()
        settings.set(value: try XCTUnwrap(accounts.first { $0.isSelected }), for: SettingsKey.selectedAccount.rawValue)
        if recovering {
            settings.setWalletMigrationRecovery(reason: UserStorageMigrationError.privacySafeRecoveryDescription(
                for: DurableFileWriter.Failure.fileSystemFailure))
            XCTAssertTrue(WalletMigrationRecoveryMarker.capture(settings).isStartupVerificationFailure)
        }
        try body(directory, keys, settings)
    }

    private func userStorageModel(named name: String) throws -> NSManagedObjectModel {
        let modelURL =
            Bundle.main.url(
                forResource: name,
                withExtension: "omo",
                subdirectory: UserStorageParams.modelDirectory
            ) ??
            Bundle.main.url(
                forResource: name,
                withExtension: "mom",
                subdirectory: UserStorageParams.modelDirectory
            )
        let unwrappedURL = try XCTUnwrap(modelURL)
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: unwrappedURL))
    }

    private func writeAccounts(
        _ accounts: [AccountItem],
        to storeURL: URL,
        model: NSManagedObjectModel,
        includesSelection: Bool
    ) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for account in accounts {
                let stored = NSEntityDescription.insertNewObject(
                    forEntityName: "CDAccountItem",
                    into: context
                )
                stored.setValue(account.address, forKey: "identifier")
                stored.setValue(account.username, forKey: "username")
                stored.setValue(account.publicKeyData, forKey: "publicKey")
                stored.setValue(
                    account.cryptoType.rawValue,
                    forKey: "cryptoType"
                )
                stored.setValue(
                    account.networkType,
                    forKey: "networkType"
                )
                stored.setValue(account.order, forKey: "order")
                if includesSelection {
                    stored.setValue(
                        account.isSelected,
                        forKey: "isSelected"
                    )
                }
            }
            try context.save()
        }
        try coordinator.remove(store)
    }
}
