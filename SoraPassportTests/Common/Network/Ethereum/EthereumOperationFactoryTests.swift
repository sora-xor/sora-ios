/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import SoraKeystore
import BigInt

class EthereumOperationFactoryTests: XCTestCase {
    func testFactorySuccessfullyCreated() {
        let keystore = InMemoryKeychain()

        _ = createIdentity(with: keystore)

        XCTAssertNoThrow(try EthereumOperationFactory(node: EthereumConstants.ropstenURL,
                                                      keystore: keystore))
    }

    func testWithdrawTransactionCreation() throws {
        // given

        let keystore = InMemoryKeychain()

        _ = createIdentity(with: keystore)

        let operationFactory = try EthereumOperationFactory(node: Constants.dummyNetworkURL,
                                                            keystore: keystore)

        let proofLength = 3

        let proof = (0..<proofLength).map { _ in
            EthereumSignature(vPart: 0, rPart: Data(repeating: 0, count: 32), sPart: Data(repeating: 0, count: 32))
        }

        let withdrawInfo = EthereumWithdrawInfo(txHash: Constants.withdrawalHash,
                                                amount: BigUInt(200),
                                                proof: proof,
                                                destination: Constants.dummyEthAddress.soraHexWithPrefix)

        // when

        let operation = operationFactory
            .createWithdrawTransactionOperation(for: { withdrawInfo },
                                                tokenAddressConfig: { EthereumConstants.xorERC20Address },
                                                masterContractAddress: EthereumConstants.masterContractOnRopsten)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        // then

        guard let result = operation.result else {
            XCTFail("Unexpected empty result")
            return
        }

        if case .failure(let error) = result {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testERC20TransferTransactionCreation() throws {
        // given

        let keystore = InMemoryKeychain()

        _ = createIdentity(with: keystore)

        let operationFactory = try EthereumOperationFactory(node: Constants.dummyNetworkURL,
                                                            keystore: keystore)

        let transferInfo = ERC20TransferInfo(tokenAddress: EthereumConstants.xorERC20Address,
                                             destinationAddress: EthereumConstants.masterContractOnRopsten,
                                             amount: 100)

        // when

        let operation = operationFactory.createERC20TransferTransactionOperation { transferInfo }

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        // then

        guard let result = operation.result else {
            XCTFail("Unexpected empty result")
            return
        }

        if case .failure(let error) = result {
            XCTFail("Unexpected error \(error)")
        }
    }
}
