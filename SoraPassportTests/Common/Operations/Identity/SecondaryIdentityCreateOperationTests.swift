import XCTest
import SoraKeystore
//import SoraCrypto
import RobinHood
import IrohaCrypto
@testable import SoraPassport

class SecondaryIdentityCreateOperationTests: XCTestCase {
    private let keystore = Keychain()

    override func setUp() {
        try? keystore.deleteAll()
    }

    override func tearDown() {
        try? keystore.deleteAll()
    }
/*
    func testSecondaryIdentityCreationSuccess() throws {
        // given

        let entropy = try IRMnemonicCreator(language: .english)
            .mnemonic(fromList: Constants.dummyValidMnemonic).entropy()
        try keystore.saveKey(entropy, with: KeystoreKey.seedEntropy.rawValue)

        let operation = IdentityOperationFactory().createSecondaryIdentitiesOperation(with: keystore,
                                                                                      skipIfExists: false)

        let expectation = XCTestExpectation()

        var optionalResult: Result<Void, Error>?

        operation.completionBlock = {
            optionalResult = operation.result
            expectation.fulfill()
        }

        // when
        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard let result = optionalResult, case .success = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(entropy, try keystore.fetchKey(for: KeystoreKey.seedEntropy.rawValue))
        XCTAssertTrue(try SecondaryIdentityRepository(keystore: keystore).checkAllExist())
    }
*/
}
