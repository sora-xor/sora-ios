// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraFoundation
@testable import SoraPassport
import SoraUIKit
import UIKit
import XCTest

/// Opt-in native screenshots of the portfolio (`SORA_CAPTURE_PORTFOLIO=1`). Production cells,
/// sheets, screens and the real tab bar render the debug sample portfolio; a file handshake lets
/// `xcrun simctl io screenshot` capture each settled screen (the driver writes `capture-ack.txt`).
@MainActor
final class PortfolioCaptureTests: XCTestCase {
    private var output: URL!
    private var window: UIWindow?
    private var shots: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        guard ProcessInfo.processInfo.environment["SORA_CAPTURE_PORTFOLIO"] == "1" else {
            throw XCTSkip("Opt-in portfolio screenshots")
        }
        output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PortfolioCapture", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    }

    func testCapturePortfolioScreens() async throws {
        let previousTheme = SoramitsuUI.shared.themeMode
        let previousLanguage = LocalizationManager.shared.selectedLocalization
        let previousWindow = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0.isKeyWindow }
        defer {
            PortfolioDebugOptions.sampleOverride = nil
            PortfolioDebugOptions.tiltOverride = nil
            SoramitsuUI.shared.themeMode = previousTheme
            LocalizationManager.shared.selectedLocalization = previousLanguage
            window?.isHidden = true
            window?.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
        }
        LocalizationManager.shared.selectedLocalization = "en"
        PortfolioFormat.locale = Locale(identifier: "en_US")
        let defaults = UserDefaults(suiteName: "portfolio.capture")!
        defaults.removePersistentDomain(forName: "portfolio.capture")

