// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ObjectiveC
import SoraUIKit
import SoraFoundation

final class MainTabBarViewController: UITabBarController {
	var presenter: MainTabBarPresenterProtocol!
    var middleButtonHadler: (() -> Void)?
    private var viewAppeared: Bool = false
    /// The custom bar, kept even when it could not be swapped in (its swap
    /// disc then lives on the system bar and still follows theme changes).
    private var customTabBar: TabBar?
    /// Liquid Glass systems only: the classic bar drawn over the system one.
    private(set) var classicCover: ClassicTabBarCover?

    override var selectedIndex: Int {
        didSet { updateClassicCover() }
    }

    override var selectedViewController: UIViewController? {
        didSet { updateClassicCover() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self

        let tabBar = TabBar(frame: tabBar.frame)
        tabBar.middleButton.sora.backgroundColor = .custom(uiColor: .white)
        tabBar.middleButton.sora.image = R.image.wallet.polkaswap()
        tabBar.middleButton.sora.shadow = .default
        tabBar.middleButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.middleButtonHadler?()
        }
        tabBar.coverButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.middleButtonHadler?()
        }
        tabBar.middleButtonTitleLabel.sora.text = R.string.localizable.tabbarPolkaswapTitle(preferredLanguages: .currentLocale)
        installCustomTabBar(tabBar)
        installClassicCover()
        installSwapDiscHitArea(for: tabBar.middleButton)

