import XCTest
import SoraKeystore
//import SoraCrypto
import RobinHood
@testable import SoraPassport

class IdentityCreationOperationTests: XCTestCase {
    private let keystore = Keychain()

    override func setUp() {
        try? keystore.deleteAll()
    }

    override func tearDown() {
        try? keystore.deleteAll()
    }
/*
    func testSuccessfullIdentityCreation() throws {
        // given
        let operation = IdentityOperationFactory().createNewIdentityOperation(with: keystore)

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

        guard let result = optionalResult, case .success = result else {
            XCTFail()
            return
        }

        XCTAssertTrue(try operation.keystore.checkKey(for: KeystoreKey.privateKey.rawValue))
        XCTAssertTrue(try operation.keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue))
        XCTAssertTrue(try SecondaryIdentityRepository(keystore: operation.keystore).checkAllExist())
    }
 */
}
