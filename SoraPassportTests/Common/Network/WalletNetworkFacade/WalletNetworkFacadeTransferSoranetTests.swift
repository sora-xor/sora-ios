/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import RobinHood
import SoraKeystore
import SoraFoundation
import CommonWallet
import Cuckoo
import BigInt

class WalletNetworkFacadeTransferSoranetTests: XCTestCase {
    typealias StoreValidationClosure = ([TransferOperationData], [WithdrawOperationData], [DepositOperationData]) -> Bool

    func testXORtoXOR() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 200)
        let sending: Decimal = 100
        let ethBalance = AmountDecimal(value: 0.5)

        let soranetOperationFactory = WalletNetworkOperationFactoryProtocolMock()
        let ethereumOperationFactory = MockEthereumOperationFactoryProtocol()

        // when

        let expectation = XCTestExpectation()

        soranetOperationFactory.transferClosure = { info in
            defer {
                expectation.fulfill()
            }

            XCTAssertEqual(info.amount.decimalValue, sending)

            let operation = ClosureOperation<Data> { Constants.transactionHash }
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let transferInfo = try createTransferInfo(amount: sending,
                                                  tokens: tokens,
                                                  ethBalance: ethBalance,
                                                  soranetFee: feeValue)

        let validator: StoreValidationClosure = { transfers, withdrawals, deposits in
            transfers.isEmpty && withdrawals.isEmpty && deposits.isEmpty
        }

        try performTransferTest(transferInfo,
                                soranetOperationFactory: soranetOperationFactory,
                                ethereumOperationFactory: ethereumOperationFactory,
                                validator: validator)

        // then

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testERC20toXOR() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 0, ethereum: 300)
        let sending: Decimal = 201
        let ethBalance = AmountDecimal(value: 0.5)

        let soranetOperationFactory = WalletNetworkOperationFactoryProtocolMock()
        let ethereumOperationFactory = MockEthereumOperationFactoryProtocol()

        // when

        let expectation = XCTestExpectation()

        stub(ethereumOperationFactory) { stub in
            when(stub).createGasPriceOperation().then {
                let operation = ClosureOperation<BigUInt> { 1000000000 }
                return operation
            }

            when(stub).createXORAddressFetchOperation(from: any()).then { _ in
                let operation = ClosureOperation<Data> { Data() }
                return operation
            }

            when(stub).createERC20TransferTransactionOperation(for: any()).then { _ in
                let operation = ClosureOperation<Data> { Data() }
                return operation
            }

            when(stub).createTransactionsCountOperation(for: any(), block: any()).then { _ in
                let operation = ClosureOperation<BigUInt> { 1 }
                return operation
            }

            when(stub).createSendTransactionOperation(for: any()).then { _ in
                defer {
                    expectation.fulfill()
                }

                let operation = ClosureOperation<Data> { Constants.transactionHash }
                return operation
            }
        }

        let transferInfo = try createTransferInfo(amount: sending,
                                                  tokens: tokens,
                                                  ethBalance: ethBalance,
                                                  soranetFee: feeValue)

        let validator: StoreValidationClosure = { transfers, withdrawals, deposits in
            if !(transfers.isEmpty && withdrawals.isEmpty) {
                return false
            }

            if deposits.count != 1 {
                return false
            }

            return
                deposits[0].depositAmount.decimalValue == sending + feeValue.decimalValue &&
                deposits[0].transferAmount?.decimalValue == sending &&
                deposits[0].status == .depositPending
        }

        try performTransferTest(transferInfo,
                                soranetOperationFactory: soranetOperationFactory,
                                ethereumOperationFactory: ethereumOperationFactory,
                                validator: validator)

        // then

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testXORERC20toXOR() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 200)
        let sending: Decimal = 200
        let ethBalance = AmountDecimal(value: 0.5)

        let soranetOperationFactory = WalletNetworkOperationFactoryProtocolMock()
        let ethereumOperationFactory = MockEthereumOperationFactoryProtocol()

        // when

        let expectation = XCTestExpectation()

        stub(ethereumOperationFactory) { stub in
            when(stub).createGasPriceOperation().then {
                let operation = ClosureOperation<BigUInt> { 1000000000 }
                return operation
            }

            when(stub).createXORAddressFetchOperation(from: any()).then { _ in
                let operation = ClosureOperation<Data> { Data() }
                return operation
            }

            when(stub).createERC20TransferTransactionOperation(for: any()).then { _ in
                let operation = ClosureOperation<Data> { Data() }
                return operation
            }

            when(stub).createTransactionsCountOperation(for: any(), block: any()).then { _ in
                let operation = ClosureOperation<BigUInt> { 1 }
                return operation
            }

            when(stub).createSendTransactionOperation(for: any()).then { _ in
                defer {
                    expectation.fulfill()
                }

                let operation = ClosureOperation<Data> { Data() }
                return operation
            }
        }

        let transferInfo = try createTransferInfo(amount: sending,
                                                  tokens: tokens,
                                                  ethBalance: ethBalance,
                                                  soranetFee: feeValue)

        let validator: StoreValidationClosure = { transfers, withdrawals, deposits in
            if !(transfers.isEmpty && withdrawals.isEmpty) {
                return false
            }

            if deposits.count != 1 {
                return false
            }

            return
                deposits[0].depositAmount.decimalValue == sending + feeValue.decimalValue - tokens.soranet &&
                deposits[0].transferAmount?.decimalValue == sending &&
                deposits[0].status == .depositPending
        }

        try performTransferTest(transferInfo,
                                soranetOperationFactory: soranetOperationFactory,
                                ethereumOperationFactory: ethereumOperationFactory,
                                validator: validator)

        // then

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    // MARK: Private

    private func performTransferTest(_ transferInfo: TransferInfo,
                                     soranetOperationFactory: WalletNetworkOperationFactoryProtocol & WalletRemoteHistoryOperationFactoryProtocol,
                                     ethereumOperationFactory: EthereumOperationFactoryProtocol,
                                     validator: StoreValidationClosure) throws {
        let primitiveFactory = WalletPrimitiveFactory(keychain: InMemoryKeychain(),
                                                      settings: InMemorySettingsManager(),
                                                      localizationManager: LocalizationManager.shared)

        let xorAsset = try primitiveFactory.createXORAsset()
        let valAsset = try primitiveFactory.createVALAsset()
        let ethAsset = try primitiveFactory.createETHAsset()

        let storeFacade = UserStoreTestFacade()
        let transferRepository: CoreDataRepository<TransferOperationData, CDTransfer> =
            storeFacade.createCoreDataCache()
        let withdrawRepository: CoreDataRepository<WithdrawOperationData, CDWithdraw> =
            storeFacade.createCoreDataCache()
        let depositRepository: CoreDataRepository<DepositOperationData, CDDeposit> =
            storeFacade.createCoreDataCache()

        let historyFactory =
            WalletHistoryOperationFactory(networkOperationFactory: soranetOperationFactory,
                                          transferRepository: AnyDataProviderRepository(transferRepository),
                                          withdrawRepository: AnyDataProviderRepository(withdrawRepository),
                                          depositRepository: AnyDataProviderRepository(depositRepository))

        let networkFacade = WalletNetworkFacade(soranetOperationFactory: soranetOperationFactory,
                                                ethereumOperationFactory: ethereumOperationFactory,
                                                transferRepository: AnyDataProviderRepository(transferRepository),
                                                withdrawRepository: AnyDataProviderRepository(withdrawRepository),
                                                depositRepository: AnyDataProviderRepository(depositRepository),
                                                historyOperationFactory: historyFactory,
                                                soranetAccountId: Constants.dummyWalletAccountId,
                                                ethereumAddress: Constants.dummyEthAddress,
                                                masterContractAddress: EthereumConstants.masterContractOnRopsten,
                                                xorAssetId: xorAsset.identifier,
                                                valAssetId: valAsset.identifier,
                                                ethAssetId: ethAsset.identifier)

        let wrapper = networkFacade.transferOperation(transferInfo)

        let operationQueue = OperationQueue()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        _ = try wrapper.targetOperation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        let transferItems = try fetchAll(from: AnyDataProviderRepository(transferRepository),
                                         operationQueue: operationQueue,
                                         expectationHandler: self)

        let withdrawItems = try fetchAll(from: AnyDataProviderRepository(withdrawRepository),
                                         operationQueue: operationQueue,
                                         expectationHandler: self)

        let depositItems = try fetchAll(from: AnyDataProviderRepository(depositRepository),
                                         operationQueue: operationQueue,
                                         expectationHandler: self)

        XCTAssertTrue(validator(transferItems, withdrawItems, depositItems))
    }

    private func createTransferInfo(amount: Decimal,
                                    tokens: TokenBalancesData,
                                    ethBalance: AmountDecimal,
                                    soranetFee: AmountDecimal) throws -> TransferInfo {
        let primitiveFactory = WalletPrimitiveFactory(keychain: InMemoryKeychain(),
                                                      settings: InMemorySettingsManager(),
                                                      localizationManager: LocalizationManager.shared)

        let xorAsset = try primitiveFactory.createXORAsset()
        let ethAsset = try primitiveFactory.createETHAsset()

        let metadata = try createTransferMetadataFromTokens(tokens,
                                                            ethBalance: ethBalance,
                                                            soranetFee: soranetFee,
                                                            xorAsset: xorAsset,
                                                            ethAsset: ethAsset)

        let balances = try createBalancesFromTokens(tokens,
                                                    ethBalance: ethBalance,
                                                    xorAsset: xorAsset,
                                                    ethAsset: ethAsset)

        let feeResult = try calculateFeeForAmount(amount,
                                                  feeDescriptions: metadata.feeDescriptions,
                                                  xorAsset: xorAsset,
                                                  ethAsset: ethAsset)

        let transferInfo = TransferInfo(source: Constants.dummyWalletAccountId,
                                        destination: Constants.dummyOtherWalletAccountId,
                                        amount: AmountDecimal(value: amount),
                                        asset: xorAsset.identifier,
                                        details: "",
                                        fees: feeResult.fees)

        return try WalletTransferValidator().validate(info: transferInfo,
                                                      balances: balances,
                                                      metadata: metadata)
    }

    private func createBalancesFromTokens(_ tokens: TokenBalancesData,
                                          ethBalance: AmountDecimal,
                                          xorAsset: WalletAsset,
                                          ethAsset: WalletAsset) throws -> [BalanceData] {
        let context: [String: String] = [
            WalletOperationContextKey.Balance.soranet: tokens.soranet.stringWithPointSeparator,
            WalletOperationContextKey.Balance.erc20: tokens.ethereum.stringWithPointSeparator
        ]

        let xorBalance = BalanceData(identifier: xorAsset.identifier,
                                     balance: AmountDecimal(value: tokens.soranet + tokens.ethereum),
                                     context: context)

        let ethBalance = BalanceData(identifier: ethAsset.identifier,
                                     balance: ethBalance)

        return [xorBalance, ethBalance]
    }

    private func createTransferMetadataFromTokens(_ tokens: TokenBalancesData,
                                                  ethBalance: AmountDecimal,
                                                  soranetFee: AmountDecimal,
                                                  xorAsset: WalletAsset,
                                                  ethAsset: WalletAsset) throws -> TransferMetaData {
        let context: [String: String] = [
            WalletOperationContextKey.Balance.soranet: tokens.soranet.stringWithPointSeparator,
            WalletOperationContextKey.Balance.erc20: tokens.ethereum.stringWithPointSeparator
        ]

        let xorFeeDescription = FeeDescription(identifier: SoranetFeeId.transfer.rawValue,
                                               assetId: xorAsset.identifier,
                                               type: WalletFeeType.fixed.rawValue,
                                               parameters: [soranetFee],
                                               context: context)

        let ethParameters = EthFeeParameters(transferGas: AmountDecimal(value: Decimal(EthereumGasLimit.estimated.transfer)),
                                             mintGas: AmountDecimal(value: Decimal(EthereumGasLimit.estimated.mint)),
                                             gasPrice: AmountDecimal(value: 0.0000000001),
                                             balance: ethBalance)

        let ethFeeDescription = FeeDescription(identifier: WalletNetworkConstants.ethFeeIdentifier,
                                               assetId: ethAsset.identifier,
                                               type: WalletFeeType.fixed.rawValue,
                                               parameters: ethParameters)

        return TransferMetaData(feeDescriptions: [xorFeeDescription, ethFeeDescription])
    }

    private func calculateFeeForAmount(_ amount: Decimal,
                                       feeDescriptions: [FeeDescription],
                                       xorAsset: WalletAsset,
                                       ethAsset: WalletAsset) throws -> FeeCalculationResult {
        let feeFactory = WalletFeeCalculatorFactory(xorPrecision: xorAsset.precision,
                                                    ethPrecision: ethAsset.precision)

        let strategy = try feeFactory.createTransferFeeStrategyForDescriptions(feeDescriptions,
                                                                               assetId: xorAsset.identifier,
                                                                               precision: xorAsset.precision)

        return try strategy.calculate(for: amount)
    }
}
