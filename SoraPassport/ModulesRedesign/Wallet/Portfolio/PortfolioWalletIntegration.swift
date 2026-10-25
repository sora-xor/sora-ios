// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraKeystore
import SoraUIKit
import UIKit

/// The portfolio on the Wallet tab's home: its view model, coordinator and table items.
@MainActor
final class PortfolioHome {
    let viewModel: PortfolioViewModel
    let heroItem = PortfolioHeroItem()
    let noticeItem = PortfolioNoticeItem()
    let lensItem = PortfolioLensItem()
    let listItem = PortfolioListItem()
    let otherNetworksItem = PortfolioOtherNetworksItem()
    private(set) var coordinator: PortfolioCoordinator?
    private let dataSource: PortfolioDataSource

    /// The top of the Wallet tab, above its other cards: the hero, the selected account's key
    /// warning while it cannot sign, the lens and list, then XOR on other networks.
    var items: [SoramitsuTableViewItemProtocol] {
        let notice: [SoramitsuTableViewItemProtocol] = noticeItem.isShown ? [noticeItem] : []
        return [heroItem] + notice + [lensItem, listItem, otherNetworksItem]
    }

    init(dataSource: PortfolioDataSource, preferences: PortfolioPreferences = PortfolioPreferences()) {
        self.dataSource = dataSource
        viewModel = PortfolioViewModel(dataSource: dataSource, preferences: preferences)
        PortfolioFormat.locale = LocalizationManager.shared.isArabic ? Locale(identifier: "en_US")
            : LocalizationManager.shared.selectedLocale
        viewModel.onRender = { [weak self] render in self?.apply(render) }
        bindItems()
    }

    /// The data source the build uses: the debug sample when asked for (never in App Store builds),
    /// otherwise every wallet read by address.
    static func makeDataSource(assetManager: AssetManagerProtocol) -> PortfolioDataSource {
        #if !F_RELEASE
        if let variant = PortfolioDebugOptions.sampleVariant {
            return PortfolioSampleDataSource(variant: variant)
        }
        #endif
        return LivePortfolioDataSource(assetManager: assetManager)
    }

    func attach(host: UIViewController, router: PortfolioHandoffRouting, switcher: PortfolioAccountSwitching) {
        let coordinator = PortfolioCoordinator(viewModel: viewModel, router: router, switcher: switcher) { [weak self] id in
            self?.dataSource.asset(id)
        }
        coordinator.host = host
        self.coordinator = coordinator
    }

    private func bindItems() {
        heroItem.onScope = { [weak self] in self?.viewModel.tapScope() }
        heroItem.onChip = { [weak self] in self?.viewModel.tapChip() }
        heroItem.onCaption = { [weak self] in self?.viewModel.tapCaption() }
        heroItem.onGroup = { [weak self] key in self?.viewModel.tapGroup(key) }
        heroItem.onQuickAction = { [weak self] action in self?.viewModel.quickAction(action) }
        lensItem.onSelect = { [weak self] lens in self?.viewModel.selectLens(lens) }
        listItem.onRow = { [weak self] row in self?.viewModel.openRow(row) }
        listItem.onChild = { [weak self] child in self?.viewModel.openChild(child) }
        listItem.onLink = { [weak self] row in
            switch row.kind {
            case .wallet:
                self?.viewModel.openWalletAlone(row.key)
            case .network:
                if let network = PortfolioNetwork(rawValue: row.key) { self?.coordinator?.openNetwork(network) }
            case .token:
                break
            }
        }
        listItem.onRowAction = { [weak self] row, action in
            guard let self else { return }
            let holdings = PortfolioAggregator.holdings(ofToken: row.key, in: self.viewModel.snapshot,
                                                        scope: self.viewModel.state.scope)
            switch action {
            case .none:
                self.coordinator?.showDetail(tokenId: row.key, holdingId: holdings.first?.id)
            case .move?:
                if let holding = holdings.first(where: { $0.transferable > 0 }) {
                    self.coordinator?.showMove(holdingId: holding.id)
                }
            case .swap?:
                if let holding = holdings.first(where: { $0.network == .sora2 }) ?? holdings.first {
                    self.coordinator?.showSwap(holdingId: holding.id)
                }
            case .send?, .receive?:
                break
            }
        }
    }

