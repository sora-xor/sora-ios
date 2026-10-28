// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import SoraFoundation
import SoraKeystore
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class SettingsScreenBehaviorTests: XCTestCase {
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
    }
    private func settings() -> (AppSettingsPresenter, SettingsCapture) {
        let presenter = AppSettingsPresenter(); presenter.localizationManager = LocalizationManager.shared
        let capture = SettingsCapture(); presenter.view = capture; presenter.reload(); return (presenter, capture)
    }
    private func rows(_ capture: SettingsCapture) -> [SoramitsuTableViewItemProtocol] { capture.model?.sections.flatMap(\.rows) ?? [] }
    func testThemeChoicesPersistAndRebuildExactlyOneSelectedChoice() throws {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        let (_, capture) = settings()
        for index in 0..<3 {
            let appearance = try XCTUnwrap(rows(capture).compactMap { $0 as? AppAppearanceItem }.first)
            XCTAssertEqual(appearance.choices.count, 3)
            appearance.onSelect(index)
            XCTAssertEqual(rows(capture).compactMap { $0 as? AppAppearanceItem }.first?.selectedIndex, index)
            switch (index, SoramitsuUI.shared.themeMode) {
            case (0, .system), (1, .manual(.dark)), (2, .manual(.light)): break
            default: XCTFail("Theme did not match selected choice")
            }
        }
    }
    func testInvalidThemeChoiceDoesNotChangePreferencesOrReload() throws {
        let (_, capture) = settings(); let deliveries = capture.deliveries
        let appearance = try XCTUnwrap(rows(capture).compactMap { $0 as? AppAppearanceItem }.first)
        appearance.onSelect(-1); appearance.onSelect(3)
        XCTAssertEqual(capture.deliveries, deliveries)
        XCTAssertEqual(rows(capture).compactMap { $0 as? AppAppearanceItem }.first?.selectedIndex, appearance.selectedIndex)
    }
    func testReduceEffectsToggleIsReflectedInTheNextModel() throws {
        let previous = FxPolicy.reduceEffects; defer { FxPolicy.reduceEffects = previous }
        let (_, capture) = settings()
        for enabled in [true, false] {
            let card = try XCTUnwrap(rows(capture).compactMap { $0 as? AppSettingsCardItem }.first { $0.title == nil })
            try XCTUnwrap(card.menuItems.first?.onSwitch)(enabled)
            XCTAssertEqual(FxPolicy.reduceEffects, enabled)
            let updated = try XCTUnwrap(rows(capture).compactMap { $0 as? AppSettingsCardItem }.first { $0.title == nil }?.menuItems.first)
            guard case let .switcher(state) = updated.rightItem else { return XCTFail("Missing effects switch") }
            XCTAssertEqual(state, enabled ? .on : .off)
        }
    }
    func testAppearanceCellForwardsTheCurrentSelection() throws {
        let cell = AppAppearanceCell(style: .default, reuseIdentifier: nil)
        var choices: [Int] = []
        let item = AppAppearanceItem(title: "APPEARANCE", choices: ["System", "Dark", "Light"], selectedIndex: 1) { choices.append($0) }
        cell.set(item: item, context: nil)
        let control = try XCTUnwrap(views(UISegmentedControl.self, in: cell).first)
        XCTAssertEqual(control.numberOfSegments, 3); XCTAssertEqual(control.selectedSegmentIndex, 1)
        control.selectedSegmentIndex = 2; control.sendActions(for: .valueChanged)
        XCTAssertEqual(choices, [2])
    }
    func testSettingsCardRebindDropsOldMenuRowsAndHandlers() throws {
        let cell = AppSettingsCardCell(style: .default, reuseIdentifier: nil)
        var old = 0; var current = 0
        let first = AppSettingsItem(title: "Old", rightItem: .switcher(state: .on), onSwitch: { _ in old += 1 })
        let second = AppSettingsItem(title: "Current", rightItem: .switcher(state: .off), onSwitch: { _ in current += 1 })
        cell.set(item: AppSettingsCardItem(title: "NETWORKS", menuItems: [first, first]), context: nil)
        cell.set(item: AppSettingsCardItem(title: nil, menuItems: [second]), context: nil)
        let switches = views(UISwitch.self, in: cell)
        XCTAssertEqual(switches.count, 1)
        switches.forEach { $0.isOn = true; $0.sendActions(for: .valueChanged) }
        XCTAssertEqual(old, 0); XCTAssertEqual(current, 1)
        XCTAssertFalse(views(UILabel.self, in: cell).contains { $0.text == "Old" || $0.text == "NETWORKS" })
    }
    func testSettingsScreenBuildsAndLanguageActionOpensTheLanguageList() throws {
        let previous = LocalizationManager.shared.selectedLocalization
        defer { LocalizationManager.shared.selectedLocalization = previous }
        LocalizationManager.shared.selectedLocalization = "en"
        let controller = AppSettingsView()
        let presenter = AppSettingsPresenter(); presenter.localizationManager = LocalizationManager.shared
        controller.presenter = presenter; presenter.view = controller
        let navigation = UINavigationController(rootViewController: controller)
        controller.loadViewIfNeeded()
        let table = try XCTUnwrap(views(SoramitsuTableView.self, in: controller.view).first)
        XCTAssertGreaterThanOrEqual(table.sora.sections.count, 2)
        let language = try XCTUnwrap(table.sora.sections.first?.rows.first as? AppSettingsItem)
        language.itemActionTap(with: nil)
        let languages = try XCTUnwrap(navigation.topViewController as? LanguageView)
        languages.loadViewIfNeeded()
        let languageTable = try XCTUnwrap(views(SoramitsuTableView.self, in: languages.view).first)
        let entries = languageTable.sora.sections.flatMap(\.rows).compactMap { $0 as? LanguageItem }
        XCTAssertEqual(Set(entries.map(\.code)), Set(LocalizationManager.shared.availableLocalizations))
        XCTAssertEqual(entries.filter(\.selected).map(\.code), ["en"])
        XCTAssertFalse(entries.contains { $0.title.isEmpty || $0.subtitle.isEmpty })
        XCTAssertTrue(languages.hidesBottomBarWhenPushed)
    }
    func testHistoricalLanguageNamesAreExplicitAndNative() throws {
        let previous = LocalizationManager.shared.selectedLocalization
        defer { LocalizationManager.shared.selectedLocalization = previous }
        LocalizationManager.shared.selectedLocalization = "en"
        let view = LanguageViewFactory.createView(); view.controller.loadViewIfNeeded()
        let table = try XCTUnwrap(views(SoramitsuTableView.self, in: view.controller.view).first)
        let items = table.sora.sections.flatMap(\.rows).compactMap { $0 as? LanguageItem }
        let akkadian = try XCTUnwrap(items.first { $0.code == "akk" })
        XCTAssertEqual(akkadian.title, "Old Akkadian"); XCTAssertEqual(akkadian.subtitle, "lišānum akkadītum labīrtum")
        let egyptian = try XCTUnwrap(items.first { $0.code == "egy-Egyp" })
        XCTAssertEqual(egyptian.title, "Middle Egyptian (Hieroglyphic)")
        XCTAssertTrue(egyptian.subtitle.contains("𓌃"))
        let cell = LanguageCell(style: .default, reuseIdentifier: nil)
        cell.set(item: akkadian, context: nil)
        XCTAssertTrue(views(UILabel.self, in: cell).contains { $0.text == akkadian.subtitle })
        cell.set(item: egyptian, context: nil)
        XCTAssertFalse(views(UILabel.self, in: cell).contains { $0.text == akkadian.subtitle })
    }
    func testLanguageLayoutFollowsRightToLeftAndReturnsToLeftToRight() {
        let previous = LocalizationManager.shared.selectedLocalization
        defer { LocalizationManager.shared.selectedLocalization = previous }
        let controller = LanguageView(); let navigation = UINavigationController(rootViewController: controller)
        controller.loadViewIfNeeded()
        LocalizationManager.shared.selectedLocalization = "ar"; controller.updateLayout()
        XCTAssertEqual(navigation.navigationBar.semanticContentAttribute, .forceRightToLeft)
        LocalizationManager.shared.selectedLocalization = "en"; controller.updateLayout()
        XCTAssertEqual(navigation.navigationBar.semanticContentAttribute, .forceLeftToRight)
    }
}
private final class SettingsCapture: UIViewController, AppSettingsViewProtocol {
    var controller: UIViewController { self }
    var presenter: AppSettingsPresenterProtocol?
    var model: AppSettingsModel?
    var deliveries = 0
    func update(model: AppSettingsModel) { self.model = model; deliveries += 1 }
}