        let themes = ProcessInfo.processInfo.environment["SORA_CAPTURE_THEMES"]?.split(separator: ",").map(String.init)
            ?? ["dark", "light"]
        for themeName in themes {
            // The same number for a screen in both themes: 01-…-dark and 01-…-light.
            var index = 1
            let dark = themeName == "dark"
            SoramitsuUI.shared.themeMode = .manual(dark ? .dark : .light)
            AppearanceFactory.applyGlobalAppearance()
            let suffix = dark ? "dark" : "light"
            func name(_ base: String) -> String {
                defer { index += 1 }
                return String(format: "%02d-%@-%@", index, base, suffix)
            }

            // Hero and list, Tokens lens.
            var host = try await makeHost(variant: .full, defaults: defaults, dark: dark)
            try await capture(name("portfolio-tokens"))
            // An expanded token row (XOR lives on three networks in three wallets).
            host.home.viewModel.toggleRow(PortfolioSampleData.xor.id)
            try await settle()
            host.scrollList()
            try await capture(name("token-expanded"))
            host.home.viewModel.toggleRow(PortfolioSampleData.xor.id)
            host.scrollToTop()
            // Networks and Wallets lenses.
            host.home.viewModel.selectLens(.networks)
            host.home.viewModel.toggleRow(PortfolioNetwork.sora2.rawValue)
            try await settle()
            host.scrollList()
            try await capture(name("networks-lens"))
            host.scrollToTop()
            host.home.viewModel.selectLens(.wallets)
            // The first row, so its "Open Savings alone" link is on screen.
            host.home.viewModel.toggleRow(PortfolioSampleData.savingsId)
            try await settle()
            host.scrollList()
            try await capture(name("wallets-lens"))
            host.scrollToTop()
            host.home.viewModel.selectLens(.tokens)
            try await settle()
            // XOR on other networks, under the portfolio list.
            host.homeController.scroll(toShow: host.home.otherNetworksItem)
            try await capture(name("other-networks"))
            host.scrollToTop()
            // Wallets sheet.
            host.coordinator.showWallets()
            try await capture(name("wallets-sheet"), delay: 1.0)
            await host.dismissPresented()
            // Where it lives for XOR (the selected wallet's SORA2 holding).
            let xorMain = "\(PortfolioSampleData.mainId)|sora2|\(PortfolioSampleData.xor.id)"
            host.coordinator.showDetail(tokenId: PortfolioSampleData.xor.id, holdingId: xorMain)
            try await capture(name("where-it-lives-xor"), delay: 1.2)
            // The selected holding's panel: breakdown, route card, actions and the Polkaswap card.
            host.scrollDetail(to: 470)
            try await capture(name("where-it-lives-xor-panel"))
            host.scrollDetail(to: .greatestFiniteMagnitude)
            try await capture(name("where-it-lives-xor-polkaswap"))
            host.popToRoot()
            try await settle()
            // The orbit with an injected deflection (screenshots only).
            PortfolioDebugOptions.tiltOverride = (0.9, -0.5)
            host.coordinator.showDetail(tokenId: PortfolioSampleData.xor.id, holdingId: xorMain)
            try await capture(name("parallax-orbit-moved"), delay: 1.2)
            PortfolioDebugOptions.tiltOverride = nil
            host.popToRoot()
            try await settle()
            // Move and Swap sheets.
            host.coordinator.showMove(holdingId: xorMain)
            try await capture(name("move-sheet"), delay: 1.0)
            await host.dismissPresented()
            host.coordinator.showSwap(holdingId: xorMain)
            try await capture(name("swap-sheet"), delay: 1.0)
            await host.dismissPresented()
            // The Polkaswap swap screen after the hand-off (XOR to VAL, both prefilled).
            host.coordinator.perform(.swap(from: PortfolioSampleData.xor.id, to: PortfolioSampleData.val.id),
                                     walletId: PortfolioSampleData.mainId, confirmed: true)
            try await capture(name("swap-handoff"), delay: 1.4)
            await host.dismissPresented()
            // The parallax moved state (an injected deflection; screenshots only).
            PortfolioDebugOptions.tiltOverride = (0.9, -0.5)
            host = try await makeHost(variant: .full, defaults: defaults, dark: dark)
            try await capture(name("parallax-moved"))
            PortfolioDebugOptions.tiltOverride = nil
            // Empty wallet.
            host = try await makeHost(variant: .empty, defaults: defaults, dark: dark)
            try await capture(name("empty"))
            // The first read still running: no empty state and no OFFLINE yet.
            host = try await makeHost(variant: .loading, defaults: defaults, dark: dark)
            try await capture(name("first-read"))
            // Freshness: one wallet's SORA2 read failed (PARTIAL, and the chip's sheet), then nothing read.
            host = try await makeHost(variant: .partial, defaults: defaults, dark: dark)
            try await capture(name("freshness-partial"))
            host.coordinator.showFreshness(host.home.viewModel.snapshot.wallets.flatMap(\.freshness.unreachable))
            try await capture(name("freshness-partial-sheet"), delay: 1.0)
            await host.dismissPresented()
            host = try await makeHost(variant: .offline, defaults: defaults, dark: dark)
            try await capture(name("freshness-offline"))
            // Accessibility text size: the legend stacks and the quick actions take two rows.
            host = try await makeHost(variant: .full, defaults: defaults, dark: dark,
                                      contentSize: .accessibilityExtraLarge)
            try await capture(name("large-text"))
            _ = host
        }