    private func apply(_ render: PortfolioRender) {
        heroItem.model = render.hero
        lensItem.lenses = render.list.lenses
        lensItem.selected = render.list.lens
        listItem.model = render.list
        coordinator?.renderDidChange()
    }

    // MARK: Lifecycle

    func viewWillAppear() {
        // Keys may have been restored or removed while the tab was away.
        noticeItem.refreshCapability()
        viewModel.viewWillAppear()
    }

    func viewDidAppear() {
        heroItem.isSkyVisible = true
        coordinator?.consumePendingHandoff()
    }

    func viewDidDisappear() {
        heroItem.isSkyVisible = false
        viewModel.viewDidDisappear()
    }
}

/// The table-side glue of the portfolio home, shared by the Wallet tab and its capture host:
/// the sky runs under the status bar, the parallax gate follows scrolling, rows settle heights, and
/// once the sky has scrolled away the status bar gets the app's chrome material behind it.
@MainActor
final class PortfolioTableBinding: NSObject, UIScrollViewDelegate {
    private let home: PortfolioHome
    private weak var tableView: SoramitsuTableView?
    private weak var host: UIViewController?
    private let backdrop = PortfolioStatusBackdrop()
    private var backdropHeight: NSLayoutConstraint?

    init(home: PortfolioHome, tableView: SoramitsuTableView, host: UIViewController) {
        self.home = home
        self.tableView = tableView
        self.host = host
        super.init()
        tableView.scrollViewDelegate = self
        home.listItem.onHeightChange = { [weak tableView] in
            UIView.performWithoutAnimation {
                tableView?.beginUpdates()
                tableView?.endUpdates()
            }
        }
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(backdrop)
        let height = backdrop.heightAnchor.constraint(equalToConstant: 0)
        backdropHeight = height
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: host.view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            height
        ])
    }

    /// Call from `viewWillAppear`, `viewDidAppear` and `viewSafeAreaInsetsDidChange`. The sky starts
    /// under the status bar: the window's top inset, which a navigation bar (hidden or not) never adds to.
    func safeAreaDidChange() {
        guard let host, let window = host.view.window else { return }
        let top = window.safeAreaInsets.top
        backdropHeight?.constant = top
        guard top != home.heroItem.topInset else { return }
        home.heroItem.topInset = top
        UIView.performWithoutAnimation {
            tableView?.beginUpdates()
            tableView?.endUpdates()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        let skyBottom = home.heroItem.topInset + PortfolioTheme.Sky.height
        home.heroItem.isSkyVisible = host?.view.window != nil && offset < skyBottom - 40
        // The card reaches the status bar once the sky (minus the card's overlap) has scrolled by.
        backdrop.setShown(offset > PortfolioTheme.Sky.height - PortfolioTheme.Sky.cardOverlap, animated: true)
    }
}

/// The chrome material behind the status bar while the list scrolls under it. It fades the material
/// in and out (never the effect view's alpha) and lets touches through to the status bar.
final class PortfolioStatusBackdrop: UIView {
    private var background: UIView?
    private let hairline = UIView()
    private(set) var isShown = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        hairline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hairline)
        NSLayoutConstraint.activate([
            hairline.leadingAnchor.constraint(equalTo: leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: trailingAnchor),
            hairline.bottomAnchor.constraint(equalTo: bottomAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
        rebuild()
        SoramitsuUI.updates.addObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setShown(_ shown: Bool, animated: Bool) {
        guard shown != isShown else { return }
        isShown = shown
        // Reduce Motion keeps fades; this is one.
        UIView.animate(withDuration: animated ? NeonMotion.fast : 0, delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.applyVisibility()
        }
    }

    private func rebuild() {
        background?.removeFromSuperview()
        let view = NeonChrome.makeBackgroundView()
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(view, at: 0)
        background = view
        hairline.backgroundColor = PortfolioTheme.hairline
        applyVisibility()
    }

    private func applyVisibility() {
        if let effectView = background as? UIVisualEffectView {
            effectView.effect = isShown ? NeonChrome.effect(tokens: PortfolioTheme.tokens) : nil
            effectView.contentView.subviews.forEach { $0.alpha = isShown ? 1 : 0 }
        } else {
            background?.alpha = isShown ? 1 : 0
        }
        hairline.alpha = isShown ? 1 : 0
    }
}

extension PortfolioStatusBackdrop: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) || options.contains(.effects) { rebuild() }
    }
}

