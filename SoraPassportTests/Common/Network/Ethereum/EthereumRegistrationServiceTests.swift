import XCTest
@testable import SoraPassport
import SoraKeystore
import IrohaCommunication
import SoraCrypto

class EthereumRegistrationServiceTests: NetworkBaseTests {
    func testSuccessfullRegistration() throws {
        // given

        let walletUnit = ApplicationConfig.shared.defaultWalletUnit

        let registrationService = try createEthereumRegistrationService(for: walletUnit)

        WalletEthereumRegistrationMock.register(mock: .success,
                                                walletUnit: walletUnit)

        // when

        let expectation = XCTestExpectation()

        let operations = registrationService.sendIntention(runCompletionIn: .main) { optionalResult in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult else {
                XCTFail("Unexpected empty result")
                return
            }

            if case .failure(let error) = result {
                XCTFail("Unexpected error \(error)")
            }
        }

        // then

        XCTAssertTrue(!operations.isEmpty)

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testSuccessfullStateFetch() throws {
        // given

        let walletUnit = ApplicationConfig.shared.defaultWalletUnit

        let registrationService = try createEthereumRegistrationService(for: walletUnit)

        WalletEthereumStateMock.register(mock: .success, walletUnit: walletUnit)

        // when

        let expectation = XCTestExpectation()

        let operations = registrationService.fetchState(runCompletionIn: .main) { optionalResult in
            defer {
                expectation.fulfill()
            }

            XCTAssertNotNil(optionalResult)

            if case .failure(let error) = optionalResult {
                XCTFail("Unexpected error \(error)")
            }
        }

        // then

        XCTAssertTrue(!operations.isEmpty)

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testEthereumRegistrationNotFound() throws {
        // given

        let walletUnit = ApplicationConfig.shared.defaultWalletUnit

        let registrationService = try createEthereumRegistrationService(for: walletUnit)

        WalletEthereumStateMock.register(mock: .notFound, walletUnit: walletUnit)

        // when

        let expectation = XCTestExpectation()

        let operations = registrationService.fetchState(runCompletionIn: .main) { optionalResult in
            defer {
                expectation.fulfill()
            }

            XCTAssertNotNil(optionalResult)

            if case .failure(let error) = optionalResult,
                let registrationError = error as? EthereumInitDataError,
                registrationError == .notFound {
                return
            }
        }

        // then

        XCTAssertTrue(!operations.isEmpty)

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    // MARK: Private

    private func createEthereumRegistrationService(for unit: ServiceUnit) throws
        -> EthereumRegistrationServiceProtocol {
        let keystore = InMemoryKeychain()
        createIdentity(with: keystore)

        let privateKey = try keystore.fetchKey(for: KeystoreKey.privateKey.rawValue)
        let keypair = try IRIrohaKeyFactory()
            .derive(fromPrivateKey: IRIrohaPrivateKey(rawData: privateKey))

        let signer = IRSigningDecorator(keystore: keystore, identifier: KeystoreKey.privateKey.rawValue)
        let requestSigner = DARequestSigner()
            .with(publicKeyId: Constants.dummyPubKeyId)
            .with(decentralizedId: Constants.dummyDid)
            .with(rawSigner: signer)

        let sender = try IRAccountIdFactory.account(withIdentifier: Constants.dummyWalletAccountId)

        let operationFactory = try EthereumRegistrationFactory(signer: signer,
                                                               publicKey: keypair.publicKey(),
                                                               sender: sender)

        return EthereumRegistrationService(serviceUnit: unit,
                                           operationFactory: operationFactory,
                                           keystore: keystore,
                                           requestSigner: requestSigner)
    }
}
