import XCTest
import SoraKeystore
//import SoraCrypto
import RobinHood
@testable import SoraPassport

class IdentityCopyOperationTests: XCTestCase {
    private let keystore = Keychain()

    override func setUp() {
        try? keystore.deleteAll()
    }

    override func tearDown() {
        try? keystore.deleteAll()
    }
/*
    func testSuccessfullIdentityCopy() throws {
        // given

        let anotherKeyStore = InMemoryKeychain()

        let factory = IdentityOperationFactory()
        let createOperation = factory.createNewIdentityOperation(with: anotherKeyStore)
        let copyOperation = factory.createCopyingOperation(oldKeystore: anotherKeyStore, newKeystore: keystore)

        copyOperation.addDependency(createOperation)

        let expectation = XCTestExpectation()

        var optionalResult: Result<Void, Error>?

        copyOperation.completionBlock = {
            optionalResult = copyOperation.result
            expectation.fulfill()
        }

        // when
        OperationManagerFacade.sharedManager.enqueue(operations: [createOperation, copyOperation],
                                                     in: .transient)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard let result = optionalResult, case .success = result else {
            XCTFail()
            return
        }

        XCTAssertTrue(try keystore.checkKey(for: KeystoreKey.privateKey.rawValue))
        XCTAssertTrue(try keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue))
        XCTAssertTrue(try SecondaryIdentityRepository(keystore: keystore).checkAllExist())
    }
 */
}