/// Switches the selected wallet the way the account picker does (`ChangeAccountPresenter`):
/// a durable selection, then `SelectedAccountChanged`, after which the tab bar rebuilds every
/// account-bound screen. Nothing else in account storage is written.
@MainActor
final class PortfolioAccountSwitcher: PortfolioAccountSwitching {
    private let repository: AnyDataProviderRepository<AccountItem>

    init(repository: AnyDataProviderRepository<AccountItem> = AnyDataProviderRepository(
        UserDataStorageFacade.shared.createRepository(filter: nil, sortDescriptors: [],
                                                      mapper: AnyCoreDataMapper(AccountItemMapper())))) {
        self.repository = repository
    }

    var selectedWalletId: String? { SelectedWalletSettings.shared.currentAccount?.address }

    func switchTo(walletId: String, completion: @escaping (Bool) -> Void) {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = {
            let accounts = (try? operation.extractNoCancellableResultData()) ?? []
            DispatchQueue.main.async {
                guard let account = accounts.first(where: { $0.address == walletId }) else {
                    completion(false)
                    return
                }
                SelectedWalletSettings.shared.performSave(value: account) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            EventCenter.shared.notify(with: SelectedAccountChanged(), completionOnMain: {
                                completion(true)
                            })
                        case .failure:
                            completion(false)
                        }
                    }
                }
            }
        }
        OperationManagerFacade.sharedDefaultQueue.addOperation(operation)
    }
}

/// Hand-offs with the Wallet tab's own services: the same screens its buttons open today.
@MainActor
final class PortfolioWalletRouter: PortfolioHandoffRouting {
    private weak var wallet: RedesignWalletViewModel?

    init(wallet: RedesignWalletViewModel) {
        self.wallet = wallet
    }

    /// The Wallet tab's Send: it asks for the network when the wallet has a choice.
    func showSend(from controller: UIViewController) {
        wallet?.sendFromWallet()
    }

