/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

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

    func testSuccessfullRemoval() {
        // given
        settings.decentralizedId = Constants.dummyDid
        settings.publicKeyId = Constants.dummyPubKeyId

        guard let keypair = IREd25519KeyFactory().createRandomKeypair() else {
            XCTFail()
            return
        }

        XCTAssertNoThrow(try keystore.saveKey(keypair.privateKey().rawData(), with: KeystoreKey.privateKey.rawValue))

        let operation = IdentityOperationFactory.createLocalRemoveOperation()

        let expectation = XCTestExpectation()

        operation.completionBlock = {
            expectation.fulfill()
        }

        // when

        OperationManager.shared.enqueue(operations: [operation], in: .normal)
        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard let result = operation.result, case .success = result else {
            XCTFail()
            return
        }

        XCTAssertNil(settings.decentralizedId)
        XCTAssertNil(settings.publicKeyId)

        guard (try? keystore.checkKey(for: KeystoreKey.privateKey.rawValue)) == false else {
            XCTFail()
            return
        }
    }

}
