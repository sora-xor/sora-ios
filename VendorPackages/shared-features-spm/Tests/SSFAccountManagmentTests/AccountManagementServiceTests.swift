import MocksBasket
import RobinHood
import SSFAccountManagmentStorage
import SSFHelpers
import SSFModels
import SSFUtils
import XCTest

@testable import SSFAccountManagment

final class AccountManagementServiceTests: XCTestCase {
    var service: AccountManageble?
    var accountManagementWorker: AccountManagementWorkerProtocolMock?

    override func setUp() {
        super.setUp()
        let storageFacade = AccountStorageTestFacade()

        let accountManagementWorker = AccountManagementWorkerProtocolMock()
        accountManagementWorker.saveAccountCompletionClosure = { _, closure in
            closure()
        }
        self.accountManagementWorker = accountManagementWorker

        let selectedWallet = SelectedWalletSettings(storageFacade: storageFacade)

        service = AccountManagementService(
            accountManagementWorker: accountManagementWorker,
            selectedWallet: selectedWallet
        )
    }

    override func tearDown() {
        super.tearDown()
        service = nil
        accountManagementWorker = nil
    }

    func testGetCurrentAccountNoAccount() {
        // act
        let result = service?.getCurrentAccount()

        // assert
        XCTAssertNil(result)
    }

    func testSetCurrentAccount() throws {
        // act
        service?.setCurrentAccount(account: TestData.account, completionClosure: { [weak self] _ in
            let currentAccount = self?.service?.getCurrentAccount()

            // assert
            DispatchQueue.main.async {
                XCTAssertEqual(currentAccount, TestData.account)
            }
        })
    }

    func testUpdateVisability() throws {
        // arrange
        service?.setCurrentAccount(account: TestData.account, completionClosure: { [weak self] _ in

            // act
            let chain = TestData.chain
            let asset = TestData.asset

            let chainAsset = ChainAsset(chain: chain, asset: asset)

            Task { [weak self] in
                do {
                    let updatedAccount = try await self?.service?.updateEnabilibilty(for: chainAsset.chainAssetId.id)
                    
                    DispatchQueue.main.async { [weak self] in
                        XCTAssertTrue(
                            self?.accountManagementWorker?
                                .saveAccountCompletionCalled ?? false
                        )
                        
                        XCTAssertTrue(updatedAccount != nil)
                    }
                } catch {
                    XCTFail("UpdateVisability test failed with error - \(error)")
                }
            }
        })
    }
    
    func testUpdateWalletName() throws {
        service?.setCurrentAccount(account: TestData.account, completionClosure: { [weak self] _ in
            
            let expectedAccount = TestData.walletName
            Task { [weak self] in
                do {
                    let updatedAccount = try await self?.service?.updateWalletName(with: expectedAccount.name)
                    
                    DispatchQueue.main.async { [weak self] in
                        XCTAssertTrue(
                            self?.accountManagementWorker?
                                .saveAccountCompletionCalled ?? false
                        )
                        XCTAssertEqual(updatedAccount, expectedAccount, "Updated account name does not match the expected value")
                    }
                } catch {
                    XCTFail("UpdateWalletName test failed with error - \(error)")
                }
            }
        })
    }
    
    func testLogout() throws {
        // act
        service?.setCurrentAccount(account: TestData.account, completionClosure: { [weak self] _ in
            Task { [weak self] in
                try await self?.service?.logout()
                let currentAccount = self?.service?.getCurrentAccount()

                // assert
                XCTAssertNil(currentAccount)
            }
        })
    }
}

private extension AccountManagementServiceTests {
    enum TestData {
        static let chain = ChainModel(
            rank: 1,
            disabled: true,
            chainId: "Kusama",
            paraId: "test",
            name: "test",
            tokens: ChainRemoteTokens(
                type: .config,
                whitelist: nil,
                utilityId: nil,
                tokens: [asset]
            ),
            xcm: nil,
            nodes: [],
            icon: nil,
            iosMinAppVersion: nil,
            properties: .init(addressPrefix: "1", rank: "2", paraId: "test", ethereumBased: true)
        )

        static let asset = AssetModel(
            id: "2",
            name: "test",
            symbol: "XOR",
            isUtility: true,
            precision: 1,
            substrateType: .soraAsset,
            ethereumType: nil,
            tokenProperties: nil,
            price: nil,
            priceId: nil,
            coingeckoPriceId: nil,
            priceProvider: nil
        )

        static let chainAccounts = ChainAccountModel(
            chainId: "Kusama",
            accountId: Data(),
            publicKey: Data(),
            cryptoType: 2,
            ethereumBased: false
        )

        static let account = MetaAccountModel(
            metaId: "1",
            name: "test",
            substrateAccountId: Data(),
            substrateCryptoType: 1,
            substratePublicKey: Data(),
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [chainAccounts],
            assetKeysOrder: nil,
            assetFilterOptions: [],
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: .defaultCurrency(),
            networkManagmentFilter: nil,
            enabledAssetIds: [],
            zeroBalanceAssetsHidden: true,
            hasBackup: false,
            favouriteChainIds: []
        )
        
        static let walletName = MetaAccountModel(
            metaId: "1",
            name: "newName",
            substrateAccountId: Data(),
            substrateCryptoType: 1,
            substratePublicKey: Data(),
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [chainAccounts],
            assetKeysOrder: nil,
            assetFilterOptions: [],
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: .defaultCurrency(),
            networkManagmentFilter: nil,
            enabledAssetIds: [],
            zeroBalanceAssetsHidden: true,
            hasBackup: false,
            favouriteChainIds: []
        )
    }
}
