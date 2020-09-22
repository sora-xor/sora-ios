import XCTest
@testable import SoraPassport
import IrohaCrypto
import IrohaCommunication
import CommonWallet
import SoraFoundation
import SoraKeystore

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

            let localizationManager = LocalizationManager(localization: Constants.englishLocalization)!

            let primitiveFactory = WalletPrimitiveFactory(keychain: keychain,
                                                          settings: settings,
                                                          localizationManager: localizationManager)
            let accountId = try primitiveFactory.createAccountId()
            let accountSettings = try primitiveFactory.createAccountSettings(for: accountId)
            let operationSettings = try primitiveFactory.createOperationSettings()

            let networkResolver = WalletNetworkResolverMock { _ in
                return transferService.serviceEndpoint
            }

            let networkFactory = SoraNetworkOperationFactory(accountSettings: accountSettings,
                                                             operationSettings: operationSettings,
                                                             networkResolver: networkResolver)

            let sourceAccountId = Constants.dummyWalletAccountId
            let destinationAccountId = Constants.dummyOtherWalletAccountId
            let amount = AmountDecimal(value: 100)

            let feeValue = AmountDecimal(string: "0.1")!
            let feeDesc = FeeDescription(identifier: UUID().uuidString,
                                         assetId: accountSettings.assets[0].identifier,
                                         type: "FIXED",
                                         parameters: [feeValue])
            let fee = Fee(value: feeValue, feeDescription: feeDesc)

            let assetId = accountSettings.assets.first!.identifier
            let transferInfo = TransferInfo(source: sourceAccountId,
                                            destination: destinationAccountId,
                                            amount: amount,
                                            asset: assetId,
                                            details: "",
                                            fees: [fee])

            // when

            let wrapper = networkFactory.transferOperation(transferInfo)

            let expectation = XCTestExpectation()

            wrapper.targetOperation.completionBlock = {
                defer {
                    expectation.fulfill()
                }

                guard let result = wrapper.targetOperation.result else {
                    XCTFail("Unexpected empty result")
                    return
                }

                if case .failure(let error) = result {
                    XCTFail("Unexpected result error \(error)")
                }
            }

            let operationQueue = OperationQueue()
            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

            // then

            wait(for: [expectation], timeout: Constants.networkRequestTimeout)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testWithdrawSuccess() {
        do {
            // given

            let walletUnit = ApplicationConfig.shared.defaultWalletUnit

            guard let withdrawService = walletUnit.service(for: WalletServiceType.withdraw.rawValue) else {
                XCTFail("Withdraw service endpoint missing")
                return
            }

            WalletWithdrawMock.register(mock: .success, walletUnit: walletUnit)

            let result = try IRKeypairFacade().createKeypair()

            let keychain = InMemoryKeychain()
            try keychain.saveKey(result.keypair.privateKey().rawData(),
                                 with: KeystoreKey.privateKey.rawValue)

            var settings = InMemorySettingsManager()
            settings.decentralizedId = Constants.dummyDid
            settings.publicKeyId = Constants.dummyPubKeyId

            let localizationManager = LocalizationManager(localization: Constants.englishLocalization)!

            let primitiveFactory = WalletPrimitiveFactory(keychain: keychain,
                                                          settings: settings,
                                                          localizationManager: localizationManager)
            let accountId = try primitiveFactory.createAccountId()
            let accountSettings = try primitiveFactory.createAccountSettings(for: accountId)
            let operationSettings = try primitiveFactory.createOperationSettings()

            let networkResolver = WalletNetworkResolverMock { _ in
                return withdrawService.serviceEndpoint
            }

            let networkFactory = SoraNetworkOperationFactory(accountSettings: accountSettings,
                                                             operationSettings: operationSettings,
                                                             networkResolver: networkResolver)

            let destinationAccountId = Constants.dummyOtherWalletAccountId
            let amount = AmountDecimal(value: 100)

            let feeValue = AmountDecimal(string: "0.1")!
            let feeDesc = FeeDescription(identifier: UUID().uuidString,
                                         assetId: accountSettings.assets[0].identifier,
                                         type: "FIXED",
                                         parameters: [feeValue])
            let fee = Fee(value: feeValue, feeDescription: feeDesc)

            let assetId = accountSettings.assets.first!.identifier
            let withdrawInfo = WithdrawInfo(destinationAccountId: destinationAccountId,
                                            assetId: assetId,
                                            amount: amount,
                                            details: Constants.dummyEthAddress.soraHexWithPrefix,
                                            fees: [fee])

            // when

            let wrapper = networkFactory.withdrawOperation(withdrawInfo)

            let expectation = XCTestExpectation()

            wrapper.targetOperation.completionBlock = {
                defer {
                    expectation.fulfill()
                }

                guard let result = wrapper.targetOperation.result else {
                    XCTFail("Unexpected empty result")
                    return
                }

                if case .failure(let error) = result {
                    XCTFail("Unexpected result error \(error)")
                }
            }

            let operationQueue = OperationQueue()
            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

            // then

            wait(for: [expectation], timeout: Constants.networkRequestTimeout)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

}
