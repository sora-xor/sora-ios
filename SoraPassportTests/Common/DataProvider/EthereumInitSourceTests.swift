/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import SoraKeystore
import IrohaCommunication
import RobinHood
import SoraCrypto

class EthereumInitSourceTests: NetworkBaseTests {

    func testSuccessfullSync() throws {
        // given

        let keystore = InMemoryKeychain()

        let keypairResult = try IRKeypairFacade().createKeypair()

        try keystore.saveKey(keypairResult.keypair.privateKey().rawData(),
                             with: KeystoreKey.privateKey.rawValue)

        let signer = IRSigningDecorator(keystore: keystore, identifier: KeystoreKey.privateKey.rawValue)

        let accountId = try IRAccountIdFactory.account(withIdentifier: Constants.dummyWalletAccountId)

        let registrationFactory = try EthereumRegistrationFactory(signer: signer,
                                                                  publicKey: keypairResult.keypair.publicKey(),
                                                                  sender: accountId)

        let mapper = SidechainInitDataMapper<EthereumInitUserInfo>()

        let facade = UserStoreTestFacade()
        let repository = facade.createCoreDataCache(filter: nil, mapper: AnyCoreDataMapper(mapper))

        let requestSigner = DARequestSigner()
            .with(rawSigner: signer)
            .with(publicKeyId: Constants.dummyPubKeyId)
            .with(decentralizedId: Constants.dummyDid)

        let walletUnit = ApplicationConfig.shared.defaultWalletUnit

        let source = EthereumInitSource(serviceUnit: walletUnit,
                                        operationFactory: registrationFactory,
                                        repository: AnyDataProviderRepository(repository),
                                        requestSigner: requestSigner,
                                        operationManager: OperationManager())

        WalletEthereumStateMock.register(mock: .success, walletUnit: walletUnit)

        let observable = CoreDataContextObservable(service: facade.databaseService,
                                                   mapper: repository.dataMapper,
                                                   predicate: { object in object.identifier == SidechainId.eth.rawValue })

        observable.start { error in
            XCTAssertNil(error)
        }

        // when

        let observableExpectation = XCTestExpectation()

        observable.addObserver(self, deliverOn: .main) { changes in
            defer {
                observableExpectation.fulfill()
            }

            XCTAssertEqual(changes.count, 1)

            guard case .insert = changes.first else {
                XCTFail("Unexpected changes \(changes)")
                return
            }
        }

        let completionExpectation = XCTestExpectation()

        source.refresh(runningIn: .main) { result in
            defer {
                completionExpectation.fulfill()
            }

            guard case .success(let count) = result else {
                XCTFail("Unexpected result \(String(describing: result))")
                return
            }

            XCTAssertEqual(count, 1)
        }

        // then

        wait(for: [completionExpectation, observableExpectation], timeout: Constants.networkRequestTimeout)
    }
}