    func showSora2Send(from controller: UIViewController, assetId: String?, recipient: String?,
                       amount: PortfolioAmountChoice?) {
        guard let wallet else { return }
        let viewModel = InputAssetAmountViewModel(selectedTokenId: assetId,
                                                  selectedAddress: recipient,
                                                  fiatService: wallet.fiatService,
                                                  assetManager: wallet.assetManager,
                                                  providerFactory: wallet.providerFactory,
                                                  networkFacade: wallet.networkFacade,
                                                  wireframe: InputAssetAmountWireframe(),
                                                  assetsProvider: wallet.assetsProvider,
                                                  qrEncoder: wallet.qrEncoder,
                                                  sharingFactory: wallet.sharingFactory,
                                                  marketCapService: wallet.marketCapService)
        let inputAmountController = InputAssetAmountViewController(viewModel: viewModel)
        viewModel.view = inputAmountController
        let navigationController = UINavigationController(rootViewController: inputAmountController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        // The Send screen's own amount handling: a typed amount, or its Max preset.
        inputAmountController.loadViewIfNeeded()
        switch amount {
        case let .exact(value)?:
            viewModel.inputedFirstAmount = value
            let precision = wallet.assetManager.assetInfo(for: assetId ?? "")?.precision ?? 18
            inputAmountController.set(firstAmountText: NumberFormatter.inputedAmoutFormatter(with: precision)
                .stringFromDecimal(value) ?? "")
        case .max?:
            viewModel.didSelect(variant: 1)
        case nil:
            break
        }
        controller.present(containerView, animated: true)
    }

    /// The Wallet tab's Receive: it asks for the network when the wallet has a choice.
    func showReceive(from controller: UIViewController) {
        wallet?.receive(showSora2Receive: { [weak self, weak controller] in
            guard let self, let controller else { return }
            self.showSora2Receive(from: controller)
        })
    }

    func showSora2Receive(from controller: UIViewController) {
        guard let wallet, let account = SelectedWalletSettings.shared.currentAccount else { return }
        let accountId = try? SS58AddressFactory().accountId(fromAddress: account.address, type: account.addressType)
            .toHex(includePrefix: true)
        let name = account.username.isEmpty ? account.address : account.username
        wallet.wireframe?.showGenerateQR(on: controller,
                                         accountId: accountId ?? "",
                                         address: account.address,
                                         username: name,
                                         qrEncoder: wallet.qrEncoder,
                                         sharingFactory: wallet.sharingFactory,
                                         assetManager: wallet.assetManager,
                                         assetsProvider: wallet.assetsProvider,
                                         networkFacade: wallet.networkFacade,
                                         providerFactory: wallet.providerFactory,
                                         isScanQRShown: false,
                                         marketCapService: wallet.marketCapService,
                                         closeHandler: nil)
    }

    func showSwap(from controller: UIViewController, fromAssetId: String, toAssetId: String) {
        guard let wallet,
              let swapController = SwapViewFactory.createView(selectedTokenId: fromAssetId,
                                                              selectedSecondTokenId: toAssetId,
                                                              assetManager: wallet.assetManager,
                                                              fiatService: wallet.fiatService,
                                                              networkFacade: wallet.networkFacade,
                                                              polkaswapNetworkFacade: wallet.polkaswapNetworkFacade,
                                                              assetsProvider: wallet.assetsProvider,
                                                              marketCapService: wallet.marketCapService) else { return }
        // The disclaimer the app already requires before the first swap (the tab bar's Polkaswap button).
        if ApplicationConfig.shared.isDisclamerShown {
            controller.present(swapController, animated: true)
            return
        }
        guard let disclaimer = MainTabBarViewFactory.swapDisclamerController(completion: { [weak controller] in
            UserDefaults.standard.set(true, forKey: "isDisclamerShown")
            controller?.present(swapController, animated: true)
        }) else { return }
        controller.present(disclaimer, animated: true)
    }

    /// The selected wallet's page on another network (balance, address, activity and, where the
    /// network allows it, Send), opened the way the Wallet tab's network rows open it. Its Send has
    /// no recipient to prefill: the user pastes it.
    func showNetwork(_ network: PortfolioNetwork, send: Bool, from controller: UIViewController) -> Bool {
        let settings = SettingsManager.shared
        guard let wallet, network != .sora2,
              let account = WalletNetworkAccounts.selectedWallet().first(where: { $0.networkId == network.networkId }),
              ProductSurfacePolicy.showsNexusPortfolio, settings.nexusEnabled,
              NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
                  networkId: account.networkId,
                  nexusEnabled: settings.nexusEnabled,
                  tairaEnabled: settings.isTairaEnabled,
                  tairaAdmitted: NexusNetworkAdmissionPolicy.current.isTairaAdmitted
              ) else { return false }
        wallet.openNetwork(account: account, startSend: send)
        return true
    }

    func showManageWallets(from controller: UIViewController) {
        wallet?.wireframe?.showManageAccount(on: controller) {}
    }

    func showManageAssets(from controller: UIViewController) {
        wallet?.showFullListAssets()
    }
}

extension RedesignWalletViewModel {
    /// Connects the portfolio home to the Wallet tab: its sheets and hand-offs, the selected
    /// account's key warning and the network pages of XOR on other networks.
    @MainActor
    func preparePortfolio() {
        let home = portfolioHome
        if home.coordinator == nil, let controller = view?.controller {
            home.attach(host: controller, router: PortfolioWalletRouter(wallet: self), switcher: PortfolioAccountSwitcher())
        }
        let account = SelectedWalletSettings.shared.currentAccount
        home.noticeItem.account = account
        home.noticeItem.onRestore = { [weak self] in
            guard let controller = self?.view?.controller, let account else { return }
            Task { @MainActor in
                WalletAccountCapability.presentRepair(account: account, from: controller)
            }
        }
        home.noticeItem.onCapabilityChange = { [weak self] showsOrHides in
            Task { @MainActor in
                guard let self else { return }
                if showsOrHides {
                    self.updateItems()
                } else {
                    self.reloadItem?([self.portfolioHome.noticeItem])
                }
            }
        }
        home.otherNetworksItem.onOpen = { [weak self] account in
            Task { @MainActor in self?.openNetwork(account: account) }
        }
    }
}
