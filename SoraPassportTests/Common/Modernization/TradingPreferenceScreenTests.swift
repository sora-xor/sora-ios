// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class TradingPreferenceScreenTests: XCTestCase {
    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) }
    }
    private func marketFixture(_ markets: [LiquiditySourceType] = [.smart, .xyk, .tbc]) -> (ChoiceMarketViewModel, ChoiceMarketViewController) {
        let model = ChoiceMarketViewModel(markets: markets, selectedMarket: .xyk)
        let screen = ChoiceMarketViewController(viewModel: model); model.view = screen; screen.loadViewIfNeeded()
        return (model, screen)
    }
    func testMarketScreenShowsExactlyTheAvailableSourcesAndOneSelection() {
        let (_, screen) = marketFixture(); let rows = descendants(MarketView.self, in: screen.view)
        XCTAssertEqual(rows.map(\.type), [.smart, .xyk, .tbc]); XCTAssertEqual(rows.filter(\.isSelectedMarket).map(\.type), [.xyk])
        XCTAssertTrue(rows.filter { $0.type != .xyk }.allSatisfy { $0.checkmarkImageView.isHidden })
    }
    func testChoosingMarketUpdatesScreenAndCompletionOnce() throws {
        let (model, screen) = marketFixture(); var chosen: [LiquiditySourceType] = []; model.completion = { chosen.append($0) }
        try XCTUnwrap(descendants(MarketView.self, in: screen.view).first { $0.type == .tbc }).sendActions(for: .touchUpInside)
        XCTAssertEqual(model.selectedMarket, .tbc); XCTAssertEqual(chosen, [.tbc])
        XCTAssertEqual(descendants(MarketView.self, in: screen.view).filter(\.isSelectedMarket).map(\.type), [.tbc])
    }
    func testReloadingMarketListReplacesOldRows() {
        let (_, screen) = marketFixture(); screen.setup(markets: [.xyk]); screen.setup(selectedMarket: .xyk)
        XCTAssertEqual(descendants(MarketView.self, in: screen.view).map(\.type), [.xyk])
    }
    func testEmptyMarketListRemovesPreviouslyAvailableRows() {
        let (_, screen) = marketFixture(); screen.setup(markets: [])
        XCTAssertTrue(descendants(MarketView.self, in: screen.view).isEmpty)
    }
    func testUnavailableMarketSelectionCannotBePublished() {
        let (model, screen) = marketFixture([.smart, .xyk]); var chosen: [LiquiditySourceType] = []; model.completion = { chosen.append($0) }
        model.selectedMarket = .tbc
        XCTAssertEqual(model.selectedMarket, .xyk); XCTAssertTrue(chosen.isEmpty)
        XCTAssertEqual(descendants(MarketView.self, in: screen.view).filter(\.isSelectedMarket).map(\.type), [.xyk])
    }
    func testMarketDescriptionsAndEncodingMatchTheirDisplaySelection() {
        XCTAssertEqual(LiquiditySourceType.xyk.code.first?.first, "XYKPool")
        XCTAssertEqual(LiquiditySourceType.tbc.code.first?.first, "MulticollateralBondingCurvePool")
        XCTAssertTrue(LiquiditySourceType.smart.code.isEmpty)
        for market in LiquiditySourceType.allCases { XCTAssertFalse(market.titleForLocale(Locale(identifier: "en")).isEmpty); XCTAssertFalse((market.descriptionText ?? "").isEmpty) }
    }
    private func slippageFixture() -> (SlippageToleranceViewModel, SlippageToleranceViewController, SlippageToleranceView) {
        let model = SlippageToleranceViewModel(value: .defaultValue); let screen = SlippageToleranceViewController(viewModel: model); model.view = screen
        screen.loadViewIfNeeded(); return (model, screen, descendants(SlippageToleranceView.self, in: screen.view)[0])
    }
    private func edit(_ text: String, in view: SlippageToleranceView) { view.field.textField.text = text; view.field.textField.sendActions(for: .editingChanged) }
    func testSlippageScreenStartsWithExactDefaultAndReadyButton() {
        let (_, _, field) = slippageFixture(); XCTAssertEqual(field.field.textField.text, "0.5%"); XCTAssertTrue(field.slipageButton.isEnabled)
        XCTAssertEqual(field.field.textField.keyboardType, .decimalPad); XCTAssertEqual(field.field.textField.autocorrectionType, .no)
    }
    func testSlippageFieldPublishesExactDecimalAndCommaInput() {
        let (model, _, field) = slippageFixture()
        edit("0.01", in: field); XCTAssertEqual(model.currentValue?.basisPoints, 1)
        edit("1,25", in: field); XCTAssertEqual(model.currentValue?.basisPoints, 125); XCTAssertTrue(field.slipageButton.isEnabled)
    }
    func testSlippageClearingOrInvalidPrecisionRevokesReadiness() {
        let (model, _, field) = slippageFixture()
        for input in ["", "0", "-1", "0.001", "bad"] { edit(input, in: field); XCTAssertNil(model.currentValue, input); XCTAssertFalse(field.slipageButton.isEnabled, input) }
    }
    func testSlippageCanRecoverAfterInvalidEntryAndSubmitExactlyOnce() {
        let (model, _, field) = slippageFixture(); var submitted: [UInt16] = []; model.completion = { submitted.append($0.basisPoints) }
        edit("bad", in: field); model.doneButtonTapped(); XCTAssertTrue(submitted.isEmpty)
        edit("1.25", in: field); field.slipageButton.sendActions(for: .touchUpInside); XCTAssertEqual(submitted, [125])
    }
    func testSlippageValidOverMaximumValueClampsToSupportedMaximum() {
        let (model, _, field) = slippageFixture(); edit("11", in: field)
        XCTAssertEqual(model.currentValue?.basisPoints, 1000); XCTAssertEqual(field.field.textField.text, "10%")
    }
    func testSlippageMalformedLargeInputDoesNotBecomeAValidMaximum() {
        let (model, _, field) = slippageFixture()
        for input in ["11garbage", "11.0junk", "1e2", "11\n"] { edit(input, in: field); XCTAssertNil(model.currentValue, input); XCTAssertFalse(field.slipageButton.isEnabled, input) }
    }
    func testSlippageContextRejectsTrailingLineBreaks() {
        for text in ["0.5\n", "1\r\n", "10\n"] { XCTAssertNil(PolkaswapSlippage(contextValue: text), text) }
    }
    func testSlippageReplacingWholeFieldAllowsAValidLowerPrecisionValue() {
        let (_, _, field) = slippageFixture(); field.field.textField.text = "0.12%"
        XCTAssertTrue(field.textField(field.field.textField, shouldChangeCharactersIn: NSRange(location: 0, length: 5), replacementString: "1.5"))
    }
    func testSlippageDelegateRejectsMixedSeparatorsAndLetters() {
        let (_, _, field) = slippageFixture(); field.field.textField.text = "1.2%"
        XCTAssertFalse(field.textField(field.field.textField, shouldChangeCharactersIn: NSRange(location: 3, length: 0), replacementString: ","))
        XCTAssertFalse(field.textField(field.field.textField, shouldChangeCharactersIn: NSRange(location: 3, length: 0), replacementString: "x"))
    }
    func testSlippageAccessoryContainsExpectedExactChoices() throws {
        let (model, _, field) = slippageFixture(); let accessory = try XCTUnwrap(field.field.textField.inputAccessoryView as? InputAccessoryView)
        XCTAssertEqual(accessory.variants.map(\.value), [Decimal(string: "0.1")!, Decimal(string: "0.5")!, 1])
        try XCTUnwrap(accessory.stackView.arrangedSubviews.compactMap { $0 as? SoramitsuButton }.last).sendActions(for: .touchUpInside)
        XCTAssertEqual(model.currentValue?.basisPoints, 100); XCTAssertEqual(field.field.textField.text, "1%")
    }
    func testAccessoryReplacesOldButtonsAndCallbacks() throws {
        let view = InputAccessoryView(frame: .zero); let source = PreferenceAccessorySpy(); view.delegate = source
        view.variants = [.init(displayValue: "Old", value: 1), .init(displayValue: "Old2", value: 2)]
        view.variants = [.init(displayValue: "New", value: 3)]
        XCTAssertEqual(view.stackView.arrangedSubviews.count, 1); try XCTUnwrap(view.stackView.arrangedSubviews.first as? SoramitsuButton).sendActions(for: .touchUpInside)
        XCTAssertEqual(source.values, [3]); view.variants = []; XCTAssertTrue(view.stackView.arrangedSubviews.isEmpty)
    }
    func testInvalidAccessoryValueDoesNotOverwriteReviewedSlippage() {
        let (model, _, field) = slippageFixture(); model.didSelect(variant: -1); model.didSelect(variant: 11)
        XCTAssertEqual(model.currentValue, .defaultValue); XCTAssertEqual(field.field.textField.text, "0.5%")
    }
}
private final class PreferenceAccessorySpy: InputAccessoryViewDelegate { var values: [Decimal] = []; func didSelect(variant: Decimal) { values.append(variant) } }
