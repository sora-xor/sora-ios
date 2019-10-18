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

            let networkFactory = SoraNetworkOperationFactory(accountSettings: accountSettings)

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

            let operation = networkFactory.transferOperation(transferService.serviceEndpoint,
                                                             info: transferInfo)

            let expectation = XCTestExpectation()

            operation.completionBlock = {
                if let result = operation.result {
                    switch result {
                    case .success(let value):
                        XCTAssert(value)
                    case .error(let error):
                        XCTFail("Unexpected result error \(error)")
                    }
                }

                expectation.fulfill()
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
