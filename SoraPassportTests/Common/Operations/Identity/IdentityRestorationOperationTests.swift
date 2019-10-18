/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
import SoraKeystore
import SoraCrypto
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

    func testSuccessfullRestoration() {
        runRestorationTest(for: Constants.dummyValidMnemonic, expectsSuccess: true)
    }

    // MARK: Private

    func runRestorationTest(for phrase: String, expectsSuccess: Bool) {
        // given
        let mnemonicCreator = IRBIP39MnemonicCreator(language: .english)
        guard let mnemonic = try? mnemonicCreator.mnemonic(fromList: phrase.components(separatedBy: CharacterSet.wordsSeparator)) else {
            XCTFail()
            return
        }

        let operation = IdentityOperationFactory.createRestorationOperation(with: mnemonic)

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

        if expectsSuccess {
            guard let result = optionalResult, case .success = result else {
                XCTFail()
                return
            }

            let privateKeyExists = try? operation.keystore.checkKey(for: KeystoreKey.privateKey.rawValue)
            guard privateKeyExists == true else {
                XCTFail()
                return
            }

            let seedEntropyExists = try? operation.keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue)
            guard seedEntropyExists == true else {
                XCTFail()
                return
            }

        } else {
            guard let result = optionalResult, case .error = result else {
                XCTFail()
                return
            }

            let privateKeyExists = try? operation.keystore.checkKey(for: KeystoreKey.privateKey.rawValue)

            guard privateKeyExists != true else {
                XCTFail()
                return
            }
        }

    }
}
