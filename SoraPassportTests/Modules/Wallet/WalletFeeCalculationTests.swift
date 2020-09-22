import XCTest
@testable import SoraPassport
import CommonWallet
import SoraKeystore
import SoraFoundation

class WalletFeeCalculationTests: XCTestCase {
    func testNoFee() throws {
        // given

        let primitiveFactory = WalletPrimitiveFactory(keychain: InMemoryKeychain(),
                                                      settings: InMemorySettingsManager(),
                                                      localizationManager: LocalizationManager.shared)

        let xorAsset = try primitiveFactory.createXORAsset()
        let ethAsset = try primitiveFactory.createETHAsset()

        let feeFactory = WalletFeeCalculatorFactory(xorPrecision: xorAsset.precision,
                                                    ethPrecision: ethAsset.precision)

        // when

        let strategy = try feeFactory.createTransferFeeStrategyForDescriptions([],
                                                                               assetId: xorAsset.identifier,
                                                                               precision: xorAsset.precision)

        let amount: Decimal = 100

        let result = try strategy.calculate(for: amount)

        // then

        XCTAssertEqual(result.sending, amount)
        XCTAssertEqual(result.total, amount)
        XCTAssertEqual(result.fees.count, 0)
    }
}