        let receipt: [String: Any] = [
            "screenshots": shots,
            "data": "PortfolioSampleData (debug-only sample: invented wallets, amounts and prices)",
            "host": "The app on its simulator (unit-test host): MainTabBarViewController with the production "
                + "portfolio cells, sheets and Where it lives; the Polkaswap screen is the production "
                + "PolkaswapViewController with a capture presentation (no chain connection or account here)",
            "secretsIncluded": false
        ]
        try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("capture-receipt.json"))
    }

    // MARK: Host

    private func makeHost(variant: PortfolioSampleData.Variant, defaults: UserDefaults, dark: Bool,
                          contentSize: UIContentSizeCategory? = nil) async throws -> PortfolioCaptureHost {
        window?.isHidden = true
        window?.rootViewController = nil
        let window = Self.makeWindow()
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        if let contentSize, #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = contentSize
        }
        let host = PortfolioCaptureHost(variant: variant, defaults: defaults)
        window.rootViewController = host.tabBar
        window.makeKeyAndVisible()
        self.window = window
        host.tabBar.loadViewIfNeeded()
        try await settle(1.0)
        return host
    }

    private static func makeWindow() -> UIWindow {
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            let window = UIWindow(windowScene: scene)
            window.frame = scene.coordinateSpace.bounds
            return window
        }
        return UIWindow(frame: UIScreen.main.bounds)
    }

    private func settle(_ seconds: Double = 0.6) async throws {
        window?.layoutIfNeeded()
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        window?.layoutIfNeeded()
    }

    /// Waits for the screen to settle, then asks the driver for a simulator screenshot.
    private func capture(_ name: String, delay: Double = 0.8) async throws {
        try await settle(delay)
        shots.append(name)
        let acknowledgement = output.appendingPathComponent("capture-ack.txt")
        try? FileManager.default.removeItem(at: acknowledgement)
        try Data(name.utf8).write(to: output.appendingPathComponent("capture-request.txt"), options: .atomic)
        guard ProcessInfo.processInfo.environment["SORA_CAPTURE_NATIVE"] == "1" else { return }
        for _ in 0..<200 {
            if (try? String(contentsOf: acknowledgement, encoding: .utf8)) == name { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("The simulator capture did not acknowledge \(name)")
    }
}

/// The Wallet tab as the app builds it, around the production portfolio home.
@MainActor
final class PortfolioCaptureHost {
    let tabBar = MainTabBarViewController()
    let home: PortfolioHome
    let homeController: PortfolioCaptureHomeController
    let router = PortfolioCaptureRouter()
    var coordinator: PortfolioCoordinator { home.coordinator! }

    private let presenterStub = PortfolioCaptureTabPresenter()

    init(variant: PortfolioSampleData.Variant, defaults: UserDefaults) {
        home = PortfolioHome(dataSource: PortfolioSampleDataSource(variant: variant),
                             preferences: PortfolioPreferences(defaults: defaults))
        homeController = PortfolioCaptureHomeController(home: home, variant: variant)
        tabBar.presenter = presenterStub
        let wallet = SoraNavigationController(rootViewController: homeController)
        wallet.navigationBar.isHidden = true
        wallet.tabBarItem = UITabBarItem(title: R.string.localizable.walletTitle(preferredLanguages: ["en"]),
                                         image: R.image.tabBar.wallet(), selectedImage: nil)
        func placeholder(_ title: String, _ image: UIImage?) -> UIViewController {
            let controller = UIViewController()
            controller.view.backgroundColor = .clear
            controller.tabBarItem = UITabBarItem(title: title, image: image, selectedImage: nil)
            return controller
        }
        let swap = UIViewController()
        swap.tabBarItem.isEnabled = false
        tabBar.viewControllers = [
            wallet,
            placeholder(R.string.localizable.commonExplore(preferredLanguages: ["en"]), R.image.wallet.globe()),
            swap,
            placeholder(R.string.localizable.commonActivity(preferredLanguages: ["en"]), R.image.wallet.activity()),
            placeholder(R.string.localizable.commonMore(preferredLanguages: ["en"]), R.image.wallet.more())
        ]
        home.attach(host: homeController, router: router, switcher: PortfolioCaptureSwitcher())
        router.host = homeController
    }

    /// Shows the legend chips, the lens control and the first rows.
    func scrollList() {
        homeController.scroll(to: 330)
    }

    func scrollDetail(to offset: CGFloat) {
        guard let detail = homeController.navigationController?.topViewController as? PortfolioDetailViewController,
              let scrollView = detail.view.subviews.compactMap({ $0 as? UIScrollView }).first else { return }
        scrollView.layoutIfNeeded()
        let bottom = scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height
        scrollView.setContentOffset(CGPoint(x: 0, y: max(0, min(offset, bottom))), animated: false)
        scrollView.layoutIfNeeded()
    }

    func scrollToTop() {
        homeController.scroll(to: 0)
    }

    func popToRoot() {
        homeController.navigationController?.popToRootViewController(animated: false)
    }

    func dismissPresented() async {
        guard let presented = homeController.navigationController?.presentedViewController ??
            homeController.presentedViewController else { return }
        await withCheckedContinuation { continuation in
            presented.dismiss(animated: false) { continuation.resume() }
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
}

/// Mirrors `RedesignWalletViewController` for the portfolio: a clear table over the aurora, pinned
/// to the top so the sky runs under the status bar, with two of the home's secondary cards below.
@MainActor
final class PortfolioCaptureHomeController: SoramitsuViewController {
    let home: PortfolioHome
    private let tableView = SoramitsuTableView()
    private var binding: PortfolioTableBinding?

    private let variant: PortfolioSampleData.Variant

    init(home: PortfolioHome, variant: PortfolioSampleData.Variant) {
        self.home = home
        self.variant = variant
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 65, right: 0)
        tableView.sectionHeaderTopPadding = 0
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 40)
        ])
        binding = PortfolioTableBinding(home: home, tableView: tableView, host: self)
        let friends = FriendsItem()
        let edit = EditViewItem()
        home.otherNetworksItem.rows = Self.networkRows(variant: variant)
        tableView.sora.sections = [SoramitsuTableViewSection(rows: home.items + [friends, edit])]
    }

    /// The selected wallet's XOR rows on SORA Nexus and Taira.
    private static func networkRows(variant: PortfolioSampleData.Variant) -> [NetworkAssetRow] {
        let snapshot = PortfolioSampleData.snapshot(variant, icon: PortfolioSampleDataSource.icon)
        let directory = snapshot.directory
        let main = snapshot.mainNetwork.networkId
        let icon = RemoteSerializer.shared.image(with: PortfolioSampleDataSource.icon(PortfolioSampleData.xor.id) ?? "")
        return [PortfolioNetwork.minamoto, .taira].compactMap { network in
            guard let address = snapshot.selectedWallet?.addresses[network] else { return nil }
            let amount = snapshot.holdings.first {
                $0.walletId == PortfolioSampleData.mainId && $0.network == network
            }?.amount ?? 0
            let account = NetworkAccount(walletId: PortfolioSampleData.mainId, networkId: network.networkId,
                                         derivationVersion: 1, publicKey: Data(repeating: 0x11, count: 32),
                                         address: address)
            return NetworkAssetRow(account: account,
                                   title: directory.rowLabel(for: network.networkId, main: main).map { "XOR · \($0)" } ?? "XOR",
                                   // While the first read runs there is no amount yet.
                                   amount: variant == .loading ? "" : PortfolioFormat.amount(amount, symbol: "XOR"),
                                   tag: directory.tag(for: network.networkId, main: main),
                                   icon: icon)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        binding?.safeAreaDidChange()
        home.viewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        binding?.safeAreaDidChange()
        home.viewDidAppear()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        binding?.safeAreaDidChange()
    }

    func scroll(to offset: CGFloat) {
        tableView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
        tableView.layoutIfNeeded()
    }

    /// Scrolls the card that shows `item` to the middle of the screen.
    func scroll(toShow item: SoramitsuTableViewItemProtocol) {
        tableView.layoutIfNeeded()
        guard let row = tableView.sora.sections.first?.rows.firstIndex(where: { ($0 as AnyObject) === (item as AnyObject) })
        else { return }
        tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .middle, animated: false)
        tableView.layoutIfNeeded()
    }
}

