import XCTest
@testable import SoraPassport
import IrohaCrypto
import SoraKeystore

class IdentityLocalRemoveOperationTests: XCTestCase {
    private let keystore = Keychain()
    private(set) var settings = SettingsManager.shared

    override func setUp() {
        try? keystore.deleteAll()
        settings.removeAll()
    }

    override func tearDown() {
        try? keystore.deleteAll()
        settings.removeAll()
    }
/*
    func testSuccessfullRemoval() throws {
        // given
        settings.decentralizedId = Constants.dummyDid
        settings.publicKeyId = Constants.dummyPubKeyId

        let keypair = try IRIrohaKeyFactory().createRandomKeypair()

        try keystore.saveKey(keypair.privateKey().rawData(), with: KeystoreKey.privateKey.rawValue)

        let data = Data(repeating: 0, count: 32)

        try keystore.saveKey(data, with: KeystoreKey.seedEntropy.rawValue)

        let secondaryRepository = SecondaryIdentityRepository(keystore: keystore)
        try secondaryRepository.generateAndSaveForAll()

        let operation = IdentityOperationFactory().createLocalRemoveOperation(with: keystore,
                                                                              settings: settings)

        let expectation = XCTestExpectation()

        operation.completionBlock = {
            expectation.fulfill()
        }

        // when

        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)
        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard let result = operation.result, case .success = result else {
            XCTFail()
            return
        }

        XCTAssertNil(settings.decentralizedId)
        XCTAssertNil(settings.publicKeyId)

        XCTAssertFalse(try keystore.checkKey(for: KeystoreKey.privateKey.rawValue))
        XCTAssertFalse(try keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue))
        XCTAssertTrue(try secondaryRepository.checkAllEmpty())
    }

    func testEmptyIdentityRemovalDoesntThrow() throws {
        let operation = IdentityOperationFactory().createLocalRemoveOperation(with: keystore,
                                                                              settings: settings)

        let expectation = XCTestExpectation()

        operation.completionBlock = {
            expectation.fulfill()
        }

        // when

        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)
        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard let result = operation.result, case .success = result else {
            XCTFail()
            return
        }

        XCTAssertNil(settings.decentralizedId)
        XCTAssertNil(settings.publicKeyId)

        XCTAssertFalse(try keystore.checkKey(for: KeystoreKey.privateKey.rawValue))
        XCTAssertFalse(try keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue))
        XCTAssertTrue(try SecondaryIdentityRepository(keystore: keystore).checkAllEmpty())
    }
 */
}
