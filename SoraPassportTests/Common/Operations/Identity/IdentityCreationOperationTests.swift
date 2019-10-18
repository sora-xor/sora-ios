/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
import SoraKeystore
import SoraCrypto
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

    func testSuccessfullIdentityCreation() {
        // given
        let operation = IdentityOperationFactory.createNewIdentityOperation()

        let expectation = XCTestExpectation()

        var optionalResult: OperationResult<DecentralizedDocumentObject>?

        operation.completionBlock = {
            optionalResult = operation.result
            expectation.fulfill()
        }

        // when
        OperationManager.shared.enqueue(operations: [operation], in: .normal)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard let result = optionalResult, case .success = result else {
            XCTFail()
            return
        }

        guard (try? operation.keystore.checkKey(for: KeystoreKey.privateKey.rawValue)) == true else {
            XCTFail()
            return
        }

        guard (try? operation.keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue)) == true else {
            XCTFail()
            return
        }
    }
}