final class PortfolioCaptureTabPresenter: MainTabBarPresenterProtocol {
    func setup() {}
}

/// Records hand-offs. Swap opens the production swap screen in the container `SwapViewFactory`
/// builds, with a capture presentation: the test host has no chain connection and no account, which
/// the factory's live view model needs. The app's own hand-off goes through `SwapViewFactory`.
@MainActor
final class PortfolioCaptureRouter: PortfolioHandoffRouting {
    weak var host: UIViewController?
    private(set) var handoffs: [String] = []

    func showSend(from controller: UIViewController) {
        handoffs.append("send")
    }

    func showSora2Send(from controller: UIViewController, assetId: String?, recipient: String?,
                       amount: PortfolioAmountChoice?) {
        handoffs.append("sora2-send")
    }

    func showReceive(from controller: UIViewController) {
        handoffs.append("receive")
    }

    func showSora2Receive(from controller: UIViewController) {
        handoffs.append("sora2-receive")
    }

    func showSwap(from controller: UIViewController, fromAssetId: String, toAssetId: String) {
        handoffs.append("swap")
        let presentation = PortfolioCaptureSwapPresentation(fromAssetId: fromAssetId, toAssetId: toAssetId,
                                                            walletId: PortfolioSampleData.mainId)
        let swap = PolkaswapViewController(viewModel: presentation)
        presentation.view = swap
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let navigationController = UINavigationController(rootViewController: swap)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        containerView.add(navigationController)
        controller.present(containerView, animated: false)
    }