        installAurora()
        SoramitsuUI.updates.addObserver(self)
        configureTabBar()
    }

    /// Swaps in the notched tab bar with the swap disc. `UITabBarController`
    /// has no public setter, so this uses key-value coding on its `_tabBar`
    /// storage, as every release since 2.0 has. Verified on the iOS 18.4
    /// (notched bar), 26.5 and 27.0 (Liquid Glass) simulators, and checked
    /// by `SoraNeonDesignTests.testTabBarChromeAndSwapDisc` on whatever
    /// system the tests run on. If a future iOS renames that storage, KVC
    /// would raise an Objective-C exception, so the swap is skipped and the
    /// whole disc (button, tap cover and label) moves onto the system tab
    /// bar.
    private func installCustomTabBar(_ custom: TabBar) {
        customTabBar = custom
        if class_getInstanceVariable(UITabBarController.self, "_tabBar") != nil {
            setValue(custom, forKey: "tabBar")
        }
        guard tabBar !== custom else { return }
        custom.installSwapDisc(in: tabBar)
    }

    /// iOS 27 ignores the app's request for the pre-26 bars, so where the
    /// system draws a Liquid Glass bar the classic one is drawn over it. The
    /// system bar still lays out the tabs, insets their content and hides
    /// with pushed screens; the cover is its subview, so it moves along.
    private func installClassicCover() {
        guard let custom = customTabBar, tabBar === custom, !custom.drawsLegacyChrome else { return }
        let cover = ClassicTabBarCover(frame: custom.bounds)
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cover.onSelect = { [weak self] index in self?.selectTab(at: index) }
        custom.addSubview(cover)
        // The disc draws above the cover's raised layer too.
        [custom.coverButton, custom.middleButton, custom.middleButtonTitleLabel].forEach {
            $0.layer.zPosition = cover.layer.zPosition + 1
        }
        classicCover = cover
        updateClassicCover()
    }

    /// What a tap on a system tab does: ask the delegate, select, and pop a
    /// selected tab back to its root.
    func selectTab(at index: Int) {
        guard let controllers = viewControllers, controllers.indices.contains(index),
              controllers[index].tabBarItem.isEnabled else { return }
        let controller = controllers[index]
        guard delegate?.tabBarController?(self, shouldSelect: controller) ?? true else { return }
        if index == selectedIndex {
            (controller as? UINavigationController)?.popToRootViewController(animated: true)
            return
        }
        selectedIndex = index
        delegate?.tabBarController?(self, didSelect: controller)
    }

    /// Keeps the cover above whatever the system bar adds during layout, and
    /// the Polkaswap disc above the cover.
    private func updateClassicCover() {
        guard let cover = classicCover, let custom = customTabBar else { return }
        cover.update(items: tabBar.items ?? [], selectedIndex: selectedIndex)
        custom.bringSubviewToFront(cover)
        [custom.coverButton, custom.middleButton, custom.middleButtonTitleLabel].forEach {
            custom.bringSubviewToFront($0)
        }
    }

    /// The top of the swap disc rises above the bar. On iOS 26+ the system
    /// keeps the bar in a container that covers only the bar, so touches there
    /// never reached it and went to the tab behind (on the Wallet tab: the
    /// Backup or Edit view card). This clear view above the tab content claims
    /// the visible disc for its button.
    private func installSwapDiscHitArea(for disc: UIView) {
        let hitArea = SwapDiscHitArea(frame: view.bounds)
        hitArea.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hitArea.disc = disc
        view.addSubview(hitArea)
    }

    /// The page behind every tab (tab roots are clear). With the classic
    /// tokens it is the plain page colour.
    private func installAurora() {
        let aurora = AuroraView(style: .standard)
        aurora.frame = view.bounds
        aurora.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(aurora, at: 0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            viewAppeared = true
            presenter.setup()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let cover = classicCover, let custom = customTabBar {
            tabBar.layoutIfNeeded()
            updateClassicCover()
            var elements: [UIView] = cover.itemControls
            if elements.count == 5 {
                custom.middleButton.isAccessibilityElement = true
                custom.middleButton.accessibilityLabel = custom.middleButtonTitleLabel.sora.text
                custom.middleButton.accessibilityTraits = .button
                elements[2] = custom.middleButton
            }
            custom.coverButton.isAccessibilityElement = false
            custom.middleButtonTitleLabel.isAccessibilityElement = false
            tabBar.accessibilityElements = elements
            return
        }
        guard let custom = customTabBar, let items = tabBar.items else { return }
        let nativeButtons = tabBar.subviews.compactMap { $0 as? UIControl }
            .filter { $0 !== custom.coverButton && $0 !== custom.middleButton }
            .sorted { $0.frame.minX < $1.frame.minX }
        guard nativeButtons.count == items.count, items.count == 5 else { return }
        var elements: [UIView] = []
        for (index, button) in nativeButtons.enumerated() {
            let accessibleButton: UIControl = index == 2 ? custom.middleButton : button
            accessibleButton.isAccessibilityElement = true
            accessibleButton.accessibilityLabel = index == 2
                ? custom.middleButtonTitleLabel.sora.text : items[index].title
            accessibleButton.accessibilityTraits = index == selectedIndex ? [.button, .selected] : .button
            elements.append(accessibleButton)
        }
        custom.coverButton.isAccessibilityElement = false
        custom.middleButtonTitleLabel.isAccessibilityElement = false
        tabBar.accessibilityElements = elements
    }

    /// The classic bar: Bold labels, the selected tab in SORA red.
    private func configureTabBar() {
        let palette = SoramitsuUI.shared.theme.palette
        let appearance = NeonChrome.tabBarAppearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        let normalAttributes = [NSAttributedString.Key.foregroundColor: palette.color(.fgSecondary),
                                NSAttributedString.Key.font: FontType.textBoldXS.font]
        let selectedAttributes = [NSAttributedString.Key.foregroundColor: palette.color(.accentPrimary),
                                  NSAttributedString.Key.font: FontType.textBoldXS.font]

        tabBar.tintColor = palette.color(.accentPrimary)
        tabBar.unselectedItemTintColor = palette.color(.fgSecondary)
        tabBar.items?.forEach {
            $0.setTitleTextAttributes(normalAttributes, for: .normal)
            $0.setTitleTextAttributes(selectedAttributes, for: .selected)
        }
    }
}

/// The classic SORA tab bar drawn over a Liquid Glass system bar: the
/// notched white chrome and the tabs in Bold labels, the selected one in SORA
/// red. The centre of five is left to the Polkaswap disc.
final class ClassicTabBarCover: UIView {
    var onSelect: ((Int) -> Void)?
    private(set) var itemControls: [ClassicTabItemControl] = []
    private var items: [UITabBarItem] = []
    private let chrome = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Drawn above anything the system bar adds after it.
        layer.zPosition = 100
        chrome.lineWidth = 0
        layer.addSublayer(chrome)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(items: [UITabBarItem], selectedIndex: Int) {
        if items.map(ObjectIdentifier.init) != self.items.map(ObjectIdentifier.init) {
            rebuild(items)
        }
        for (index, control) in itemControls.enumerated() {
            control.isSelected = index == selectedIndex
        }
        chrome.fillColor = SoramitsuUI.shared.theme.palette.color(.bgSurface).cgColor
        setNeedsLayout()
    }

