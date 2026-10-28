// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Foundation
import CoreData
import CoreImage
import UIKit
import IrohaCrypto
import RobinHood
import SoraFoundation
import SSFUtils
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