    func showNetwork(_ network: PortfolioNetwork, send: Bool, from controller: UIViewController) -> Bool {
        handoffs.append("network")
        return true
    }

    func showManageAssets(from controller: UIViewController) { handoffs.append("manage-assets") }

    func showManageWallets(from controller: UIViewController) {
        handoffs.append("manage")
    }
}

@MainActor
final class PortfolioCaptureSwitcher: PortfolioAccountSwitching {
    var selectedWalletId: String? { PortfolioSampleData.mainId }
    func switchTo(walletId: String, completion: @escaping (Bool) -> Void) { completion(false) }
}

/// The swap screen as `SwapViewModel` first draws it after a hand-off: both tokens prefilled, the
/// wallet's balances (here the sample's), no amount yet, Review disabled. Screenshots only.
final class PortfolioCaptureSwapPresentation: LiquidityViewModelProtocol {
    weak var view: PolkaswapViewController?
    var title: String? { nil }
    var imageName: String? { "Wallet/polkaswapLogo" }
    var firstFieldEmptyStateFullFiatText: String? { R.string.localizable.swapWantFrom(preferredLanguages: ["en"]) }
    var secondFieldEmptyStateFullFiatText: String? { R.string.localizable.swapWantTo(preferredLanguages: ["en"]) }
    var isSwap: Bool { true }
    var actionButtonImage: UIImage? { R.image.wallet.swapButton() }
    var inputedFirstAmount: Decimal = 0
    var inputedSecondAmount: Decimal = 0
    var middleButtonActionHandler: (() -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var focusedField: FocusedField = .one

    private let fromAssetId: String
    private let toAssetId: String
    private let snapshot: PortfolioSnapshot
    private let walletId: String

    init(fromAssetId: String, toAssetId: String, walletId: String) {
        self.fromAssetId = fromAssetId
        self.toAssetId = toAssetId
        self.walletId = walletId
        snapshot = PortfolioSampleData.snapshot(icon: PortfolioSampleDataSource.icon)
    }

    func viewDidLoad() {
        for (index, assetId) in [fromAssetId, toAssetId].enumerated() {
            let holding = snapshot.holdings.first {
                $0.walletId == walletId && $0.network == .sora2 && $0.token.id == assetId
            }
            let token = holding?.token ?? snapshot.holdings.first { $0.token.id == assetId }?.token
            let image = RemoteSerializer.shared.image(with: token?.icon ?? "")
            let balance = holding?.transferable ?? 0
            var text = NumberFormatter.polkaswapBalance.stringFromDecimal(balance) ?? ""
            if let price = token?.priceUSD {
                text += " ($" + (NumberFormatter.fiat.stringFromDecimal(balance * price) ?? "") + ")"
            }
            if index == 0 {
                view?.updateFirstAsset(symbol: token?.symbol ?? "", image: image)
                view?.updateFirstAsset(balance: text)
            } else {
                view?.updateSecondAsset(symbol: token?.symbol ?? "", image: image)
                view?.updateSecondAsset(balance: text)
            }
        }
        view?.update(slippageTolerance: PolkaswapSlippage.defaultValue.displayValue)
        view?.updateMiddleButton(isEnabled: true)
        view?.setupButton(isEnabled: false)
    }

    func choiсeBaseAssetButtonTapped() {}
    func choiсeTargetAssetButtonTapped() {}
    func changeSlippageTolerance() {}
    func reviewButtonTapped() {}
    func recalculate(field: FocusedField) {}
    func didSelect(variant: Decimal) {}
}
