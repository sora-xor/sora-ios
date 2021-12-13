import XCTest
import SoraKeystore
//import SoraCrypto
import IrohaCrypto
import RobinHood
@testable import SoraPassport

class IdentityRestorationOperationTests: XCTestCase {
    private let keystore = Keychain()

    override func setUp() {
        try? keystore.deleteAll()
    }

    override func tearDown() {
        try? keystore.deleteAll()
    }
/*
    func testSuccessfullRestoration() throws {
        try runRestorationTest(for: Constants.dummyValidMnemonic, expectsSuccess: true)
    }

    // MARK: Private

    func runRestorationTest(for mnemonic: String, expectsSuccess: Bool) throws {
        // given
        let mnemonicCreator = IRMnemonicCreator(language: .english)
        let mnemonicRepresentation = try mnemonicCreator.mnemonic(fromList: mnemonic)

        let operation = IdentityOperationFactory()
            .createRestorationOperation(with: mnemonicRepresentation, keystore: keystore)

        let expectation = XCTestExpectation()

        var optionalResult: Result<DecentralizedDocumentObject, Error>?

        operation.completionBlock = {
            optionalResult = operation.result
            expectation.fulfill()
        }

        // when

        OperationManagerFacade.sharedManager.enqueue(operations: [operation],
                                                     in: .transient)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        if expectsSuccess {
            guard let result = optionalResult, case .success = result else {
                XCTFail()
                return
            }

            XCTAssertTrue(try operation.keystore.checkKey(for: KeystoreKey.privateKey.rawValue))
            XCTAssertTrue(try operation.keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue))
            XCTAssertTrue(try SecondaryIdentityRepository(keystore: operation.keystore).checkAllExist())

        } else {
            guard let result = optionalResult, case .failure = result else {
                XCTFail()
                return
            }
        }
    }
 */
}