    private func rebuild(_ items: [UITabBarItem]) {
        itemControls.forEach { $0.removeFromSuperview() }
        self.items = items
        itemControls = items.enumerated().map { index, item in
            let control = ClassicTabItemControl(item: item)
            control.isHidden = items.count == 5 && index == 2
            control.addAction(UIAction { [weak self] _ in self?.onSelect?(index) }, for: .touchUpInside)
            addSubview(control)
            return control
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        chrome.frame = bounds
        chrome.path = Self.notchedPath(in: bounds)
        CATransaction.commit()
        guard !itemControls.isEmpty else { return }
        let width = bounds.width / CGFloat(itemControls.count)
        let rightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
        for (index, control) in itemControls.enumerated() {
            let slot = rightToLeft ? itemControls.count - 1 - index : index
            control.frame = CGRect(x: CGFloat(slot) * width, y: 0, width: width, height: 49)
        }
    }

    /// The classic bar's outline: a trough under the Polkaswap disc.
    static func notchedPath(in bounds: CGRect) -> CGPath {
        let depth: CGFloat = 32
        let centre = bounds.midX
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.minX, y: 0))
        path.addLine(to: CGPoint(x: centre - depth, y: 0))
        path.addCurve(to: CGPoint(x: centre, y: depth),
                      controlPoint1: CGPoint(x: centre - depth, y: 0),
                      controlPoint2: CGPoint(x: centre - depth, y: depth))
        path.addCurve(to: CGPoint(x: centre + depth, y: 0),
                      controlPoint1: CGPoint(x: centre + depth, y: depth),
                      controlPoint2: CGPoint(x: centre + depth, y: 0))
        path.addLine(to: CGPoint(x: bounds.maxX, y: 0))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.close()
        return path.cgPath
    }
}

/// One tab of `ClassicTabBarCover`: the item's icon over its title.
final class ClassicTabItemControl: UIControl {
    let item: UITabBarItem
    private let icon = UIImageView()
    private let title = UILabel()

    init(item: UITabBarItem) {
        self.item = item
        super.init(frame: .zero)
        icon.contentMode = .center
        icon.isUserInteractionEnabled = false
        title.font = FontType.textBoldXS.font
        title.textAlignment = .center
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.7
        title.text = item.title
        title.isUserInteractionEnabled = false
        addSubview(icon)
        addSubview(title)
        isAccessibilityElement = true
        accessibilityLabel = item.title
        apply()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet { apply() }
    }

    private func apply() {
        let palette = SoramitsuUI.shared.theme.palette
        let color = palette.color(isSelected ? .accentPrimary : .fgSecondary)
        icon.image = ((isSelected ? item.selectedImage : nil) ?? item.image)?.withRenderingMode(.alwaysTemplate)
        icon.tintColor = color
        title.textColor = color
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        icon.frame = CGRect(x: 0, y: 4, width: bounds.width, height: 30)
        title.frame = CGRect(x: 2, y: 34, width: bounds.width - 4, height: 14)
    }
}

/// Claims touches on the swap disc wherever its bar is hosted, and nothing
/// else: a point counts only inside the disc's circle while the disc is fully
/// on screen and neither it nor any view above it in the hierarchy is hidden,
/// transparent or disabled, so a bar hidden for a pushed screen claims none.
final class SwapDiscHitArea: UIView {
    weak var disc: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let disc, Self.isShown(disc, in: window) else { return false }
        let circle = disc.convert(disc.bounds, to: self)
        let radius = min(circle.width, circle.height) / 2
        return hypot(point.x - circle.midX, point.y - circle.midY) <= radius
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        self.point(inside: point, with: event) ? disc : nil
    }

    private static func isShown(_ view: UIView, in window: UIWindow?) -> Bool {
        guard let window, view.window === window else { return false }
        var current: UIView? = view
        while let ancestor = current, ancestor !== window {
            guard !ancestor.isHidden, ancestor.alpha > 0.01, ancestor.isUserInteractionEnabled else { return false }
            current = ancestor.superview
        }
        return window.bounds.contains(view.convert(view.bounds, to: window))
    }
}

extension MainTabBarViewController: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        configureTabBar()
        AppearanceFactory.applyGlobalAppearance()
        AppearanceFactory.restyleVisibleNavigationBars()
    }
}

extension MainTabBarViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        if let scrollableController = viewController as? ScrollsToTop {
            scrollableController.scrollToTop()
        }

        return true
    }
}

extension MainTabBarViewController: MainTabBarViewProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int) {
        guard var newViewControllers = viewControllers else {
            return
        }

        newViewControllers[index] = newView

        self.setViewControllers(newViewControllers, animated: false)
    }
}

extension MainTabBarViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        let languages = localizationManager?.preferredLocalizations
        customTabBar?.middleButtonTitleLabel.sora.text = R.string.localizable.tabbarPolkaswapTitle(preferredLanguages: languages)
    }
}
