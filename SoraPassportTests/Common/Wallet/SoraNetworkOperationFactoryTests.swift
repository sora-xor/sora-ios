/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import IrohaCrypto
import IrohaCommunication
import CommonWallet

class SoraNetworkOperationFactoryTests: NetworkBaseTests {

    func testTransferSuccess() {
        do {
            // given

            let walletUnit = ApplicationConfig.shared.defaultWalletUnit

            guard let transferService = walletUnit.service(for: WalletServiceType.transfer.rawValue) else {
                XCTFail("Transfer service endpoint missing")
                return
            }

            WalletTransferMock.register(mock: .success, walletUnit: walletUnit)

            let result = try IRKeypairFacade().createKeypair()

            let keychain = InMemoryKeychain()
            try keychain.saveKey(result.keypair.privateKey().rawData(),
                                 with: KeystoreKey.privateKey.rawValue)

            var settings = InMemorySettingsManager()
            settings.decentralizedId = Constants.dummyDid
            settings.publicKeyId = Constants.dummyPubKeyId

            let primitiveFactory = WalletPrimitiveFactory(keychain: keychain, settings: settings)
            let accountId = try primitiveFactory.createAccountId()
            let accountSettings = try primitiveFactory.createAccountSettings(for: accountId)

            let networkResolver = WalletNetworkResolverMock { _ in
                return transferService.serviceEndpoint
            }

            let networkFactory = SoraNetworkOperationFactory(accountSettings: accountSettings, networkResolver: networkResolver)

            let sourceAccountId = try IRAccountIdFactory.account(withIdentifier: Constants.dummyWalletAccountId)
            let destinationAccountId = try IRAccountIdFactory.account(withIdentifier: Constants.dummyOtherWalletAccountId)
            let amount = try IRAmountFactory.amount(fromUnsignedInteger: 100)
            let fee = try IRAmountFactory.amount(from: "0.1")
            let assetId = accountSettings.assets.first!.identifier
            let transferInfo = TransferInfo(source: sourceAccountId,
                                            destination: destinationAccountId,
                                            amount: amount,
                                            asset: assetId,
                                            details: "",
                                            feeAccountId: nil,
                                            fee: fee)

            // when

            let operation = networkFactory.transferOperation(transferInfo)

            let expectation = XCTestExpectation()

            operation.completionBlock = {
                defer {
                    expectation.fulfill()
                }

                guard let result = operation.result else {
                    XCTFail("Unexpected empty result")
                    return
                }

                if case .failure(let error) = result {
                    XCTFail("Unexpected result error \(error)")
                }
            }

            let operationQueue = OperationQueue()
            operationQueue.addOperation(operation)

            // then

            wait(for: [expectation], timeout: Constants.networkRequestTimeout)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

}
