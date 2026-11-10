// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import CoreImage
import Foundation
import NexusTransferCodec
import SoraFoundation
import SoraKeystore
import SoraUIKit
import UIKit

enum NexusPortfolioPresentationPolicy {
    enum PendingKind: Equatable {
        case currentXor
        case assetRecovery
    }

    struct PendingRow: Equatable {
        let transaction: NexusPendingTransaction
        let kind: PendingKind
    }

    struct NetworkDetailAccess: Equatable {
        let readsAvailable: Bool
        let mutationSurfaceAvailable: Bool
    }

    static func rowsMatchSelectedWallet(
        walletIds: [String],
        selectedWalletId: String?
    ) -> Bool {
        guard !walletIds.isEmpty else {
            return true
        }
        guard let selectedWalletId, !selectedWalletId.isEmpty else {
            return false
        }
        return walletIds.allSatisfy { $0 == selectedWalletId }
    }

    static func detailMatchesSelectedWallet(
        walletId: String,
        selectedWalletId: String?
    ) -> Bool {
        walletId == selectedWalletId
    }

    static let journalUnavailableMessage =
        "The protected pending-transaction journal is unavailable. Receive addresses, balances, and finalized history remain read-only; Nexus sends are disabled until the journal is recovered."

    static func portfolioSubtitle(tairaAdmitted: Bool) -> String {
        tairaAdmitted
            ? "SORA2 · Nexus Production Address · Taira Testnet"
            : "SORA2 · Nexus Production Address"
    }

    static func exposesTairaSettings(tairaAdmitted: Bool) -> Bool {
        tairaAdmitted
    }

    static func networkDetailIsAvailable(
        networkId: NetworkId,
        nexusEnabled: Bool,
        tairaEnabled: Bool,
        tairaAdmitted: Bool
    ) -> Bool {
        guard nexusEnabled else {
            return false
        }
        return networkId != .taira ||
            (tairaEnabled && tairaAdmitted)
    }

    static func networkDetailAccess(
        networkId: NetworkId,
        nexusEnabled: Bool,
        tairaEnabled: Bool,
        tairaAdmitted: Bool,
        mutationCoordinatorAvailable: Bool
    ) -> NetworkDetailAccess {
        let readsAvailable = networkDetailIsAvailable(
            networkId: networkId,
            nexusEnabled: nexusEnabled,
            tairaEnabled: tairaEnabled,
            tairaAdmitted: tairaAdmitted
        )
        return NetworkDetailAccess(
            readsAvailable: readsAvailable && networkId == .taira,
            mutationSurfaceAvailable:
                readsAvailable && networkId == .taira && mutationCoordinatorAvailable
        )
    }

    static func mutationIsReady(
        mutationCoordinatorAvailable: Bool,
        pendingJournalLoaded: Bool,
        containsAssetRecovery: Bool,
        currentXorIdentityVerified: Bool,
        featureEnabled: Bool
    ) -> Bool {
        mutationCoordinatorAvailable &&
            pendingJournalLoaded &&
            !containsAssetRecovery &&
            currentXorIdentityVerified &&
            featureEnabled
    }

    static func pendingRows(
        _ transactions: [NexusPendingTransaction],
        currentXorAssetDefinitionID: String?
    ) -> [PendingRow] {
        let currentID = currentXorAssetDefinitionID.flatMap {
            NexusAssetDefinitionIdentity.hasCanonicalWireShape($0) ? $0 : nil
        }
        return transactions.map { transaction in
            let configuration = NexusNetworkConfiguration.configuration(
                for: transaction.networkId
            )
            let isCurrentChain = configuration.map {
                transaction.chainId == $0.chainId
            } ?? false
            let assetMatches = currentID.map {
                transaction.assetDefinitionID == $0
            } ?? false
            let isCurrentXor = isCurrentChain && assetMatches
            return PendingRow(
                transaction: transaction,
                kind: isCurrentXor ? .currentXor : .assetRecovery
            )
        }
    }
}

func readCurrentNexusXorBalance(
    account: NetworkAccount,
    configuration: NexusNetworkConfiguration,
    readClient: NexusToriiReading
) async throws -> NexusCurrentXorBalance {
    guard account.networkId == configuration.networkId else {
        throw NexusToriiError.wrongWalletOrNetwork
    }
    let definition = try await readClient.xorAssetDefinition(
        configuration: configuration
    )
    let response = try await readClient.accountAssets(
        account: account.address,
        configuration: configuration,
        asset: definition.id,
        limit: 100,
        offset: 0
    )
    let quantity = try NexusBalanceValidator.xorBalance(
        in: response,
        account: account.address,
        configuration: configuration,
        assetDefinitionID: definition.id
    )
    return NexusCurrentXorBalance(
        quantity: quantity,
        assetDefinitionID: definition.id
    )
}

enum NexusPortfolioTaskPolicy {
    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError ||
            (error as? URLError)?.code == .cancelled
    }
}

@MainActor
final class NexusPortfolioViewController: WalletTableViewController {
    private struct Row {
        let account: NetworkAccount
        var balance: String
        var error: String?
    }

    private let assetsProvider: AssetProviderProtocol?
    private let readClient: NexusToriiReading
    private let networkStore: () throws -> WalletNetworkStore
    private let openSora2Experience: @MainActor () -> Bool
    private let settings = SettingsManager.shared
    private var coordinator: NexusTransactionCoordinator?
    private var nexusInfrastructureError: String?
    private var rows: [Row] = []
    private var mainNetwork: NetworkId = MainNetworkPolicy.preferred
    private var loadTask: Task<Void, Never>?

    init(
        assetsProvider: AssetProviderProtocol?,
        readClient: NexusToriiReading = NexusToriiReadClient(),
        openSora2Experience: @escaping @MainActor () -> Bool = { false },
        networkStore: @escaping () throws -> WalletNetworkStore = { try WalletNetworkStore() }
    ) {
        self.assetsProvider = assetsProvider
        self.readClient = readClient
        self.networkStore = networkStore
        self.openSora2Experience = openSora2Experience
        super.init(style: .insetGrouped)
        let runtime = NexusTransactionRuntime.shared
        coordinator = runtime.coordinator
        if runtime.initializationFailed {
            nexusInfrastructureError = NexusPortfolioPresentationPolicy.journalUnavailableMessage
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        assetsProvider?.remove(observer: self)
        loadTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshVisible), name: UIApplication.didBecomeActiveNotification, object: nil)
        title = WalletUX.text("Networks")
        view.backgroundColor = WalletUX.page
        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: "Network"
        )
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(
            self,
            action: #selector(refresh),
            for: .valueChanged
        )
        assetsProvider?.add(observer: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Tab navigation retains this controller across wallet changes. Always
        // rebuild from the currently selected wallet before exposing receive
        // addresses, balances, pending transactions, or history again.
        reload()
    }

    @objc private func refreshVisible() {
        guard isViewLoaded, view.window != nil else { return }
        reload()
    }

    @objc private func refresh() {
        reload()
    }

    private func reload() {
        loadTask?.cancel()
        let selectedWalletId =
            SelectedWalletSettings.shared.currentAccount?.address
        let rowsRemainAvailable = rows.allSatisfy { row in
            row.account.networkId == .sora2 ||
                NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
                    networkId: row.account.networkId,
                    nexusEnabled: settings.nexusEnabled,
                    tairaEnabled: settings.isTairaEnabled,
                    tairaAdmitted: NexusNetworkAdmissionPolicy
                        .current.isTairaAdmitted
                )
        }
        if !NexusPortfolioPresentationPolicy.rowsMatchSelectedWallet(
            walletIds: rows.map(\.account.walletId),
            selectedWalletId: selectedWalletId
        ) || !rowsRemainAvailable {
            // Account selection is a privacy boundary. Remove the previous
            // wallet's addresses, balances and transaction rows synchronously,
            // before the replacement snapshot performs any asynchronous work.
            rows = []
            tableView.reloadData()
        }
        loadTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                guard
                    let snapshot = try networkStore().load(),
                    let walletId = SelectedWalletSettings.shared
                        .currentAccount?.address,
                    snapshot.wallets.contains(where: {
                        $0.id == walletId
                    })
                else {
                    throw WalletNetworkMigrationError.missingSnapshot
                }

                var accounts = snapshot.accounts
                    .filter { $0.walletId == walletId }
                    .filter {
                        $0.networkId != .taira ||
                            (self.settings.isTairaEnabled &&
                                NexusNetworkAdmissionPolicy
                                    .current.isTairaAdmitted)
                    }
                if !settings.nexusEnabled {
                    accounts.removeAll { $0.networkId != .sora2 }
                }
                let directory = WalletNetworkDirectory.current
                let main = directory.mainNetwork(walletNetworks: Set(accounts.map(\.networkId)))
                let order = directory.ordered(accounts.map(\.networkId), main: main)
                accounts.sort {
                    (order.firstIndex(of: $0.networkId) ?? order.count) <
                        (order.firstIndex(of: $1.networkId) ?? order.count)
                }
                mainNetwork = main

                guard portfolioContextIsCurrent(walletId: walletId) else {
                    clearRowsAfterContextChange()
                    return
                }

                rows = accounts.map {
                    Row(account: $0, balance: "Loading…", error: nil)
                }
                tableView.reloadData()
                await loadBalances(expectedWalletId: walletId)
            } catch {
                if NexusPortfolioTaskPolicy.isCancellation(error) {
                    refreshControl?.endRefreshing()
                    return
                }
                rows = []
                tableView.reloadData()
                showError(error)
            }
            refreshControl?.endRefreshing()
        }
    }

    private func loadBalances(expectedWalletId: String) async {
        for index in rows.indices {
            guard
                portfolioContextIsCurrent(walletId: expectedWalletId),
                rows.indices.contains(index)
            else {
                clearRowsAfterContextChange()
                return
            }
            let account = rows[index].account
            guard portfolioContextIsCurrent(
                walletId: expectedWalletId,
                account: account
            ) else {
                clearRowsAfterContextChange()
                return
            }
            if account.networkId == .sora2 {
                let assetID = WalletAssetId.xor.rawValue
                if assetsProvider?.unavailableBalanceAssetIds(among: [assetID]).contains(assetID) == true {
                    rows[index].balance = "Unavailable"
                } else {
                    let balances = assetsProvider?.getBalances(with: [assetID]).filter { $0.identifier == assetID } ?? []
                    if balances.count == 1, let value = balances.first,
                       !value.balance.decimalValue.isNaN, value.balance.decimalValue >= 0 {
                        rows[index].balance = value.balance.stringValue
                    } else {
                        rows[index].balance = "—"
                    }
                }
            } else if !WalletNetworkDirectory.current.info(account.networkId).isLive {
                rows[index].balance = WalletUX.text("Address ready")
            } else {
                do {
                    guard
                        let configuration =
                            NexusNetworkConfiguration.configuration(
                                for: account.networkId
                            )
                    else {
                        throw NexusToriiError.wrongWalletOrNetwork
                    }
                    let currentBalance = try await readCurrentNexusXorBalance(
                        account: account,
                        configuration: configuration,
                        readClient: readClient
                    )
                    let loadedBalance = currentBalance.quantity.rawValue
                    guard
                        portfolioContextIsCurrent(
                            walletId: expectedWalletId,
                            account: account
                        ),
                        rows.indices.contains(index),
                        rows[index].account == account
                    else {
                        clearRowsAfterContextChange()
                        return
                    }
                    rows[index].balance = loadedBalance
                } catch {
                    if NexusPortfolioTaskPolicy.isCancellation(error) {
                        return
                    }
                    guard
                        portfolioContextIsCurrent(
                            walletId: expectedWalletId,
                            account: account
                        ),
                        rows.indices.contains(index),
                        rows[index].account == account
                    else {
                        clearRowsAfterContextChange()
                        return
                    }
                    rows[index].balance = "Unavailable"
                    rows[index].error = error.localizedDescription
                }
            }
            guard
                portfolioContextIsCurrent(
                    walletId: expectedWalletId,
                    account: account
                ),
                rows.indices.contains(index),
                rows[index].account == account
            else {
                clearRowsAfterContextChange()
                return
            }
            tableView.reloadRows(
                at: [IndexPath(row: index, section: 0)],
                with: .none
            )
        }
    }

    private func portfolioContextIsCurrent(
        walletId: String,
        account: NetworkAccount? = nil
    ) -> Bool {
        guard
            !Task.isCancelled,
            NexusPortfolioPresentationPolicy.detailMatchesSelectedWallet(
                walletId: walletId,
                selectedWalletId:
                    SelectedWalletSettings.shared.currentAccount?.address
            )
        else {
            return false
        }
        guard let account, account.networkId != .sora2 else {
            return true
        }
        return NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
            networkId: account.networkId,
            nexusEnabled: settings.nexusEnabled,
            tairaEnabled: settings.isTairaEnabled,
            tairaAdmitted: NexusNetworkAdmissionPolicy
                .current.isTairaAdmitted
        )
    }

    private func clearRowsAfterContextChange() {
        guard !Task.isCancelled else {
            return
        }
        rows = []
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        rows.count
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        WalletUX.text("XOR on each network")
    }

    override func tableView(
        _ tableView: UITableView,
        titleForFooterInSection section: Int
    ) -> String? {
        if rows.contains(where: { $0.account.networkId != .sora2 }) {
            return WalletUX.text("Use Taira for testnet balances and activity. You can create and copy your Nexus production address before the production network launches. Testnet funds have no monetary value.")
        }
        return WalletUX.text("Only SORA2 is available for this account. To add other networks, import this wallet using its recovery phrase in Accounts.")
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let row = rows[indexPath.row]
        let cell = UITableViewCell(
            style: .subtitle,
            reuseIdentifier: "Network"
        )
        var configuration = cell.defaultContentConfiguration()
        configuration.text = Self.title(for: row.account.networkId, main: mainNetwork)
        configuration.secondaryText = WalletNetworkDirectory.current.info(row.account.networkId).isLive
            ? "\(row.balance) XOR\n\(Self.short(row.account.address))"
            : "\(row.balance)\n\(Self.short(row.account.address))"
        configuration.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
        if row.account.networkId == .taira {
            cell.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.08)
        }
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        guard portfolioContextIsCurrent(
            walletId: row.account.walletId,
            account: row.account
        ) else {
            clearRowsAfterContextChange()
            return
        }
        if row.account.networkId == .sora2 {
            // Keep the established SORA2 asset experience—send, receive QR,
            // finalized history and explorer actions—instead of duplicating
            // signing behavior inside the Nexus controller.
            if !openSora2Experience() {
                showAddress(
                    title: WalletUX.text("SORA2"),
                    account: row.account,
                    notice: assetsProvider == nil
                        ? "SORA2 services are unavailable. Go back to retry or change the SORA2 node. Other networks remain available."
                        : "Open Wallet and select XOR for SORA2 send, history, QR, and explorer actions."
                )
            }
            return
        }
        guard
            let configuration = NexusNetworkConfiguration.configuration(
                for: row.account.networkId
            )
        else {
            showErrorMessage("The selected network configuration is unavailable.")
            return
        }
        let access = NexusPortfolioPresentationPolicy.networkDetailAccess(
            networkId: row.account.networkId,
            nexusEnabled: settings.nexusEnabled,
            tairaEnabled: settings.isTairaEnabled,
            tairaAdmitted: NexusNetworkAdmissionPolicy
                .current.isTairaAdmitted,
            mutationCoordinatorAvailable: coordinator != nil
        )
        guard access.readsAvailable || row.account.networkId == .minamoto else {
            clearRowsAfterContextChange()
            return
        }
        navigationController?.pushViewController(
            NexusNetworkDetailViewController(
                account: row.account,
                configuration: configuration,
                coordinator: coordinator,
                readClient: readClient,
                mutationUnavailableReason: nexusInfrastructureError,
                networkStore: networkStore
            ),
            animated: true
        )
    }

    private func showAddress(
        title: String,
        account: NetworkAccount,
        notice: String? = nil
    ) {
        let alert = UIAlertController(
            title: "\(title) receive address",
            message: [account.address, notice]
                .compactMap { $0 }
                .joined(separator: "\n\n"),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: WalletUX.text("Copy"), style: .default) {
                [weak self] _ in
                guard
                    let self,
                    self.portfolioContextIsCurrent(
                        walletId: account.walletId,
                        account: account
                    )
                else {
                    self?.clearRowsAfterContextChange()
                    return
                }
                UIPasteboard.general.string = account.address
            }
        )
        alert.addAction(UIAlertAction(title: WalletUX.text("Close"), style: .cancel))
        present(alert, animated: true)
    }

    private func showError(_ error: Error) {
        showErrorMessage(error.localizedDescription)
    }

    private func showErrorMessage(_ message: String) {
        let alert = UIAlertController(
            title: WalletUX.text("Portfolio unavailable"),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
        present(alert, animated: true)
    }

    private static func title(for network: NetworkId, main: NetworkId) -> String {
        let directory = WalletNetworkDirectory.current
        let name = directory.info(network).name
        return directory.tag(for: network, main: main).map { "\(name) · \($0.title)" } ?? name
    }

    private static func short(_ value: String) -> String {
        guard value.count > 24 else {
            return value
        }
        return "\(value.prefix(12))…\(value.suffix(10))"
    }
}

extension NexusPortfolioViewController: AssetProviderObserverProtocol {
    nonisolated func processBalance(data: [BalanceData]) {
        Task { @MainActor [weak self] in
            self?.reload()
        }
    }
}

/// One network's XOR (Taira, or the SORA Nexus production address) on
/// SORA2's asset-details screen: the token card, the balance card with its
/// round actions, Recent activity and the address card. Every read and
/// every action still checks the selected wallet and the network first.
@MainActor
final class NexusNetworkDetailViewController: SoramitsuViewController {
    private enum BalanceState: Equatable {
        case loading
        case loaded(String)
        case unavailable
        case notLive
    }

    /// The balance card's Send: offered on a network that allows sends, and
    /// usable only once the balance, the XOR asset and the pending journal
    /// have been checked.
    private struct SendEntry {
        var isAvailable = false
        var isEnabled = false
    }

    private let account: NetworkAccount
    private let configuration: NexusNetworkConfiguration
    private let coordinator: NexusTransactionCoordinator?
    private let readClient: NexusToriiReading
    private let networkStore: () throws -> WalletNetworkStore
    private let mutationUnavailableReason: String?
    private let xorAsset: AssetInfo?
    private let xorImage: UIImage?
    private var history: [NexusTransferHistoryItem] = []
    private var pendingRows: [NexusPortfolioPresentationPolicy.PendingRow] = []
    private var pendingLoadError: String?
    private var historyLoadError: String?
    private var balance = BalanceState.loading
    private var mutationReady = false
    private var sendEntry = SendEntry()
    private var sendAvailabilityMessage: String? = WalletUX.text("Checking the network and pending transfers before enabling Send.")
    private(set) var sendFlow: NexusSendFlow?
    private var loadTask: Task<Void, Never>?
    private var historyPageTask: Task<Void, Never>?
    private var historyCursor = NexusHistoryCursor()
    private var historyAssetDefinitionID: String?
    private var historyPageError: String?
    private var faucetTask: Task<Void, Never>?
    private var faucetClock: Task<Void, Never>?
    private(set) var faucet: NexusFaucetState?
    private var faucetHasPending = false
    private var faucetRetryAfter: Date?
    private let faucetService: TairaFaucetServing
    private let appEventService = AppEventService()
    /// Opened from the wallet's Send: show the send form once the checks
    /// below have made sending safe. Used once; a later refresh never
    /// reopens it.
    private var opensSendWhenReady: Bool
    /// Told when this screen closes. The wallet home below it stays in the
    /// window and gets no `viewWillAppear`, so this is how it hears that a
    /// send or a faucet claim made here may have changed the balance.
    var onClose: (@MainActor () -> Void)?

    private(set) var priceItem: PriceItem?
    private(set) var balanceItem: NexusBalanceItem?
    private(set) var activityItem: NexusActivityItem?
    private(set) var addressItem: AssetIdItem?
    private(set) var items: [SoramitsuTableViewItemProtocol] = []
    let refreshControl = UIRefreshControl()

    /// The same table as SORA2's asset details.
    private(set) lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        tableView.sora.cancelsTouchesOnDragging = true
        tableView.accessibilityIdentifier = "nexus.network.detail"
        return tableView
    }()

    init(
        account: NetworkAccount,
        configuration: NexusNetworkConfiguration,
        coordinator: NexusTransactionCoordinator?,
        readClient: NexusToriiReading,
        mutationUnavailableReason: String?,
        opensSendWhenReady: Bool = false,
        faucetService: TairaFaucetServing = TairaFaucetService.shared,
        xorAsset: AssetInfo? = NexusSora2Presentation.xorAsset,
        networkStore: @escaping () throws -> WalletNetworkStore = { try WalletNetworkStore() }
    ) {
        self.account = account
        self.configuration = configuration
        self.coordinator = coordinator
        self.readClient = readClient
        self.networkStore = networkStore
        self.mutationUnavailableReason = mutationUnavailableReason
        self.opensSendWhenReady = opensSendWhenReady
        self.faucetService = faucetService
        self.xorAsset = xorAsset
        self.xorImage = NexusSora2Presentation.xorImage(xorAsset)
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        loadTask?.cancel()
        historyPageTask?.cancel()
        faucetTask?.cancel()
        faucetClock?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshVisible), name: UIApplication.didBecomeActiveNotification, object: nil)
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        if navigationController?.viewControllers.first === self {
            // Presented as SORA2 presents its asset details.
            addCloseButton()
        }
        let access = NexusPortfolioPresentationPolicy.networkDetailAccess(
            networkId: account.networkId,
            nexusEnabled: SettingsManager.shared.nexusEnabled,
            tairaEnabled: SettingsManager.shared.isTairaEnabled,
            tairaAdmitted: NexusNetworkAdmissionPolicy
                .current.isTairaAdmitted,
            mutationCoordinatorAvailable: coordinator != nil
        )
        if access.mutationSurfaceAvailable {
            sendEntry.isAvailable = true
            sendEntry.isEnabled = false
        }
        if account.networkId == .taira, configuration.satisfiesCurrentTairaContract {
            faucet = NexusFaucetState(title: WalletUX.text("Get test XOR"),
                                      message: WalletUX.text("Free XOR for testing on Taira."),
                                      busy: false, enabled: true)
        }
        refreshControl.addTarget(
            self,
            action: #selector(refresh),
            for: .valueChanged
        )
        tableView.refreshControl = refreshControl
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard NexusPortfolioPresentationPolicy.detailMatchesSelectedWallet(
            walletId: account.walletId,
            selectedWalletId:
                SelectedWalletSettings.shared.currentAccount?.address
        ), NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
            networkId: account.networkId,
            nexusEnabled: SettingsManager.shared.nexusEnabled,
            tairaEnabled: SettingsManager.shared.isTairaEnabled,
            tairaAdmitted: NexusNetworkAdmissionPolicy
                .current.isTairaAdmitted
        )
        else {
            // This detail owns an immutable, network-qualified account. Once
            // selection or network availability changes it must not keep
            // presenting stale receive addresses or transaction data.
            loadTask?.cancel()
            faucetTask?.cancel()
            setMutationReady(false)
            closeStaleScreen()
            return
        }
        reload()
        restoreFaucetRequest()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed ||
            navigationController?.isBeingDismissed == true ||
            navigationController?.parent?.isBeingDismissed == true {
            faucetTask?.cancel()
            // The screen may sleep now, even if the request takes a moment to stop.
            faucetClock?.cancel()
            onClose?()
        }
    }

    @objc private func refreshVisible() {
        guard isViewLoaded, view.window != nil else { return }
        reload()
        restoreFaucetRequest()
    }

    @objc private func refresh() {
        reload()
    }

    /// Pops a pushed detail, or closes the SORA2-style modal it is the root of.
    private func closeStaleScreen() {
        if presentedViewController != nil { dismiss(animated: false) }
        if let navigation = navigationController, navigation.viewControllers.first === self {
            (navigation.parent ?? navigation).dismiss(animated: false)
        } else {
            navigationController?.popViewController(animated: false)
        }
    }

    private func reload() {
        loadTask?.cancel()
        historyPageTask?.cancel()
        historyPageTask = nil
        historyCursor = NexusHistoryCursor()
        historyAssetDefinitionID = nil
        historyPageError = nil
        setMutationReady(false)
        if !configuration.isLive {
            balance = .notLive
            history = []
            pendingRows = []
            sendAvailabilityMessage = WalletUX.text("Your production address is ready to copy or share. Balances, activity, and transfers will be available when the SORA Nexus production network launches.")
            refreshControl.endRefreshing()
            render()
            return
        }
        // The balance and Send come first. Until 2026-11-08 this screen drew
        // nothing until every pending transfer had been reconciled with Torii
        // and a history page had loaded; one Taira send that was waiting for
        // its history proof kept it on "Loading…" with no Send for minutes.
        // Send still opens only on the same checks: a readable journal with
        // no record from another chain or asset, and a verified XOR identity.
        loadTask = Task { [weak self] in
            guard let self else {
                return
            }
            guard reloadContextIsCurrent() else {
                return
            }
            async let balanceResult = Self.readBalanceWithDeadline(
                account: account,
                configuration: configuration,
                readClient: readClient
            )
            var journal: [NexusPendingTransaction] = []
            var currentXorAssetDefinitionID: String?
            if let coordinator {
                do {
                    // The journal as written, read locally: enough to gate
                    // Send. Network reconciliation follows below.
                    journal = try await coordinator.journalSnapshot()
                        .filter {
                            $0.walletId == self.account.walletId &&
                                $0.networkId == self.account.networkId
                        }
                        .sorted { $0.updatedAt > $1.updatedAt }
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    pendingLoadError = nil
                } catch {
                    if Self.isOwnCancellation(error) {
                        refreshControl.endRefreshing()
                        return
                    }
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    pendingRows = []
                    pendingLoadError =
                        "The protected pending-transaction journal is unreadable. Sending is disabled until it is recovered."
                }
            } else {
                pendingRows = []
                pendingLoadError = mutationUnavailableReason ??
                    "The protected pending-transaction journal is unavailable. Read-only balance and finalized history remain available; sending is disabled until recovery."
            }
            do {
                let value = try await balanceResult
                guard reloadContextIsCurrent() else {
                    return
                }
                balance = .loaded(value.quantity.rawValue)
                currentXorAssetDefinitionID = value.assetDefinitionID
            } catch {
                // Only cancellation is silent. A request that failed, ran
                // out of time or was cancelled by the system shows "Balance
                // unavailable" and the pull-to-refresh retry, never "Loading…".
                if Self.isOwnCancellation(error) {
                    refreshControl.endRefreshing()
                    return
                }
                guard reloadContextIsCurrent() else {
                    return
                }
                balance = .unavailable
            }
            if pendingLoadError == nil {
                pendingRows = NexusPortfolioPresentationPolicy.pendingRows(
                    journal,
                    currentXorAssetDefinitionID: currentXorAssetDefinitionID
                )
            }
            applyMutationReadiness(
                currentXorIdentityVerified: currentXorAssetDefinitionID != nil
            )
            refreshControl.endRefreshing()
            render()

            // Finalized history, then the pending records' status from
            // Torii. Each redraws its own rows when it arrives.
            if let currentXorAssetDefinitionID {
                await loadFirstHistory(
                    assetDefinitionID: currentXorAssetDefinitionID
                )
            } else {
                history = []
                historyLoadError =
                    "Finalized history is unavailable until the current XOR asset identity can be verified."
            }
            guard reloadContextIsCurrent() else {
                return
            }
            render()
            guard let coordinator, pendingLoadError == nil else {
                return
            }
            do {
                let reconciled = try await coordinator.resumePending()
                    .filter {
                        $0.walletId == self.account.walletId &&
                            $0.networkId == self.account.networkId
                    }
                    .sorted { $0.updatedAt > $1.updatedAt }
                guard reloadContextIsCurrent() else {
                    return
                }
                pendingRows = NexusPortfolioPresentationPolicy.pendingRows(
                    reconciled,
                    currentXorAssetDefinitionID: currentXorAssetDefinitionID
                )
            } catch {
                if Self.isOwnCancellation(error) {
                    return
                }
                guard reloadContextIsCurrent() else {
                    return
                }
                pendingRows = []
                pendingLoadError =
                    "The protected pending-transaction journal is unreadable. Sending is disabled until it is recovered."
                applyMutationReadiness(
                    currentXorIdentityVerified: currentXorAssetDefinitionID != nil
                )
            }
            render()
        }
    }

    /// This load's own cancellation (a newer reload, or the screen going
    /// away). `URLError.cancelled` alone is not enough: URLSession reports it
    /// for a refused challenge too, and that must not leave "Loading…".
    nonisolated static func isOwnCancellation(_ error: Error) -> Bool {
        Task.isCancelled || error is CancellationError
    }

    /// The XOR balance read with a deadline: a stalled request shows
    /// "Balance unavailable" and a retry, never an endless "Loading…".
    nonisolated static func readBalanceWithDeadline(
        account: NetworkAccount,
        configuration: NexusNetworkConfiguration,
        readClient: NexusToriiReading,
        seconds: UInt64 = 45
    ) async throws -> NexusCurrentXorBalance {
        try await withThrowingTaskGroup(of: NexusCurrentXorBalance?.self) { group in
            group.addTask {
                try await readCurrentNexusXorBalance(
                    account: account,
                    configuration: configuration,
                    readClient: readClient
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                return nil
            }
            defer { group.cancelAll() }
            guard let first = try await group.next(), let value = first else {
                throw URLError(.timedOut)
            }
            return value
        }
    }

    /// Pages of Taira history that may come back empty before the first
    /// transfer: the server reads block ranges newest first and answers a
    /// range without matching rows with an empty page and a cursor.
    static let emptyHistoryPagesToFollow = 12

    /// The first page of finalized history that has transfers in it.
    private func loadFirstHistory(assetDefinitionID: String) async {
        do {
            var cursor = NexusHistoryCursor()
            var items: [NexusTransferHistoryItem] = []
            var pages = 0
            repeat {
                let value = try await readClient.transferHistoryPage(
                    account: account.address,
                    configuration: configuration,
                    assetDefinitionID: assetDefinitionID,
                    cursor: cursor.nextCursor
                )
                guard reloadContextIsCurrent() else {
                    return
                }
                try cursor.accept(value)
                items.append(contentsOf: value.items)
                pages += 1
            } while items.isEmpty && cursor.hasMore &&
                pages < Self.emptyHistoryPagesToFollow
            historyCursor = cursor
            history = items
            historyAssetDefinitionID = assetDefinitionID
            historyLoadError = nil
        } catch {
            if Self.isOwnCancellation(error) {
                return
            }
            guard reloadContextIsCurrent() else {
                return
            }
            history = []
            historyLoadError =
                "Finalized history is temporarily unavailable. No local transaction was retried."
        }
    }

    private func applyMutationReadiness(currentXorIdentityVerified: Bool) {
        setMutationReady(
            NexusPortfolioPresentationPolicy.mutationIsReady(
                mutationCoordinatorAvailable: coordinator != nil,
                pendingJournalLoaded: pendingLoadError == nil,
                containsAssetRecovery: pendingRows.contains(where: {
                    $0.kind == .assetRecovery
                }),
                currentXorIdentityVerified: currentXorIdentityVerified,
                featureEnabled: SettingsManager.shared.nexusSendsEnabled(for: configuration.networkId)
            )
        )
        if mutationReady {
            sendAvailabilityMessage = nil
        } else if !SettingsManager.shared.nexusSendsEnabled(for: configuration.networkId) {
            sendAvailabilityMessage = WalletUX.text("Sending is paused for this network. Check that Taira Testnet is enabled in Settings.")
        } else if pendingLoadError != nil || pendingRows.contains(where: { $0.kind == .assetRecovery }) {
            sendAvailabilityMessage = WalletUX.text("Sending is paused while pending transfers need checking. Review the activity below before starting another transfer.")
        } else {
            sendAvailabilityMessage = WalletUX.text("Sending is unavailable until this network's balance and XOR asset can be verified. Pull down to refresh.")
        }
    }

    private func reloadContextIsCurrent() -> Bool {
        guard !Task.isCancelled else {
            return false
        }
        guard
            NexusPortfolioPresentationPolicy.detailMatchesSelectedWallet(
                walletId: account.walletId,
                selectedWalletId:
                    SelectedWalletSettings.shared.currentAccount?.address
            ),
            NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
                networkId: account.networkId,
                nexusEnabled: SettingsManager.shared.nexusEnabled,
                tairaEnabled: SettingsManager.shared.isTairaEnabled,
                tairaAdmitted: NexusNetworkAdmissionPolicy
                    .current.isTairaAdmitted
            )
        else {
            refreshControl.endRefreshing()
            setMutationReady(false)
            faucetTask?.cancel()
            faucet?.enabled = false
            renderBalance()
            closeStaleScreen()
            return false
        }
        return true
    }

    private func setMutationReady(_ ready: Bool) {
        mutationReady = ready
        sendEntry.isEnabled = ready
        renderBalance()
        guard ready, opensSendWhenReady, isViewLoaded, view.window != nil, presentedViewController == nil else {
            return
        }
        opensSendWhenReady = false
        // The checks can finish while this screen is still being presented.
        if let transition = transitionCoordinator ?? navigationController?.transitionCoordinator {
            transition.animate(alongsideTransition: nil) { [weak self] _ in
                self?.send()
            }
        } else {
            send()
        }
    }

    private var network: WalletNetworkInfo {
        WalletNetworkDirectory.current.info(account.networkId)
    }

    /// "Taira · Testnet" or "SORA Nexus · Coming soon".
    private var networkLabel: String {
        Self.networkLabel(for: account.networkId)
    }

    static func networkLabel(for networkId: NetworkId) -> String {
        let directory = WalletNetworkDirectory.current
        let network = directory.info(networkId)
        let main = directory.mainNetwork(walletNetworks: [.sora2, networkId])
        return directory.tag(for: networkId, main: main)
            .map { "\(network.name) · \($0.title)" } ?? network.name
    }

    private var balanceQuantity: String? {
        if case let .loaded(quantity) = balance { return quantity }
        return nil
    }

    /// SORA2 hides Send while there is nothing to send.
    private var hasBalanceToSend: Bool {
        guard let quantity = balanceQuantity,
              let value = Decimal(string: quantity, locale: Locale(identifier: "en_US_POSIX")) else { return false }
        return value > 0
    }

    private var balanceText: String {
        switch balance {
        case .loading: return WalletUX.text("Loading…")
        case let .loaded(quantity): return "\(quantity) XOR"
        case .unavailable: return WalletUX.balanceUnavailableText
        case .notLive: return WalletUX.text("Coming soon")
        }
    }

    // MARK: Items

    private func render() {
        guard isViewLoaded else { return }
        let price = PriceItem(icon: xorAsset?.icon,
                              tokenName: xorAsset?.name ?? "XOR",
                              tokenSymbol: xorAsset?.symbol ?? "XOR",
                              priceText: networkLabel)
        priceItem = price
        let balance = makeBalanceItem()
        balanceItem = balance
        var items: [SoramitsuTableViewItemProtocol] = [
            price,
            SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)),
            balance
        ]
        activityItem = makeActivityItem()
        if let activityItem {
            items.append(activityItem)
        }
        let address = AssetIdItem(
            assetId: account.address,
            title: configuration.isLive
                ? R.string.localizable.accountAddress(preferredLanguages: .currentLocale)
                : WalletUX.text("Production address"),
            tapHandler: { [weak self] in self?.copyAddress() })
        addressItem = address
        items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))
        items.append(address)
        self.items = items
        tableView.sora.sections = [SoramitsuTableViewSection(rows: items)]
    }

    /// Updates the balance card alone, for the changes that only it shows.
    private func renderBalance() {
        guard isViewLoaded, let current = balanceItem,
              let index = items.firstIndex(where: { $0 === current }) else { return }
        let updated = makeBalanceItem()
        balanceItem = updated
        items[index] = updated
        tableView.sora.sections = [SoramitsuTableViewSection(rows: items)]
    }

    private func makeBalanceItem() -> NexusBalanceItem {
        var notes: [String] = []
        if let sendAvailabilityMessage, sendEntry.isAvailable || !configuration.isLive {
            notes.append(sendAvailabilityMessage)
        }
        let item = NexusBalanceItem(
            balanceText: balanceText,
            showsSend: sendEntry.isAvailable && sendEntry.isEnabled && hasBalanceToSend,
            receiveTitle: configuration.isLive
                ? R.string.localizable.commonReceive(preferredLanguages: .currentLocale)
                : WalletUX.text("Production address"),
            faucet: faucet,
            notes: notes)
        item.actionHandler = { [weak self] action in
            switch action {
            case .send: self?.send()
            case .receive: self?.receive()
            case .faucet: self?.requestTestXor()
            }
        }
        return item
    }

    private func makeActivityItem() -> NexusActivityItem? {
        guard configuration.isLive else { return nil }
        var rows: [ActivityContentViewModel] = []
        var notices: [String] = []
        if pendingLoadError != nil {
            notices.append(WalletUX.text("Recovery required") + ". " +
                WalletUX.text("Sending is paused while pending transfers are unavailable. Tap to check again."))
        } else {
            // A send that finalized history already lists is shown once, as
            // SORA2 shows it: from history. Rejected or expired sends never
            // reach history and stay listed from the journal.
            let finalized = Set(history.compactMap {
                NexusTransactionHash.normalized($0.transactionHash)
            })
            rows += pendingRows
                .filter { row in
                    guard let hash = row.transaction.hash.flatMap(NexusTransactionHash.normalized) else {
                        return true
                    }
                    return !finalized.contains(hash)
                }
                .map { NexusActivityRows.pending($0, xorImage: xorImage) }
        }
        if historyLoadError != nil {
            notices.append(WalletUX.text("History unavailable") + ". " +
                WalletUX.text("Activity could not be loaded. Tap to refresh."))
        } else {
            rows += history.map { NexusActivityRows.history($0, account: account.address, xorImage: xorImage) }
        }
        if let historyPageError {
            notices.append(historyPageError)
        }
        let hasMore = historyLoadError == nil && historyCursor.hasMore && historyAssetDefinitionID != nil
        // SORA2 shows no activity card without activity.
        guard !rows.isEmpty || !notices.isEmpty || hasMore else { return nil }
        let item = NexusActivityItem(
            rows: rows,
            notice: notices.isEmpty ? nil : notices.joined(separator: "\n\n"),
            moreTitle: hasMore
                ? (historyPageTask == nil
                    ? R.string.localizable.showMore(preferredLanguages: .currentLocale)
                    : WalletUX.text("Loading…"))
                : nil)
        item.openDetails = { [weak self] id in self?.openActivity(id) }
        item.openMore = { [weak self] in self?.loadMoreHistory() }
        item.openNotice = { [weak self] in self?.showConnectionHelp() }
        return item
    }

    private func loadMoreHistory() {
        guard configuration.isLive, networkActionContextIsCurrent(),
              historyPageTask == nil,
              historyCursor.hasMore,
              let assetID = historyAssetDefinitionID else { return }
        historyPageError = nil
        historyPageTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if !Task.isCancelled {
                    historyPageTask = nil
                    render()
                }
            }
            do {
                // Follow empty block-range pages until the next transfers.
                var cursor = historyCursor
                var items: [NexusTransferHistoryItem] = []
                var pages = 0
                repeat {
                    let page = try await readClient.transferHistoryPage(
                        account: account.address, configuration: configuration,
                        assetDefinitionID: assetID, cursor: cursor.nextCursor
                    )
                    guard reloadContextIsCurrent() else { return }
                    try cursor.accept(page)
                    items.append(contentsOf: page.items)
                    pages += 1
                } while items.isEmpty && cursor.hasMore &&
                    pages < Self.emptyHistoryPagesToFollow
                historyCursor = cursor
                history.append(contentsOf: items)
            } catch {
                guard !NexusPortfolioTaskPolicy.isCancellation(error),
                      reloadContextIsCurrent() else { return }
                historyPageError = WalletUX.text("Could not load more activity. Retry, or pull down to refresh if new transfers arrived.")
            }
        }
        render()
    }

    private func networkActionContextIsCurrent() -> Bool {
        // Copy, explorer and send entry points can be invoked after a retained
        // controller receives an account/feature change but before navigation
        // teardown completes. Revalidate at the action boundary as well.
        reloadContextIsCurrent()
    }

    // MARK: Faucet

    private func updateFaucet(message: String? = nil, busy: Bool = false) {
        guard var state = faucet else { return }
        if let message { state.message = message }
        state.title = WalletUX.text(faucetHasPending ? "Check faucet request" : "Get test XOR")
        state.busy = busy
        // Keep the action tappable during a cooldown to explain when to retry.
        state.enabled = !busy
        faucet = state
        renderBalance()
    }

    /// Preparing can take minutes on a slow device, and no percentage can be shown
    /// because every try of the puzzle is independent of the others. So after a few
    /// seconds the status counts the time, to show that the claim is still going.
    /// The screen stays on until the clock stops, because the solve stands still
    /// while the phone is locked.
    private func startFaucetClock() {
        faucetClock?.cancel()
        let started = ProcessInfo.processInfo.systemUptime
        faucetClock = Task { [weak self] in
            defer { UIApplication.shared.isIdleTimerDisabled = false }
            while !Task.isCancelled {
                // One flag for the whole app, and a clock that has just stopped
                // clears it, so each tick sets it again.
                UIApplication.shared.isIdleTimerDisabled = true
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                let seconds = Int(ProcessInfo.processInfo.systemUptime - started)
                if seconds >= 3 { self.showFaucetClock(seconds: seconds) }
            }
        }
    }

    /// Changes only the status text. Going through renderBalance once a second
    /// would replace the table's section, which fades the whole page each time.
    func showFaucetClock(seconds: Int) {
        guard var state = faucet else { return }
        let time = String(format: "%d:%02d", seconds / 60, seconds % 60)
        state.message = WalletUX.format("Preparing your test XOR… %@\nThis can take a few minutes.", time)
        faucet = state
        balanceItem?.faucet = state
        guard let label = tableView.visibleCells.lazy.compactMap({ ($0 as? NexusBalanceCell)?.faucetStatusLabel }).first else { return }
        let fitting = CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)
        let height = label.sizeThatFits(fitting).height
        label.sora.text = state.message
        if label.sizeThatFits(fitting).height != height {
            UIView.performWithoutAnimation { tableView.performBatchUpdates(nil) }
        }
    }

    private func restoreFaucetRequest() {
        guard faucet != nil, faucetTask == nil else { return }
        faucetTask = Task { [weak self] in
            guard let self else { return }
            defer { faucetTask = nil }
            do {
                let pending = try await faucetService.hasPending(account: account.address)
                guard !Task.isCancelled, networkActionContextIsCurrent() else { return }
                faucetHasPending = pending
                updateFaucet(message: pending ? WalletUX.text("Your faucet request is still processing. Check again to update your balance.") : nil)
            } catch {
                guard !Task.isCancelled, networkActionContextIsCurrent() else { return }
                updateFaucet(message: WalletUX.text("Your saved faucet request could not be read. Try again after restarting the app."))
                faucet?.enabled = false
                renderBalance()
            }
        }
    }

    private func requestTestXor() {
        guard faucet != nil, faucetTask == nil, networkActionContextIsCurrent() else { return }
        guard faucet?.enabled == true else { return }
        if let retry = faucetRetryAfter, retry > Date() {
            updateFaucet(message: WalletUX.format("Please wait %@ seconds before requesting more test XOR.", String(Int(ceil(retry.timeIntervalSinceNow)))))
            return
        }
        updateFaucet(busy: true)
        faucetTask = Task { [weak self] in
            guard let self else { return }
            defer {
                faucetTask = nil
                faucetClock?.cancel()
                if networkActionContextIsCurrent() {
                    updateFaucet()
                } else {
                    faucet?.enabled = false
                    renderBalance()
                }
            }
            do {
                let outcome = try await faucetService.request(
                    account: account, configuration: configuration,
                    contextIsCurrent: { [weak self] in
                        guard let self else { return false }
                        return await self.networkActionContextIsCurrent()
                    }, progress: { [weak self] phase in
                        guard let self else { return }
                        await MainActor.run {
                            guard self.networkActionContextIsCurrent() else { return }
                            let text: String
                            switch phase {
                            case .preparing: text = "Preparing your test XOR…"
                            case .submitting: text = "Requesting test XOR…"
                            case .checking: text = "Checking your faucet request…"
                            }
                            self.faucetClock?.cancel()
                            self.updateFaucet(message: WalletUX.text(text), busy: true)
                            if case .preparing = phase { self.startFaucetClock() }
                        }
                    }
                )
                guard !Task.isCancelled, networkActionContextIsCurrent() else { return }
                switch outcome.state {
                case .applied:
                    faucetHasPending = false
                    let message = WalletUX.format("Received %@ test XOR.", outcome.amount)
                    updateFaucet(message: message)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    UIAccessibility.post(notification: .announcement, argument: message)
                    reload()
                case .pending:
                    faucetHasPending = true
                    updateFaucet(message: WalletUX.text("Your faucet request is still processing. Check again to update your balance."))
                case .rejected:
                    faucetHasPending = false
                    updateFaucet(message: WalletUX.text("The faucet request was not completed. Please try again."))
                }
            } catch {
                guard !Task.isCancelled, networkActionContextIsCurrent() else { return }
                let pending = (try? await faucetService.hasPending(account: account.address)) ?? true
                guard !Task.isCancelled, networkActionContextIsCurrent() else { return }
                faucetHasPending = pending
                if let failure = error as? TairaFaucetClient.Failure, case .rateLimited(let seconds) = failure {
                    faucetRetryAfter = Date().addingTimeInterval(min(max(seconds ?? 60, 1), 86_400))
                    updateFaucet(message: WalletUX.text("The faucet limit has been reached. Please try again later."))
                } else {
                    updateFaucet(message: WalletUX.text(faucetHasPending
                        ? "Your faucet request is still processing. Check again to update your balance."
                        : TairaFaucetClient.failureMessage(for: error)))
                }
            }
        }
    }

    // MARK: Actions

    @objc private func copyAddress() {
        guard networkActionContextIsCurrent() else {
            return
        }
        UIPasteboard.general.string = account.address
        NexusSora2Presentation.showCopied(appEventService)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    @objc private func openExplorer() {
        guard configuration.isLive, networkActionContextIsCurrent() else {
            return
        }
        UIApplication.shared.open(configuration.explorerURL)
    }

    /// SORA2's Receive screen with this network's receive address.
    private func receive() {
        guard networkActionContextIsCurrent() else {
            return
        }
        Self.presentReceive(account: account, configuration: configuration, xorAsset: xorAsset, from: self,
                            isCurrent: { [weak self] in self?.networkActionContextIsCurrent() ?? false })
    }

    /// SORA2's Receive screen for a network account, also opened straight
    /// from the wallet's Receive, as SORA2's own Receive is. Copy and Share
    /// check the selected wallet and the network first.
    static func presentReceive(
        account: NetworkAccount,
        configuration: NexusNetworkConfiguration,
        xorAsset: AssetInfo?,
        from presenter: UIViewController,
        isCurrent: (@MainActor () -> Bool)? = nil
    ) {
        let accountIsCurrent: @MainActor () -> Bool = {
            NexusPortfolioPresentationPolicy.detailMatchesSelectedWallet(
                walletId: account.walletId,
                selectedWalletId: SelectedWalletSettings.shared.currentAccount?.address
            ) && NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
                networkId: account.networkId,
                nexusEnabled: SettingsManager.shared.nexusEnabled,
                tairaEnabled: SettingsManager.shared.isTairaEnabled,
                tairaAdmitted: NexusNetworkAdmissionPolicy.current.isTairaAdmitted
            )
        }
        let contextIsCurrent: @MainActor () -> Bool
        if let isCurrent {
            contextIsCurrent = isCurrent
        } else {
            contextIsCurrent = accountIsCurrent
        }
        let notice = configuration.isLive
            ? WalletUX.text("Each network has its own address. Share the address of the network the sender uses.")
            : WalletUX.text("Your production address is ready to copy or share. Balances, activity, and transfers will be available when the SORA Nexus production network launches.")
        let viewModel = NexusReceiveViewModel(address: account.address, name: networkLabel(for: account.networkId), notice: notice,
                                              avatar: NexusSora2Presentation.xorImage(xorAsset), isCurrent: contextIsCurrent)
        let controller = ReceiveViewController(viewModel: viewModel)
        viewModel.view = controller
        let navigation = UINavigationController(rootViewController: controller)
        navigation.addCustomTransitioning()
        NexusSora2Presentation.present(controller, from: presenter, navigation: navigation)
    }

    /// SORA2's transaction details for a row of Recent activity.
    private func openActivity(_ id: String) {
        guard networkActionContextIsCurrent() else { return }
        let model: NexusActivityDetailsViewModel.Model
        if id.hasPrefix(NexusActivityRows.pendingPrefix) {
            guard let row = pendingRows.first(where: {
                NexusActivityRows.pendingPrefix + $0.transaction.id.uuidString == id
            }) else { return }
            model = NexusActivityDetailsViewModel.pending(row)
        } else if let transfer = history.first(where: { $0.transactionHash == id }) {
            model = NexusActivityDetailsViewModel.transfer(transfer, account: account.address)
        } else {
            return
        }
        var explorer: (@MainActor () -> Void)?
        if configuration.isLive {
            explorer = { [weak self] () -> Void in
                self?.openExplorer()
            }
        }
        let viewModel = NexusActivityDetailsViewModel(
            model: model, xorImage: xorImage,
            isCurrent: { [weak self] in self?.networkActionContextIsCurrent() ?? false },
            openExplorer: explorer)
        let controller = ActivityDetailsViewController(viewModel: viewModel)
        viewModel.view = controller
        NexusSora2Presentation.presentDetails(controller, from: self)
    }

    private func showConnectionHelp() {
        guard networkActionContextIsCurrent() else { return }
        let error = [pendingLoadError, historyLoadError].compactMap { $0 }.joined(separator: "\n\n")
        let alert = UIAlertController(title: WalletUX.text("Check connection"),
            message: WalletUX.text("Check your internet connection, then refresh. Pending transfers will be checked without sending them again."), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("Refresh"), style: .default) { [weak self] _ in self?.reload() })
        if !error.isEmpty {
            alert.addAction(UIAlertAction(title: WalletUX.text("Technical details"), style: .default) { [weak self] _ in
                self?.show(title: WalletUX.text("Technical details"), message: error)
            })
        }
        alert.addAction(UIAlertAction(title: WalletUX.text("Close"), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func send() {
        guard networkActionContextIsCurrent() else {
            return
        }
        guard mutationReady, coordinator != nil else {
            return
        }
        guard SettingsManager.shared.nexusSendsEnabled(for: configuration.networkId) else {
            show(
                title: WalletUX.text("Sends paused"),
                message: WalletUX.text("Nexus sends are temporarily disabled.")
            )
            return
        }
        let flow = NexusSendFlow(
            network: networkLabel,
            balance: balanceQuantity ?? "0",
            configuration: configuration,
            ownAddress: account.address,
            xorAsset: xorAsset
        )
        flow.onReview = { [weak self] receiver, amount in self?.reviewSend(receiver: receiver, amount: amount) }
        flow.onConfirm = { [weak self] prepared in self?.performSend(prepared) }
        flow.onActivity = { [weak self] in
            guard let self else { return }
            self.reload()
            self.tableView.layoutIfNeeded()
            if let activityItem = self.activityItem,
               let row = self.items.firstIndex(where: { $0 === activityItem }) {
                self.tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .top, animated: true)
            }
        }
        sendFlow = flow
        flow.present(from: self)
    }

    private func reviewSend(receiver: String, amount: String) {
        guard networkActionContextIsCurrent() else {
            return
        }
        guard mutationReady, let coordinator else {
            return
        }
        let quantity: PIQuantity
        do {
            try configuration.validate(address: receiver)
            quantity = try PIQuantity(amount)
        } catch {
            sendFlow?.showError(WalletUX.text("Check the recipient address and enter a valid XOR amount for this network."))
            return
        }

        setSendEntryEnabled(false)
        sendFlow?.setBusy(true)
        Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                setSendEntryEnabled(mutationReady)
                sendFlow?.setBusy(false)
            }
            do {
                let prepared = try await coordinator.prepare(
                    NexusTransferRequest(
                        walletId: account.walletId,
                        networkId: account.networkId,
                        sender: account.address,
                        receiver: receiver,
                        amount: quantity
                    ),
                    selectedAccount: selectedAccountSnapshot
                )
                guard networkActionContextIsCurrent() else {
                    return
                }
                sendFlow?.showReview(prepared)
            } catch {
                guard networkActionContextIsCurrent() else {
                    return
                }
                sendFlow?.showError(WalletUX.sendError(error))
            }
        }
    }

    private func performSend(_ prepared: NexusPreparedTransfer) {
        guard networkActionContextIsCurrent() else {
            return
        }
        guard mutationReady, let coordinator else {
            return
        }
        setSendEntryEnabled(false)
        sendFlow?.setBusy(true)
        Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                setSendEntryEnabled(mutationReady)
                sendFlow?.setBusy(false)
            }
            do {
                let transaction = try await coordinator.send(
                    prepared,
                    selectedAccount: selectedAccountSnapshot
                )
                guard networkActionContextIsCurrent() else {
                    return
                }
                sendFlow?.showResult(transaction)
                reload()
            } catch {
                guard networkActionContextIsCurrent() else {
                    return
                }
                if WalletUX.sendOutcomeNeedsChecking(error, submissionMayHaveStarted: prepared.submissionMayHaveStarted) {
                    sendFlow?.showUncertainSubmission(WalletUX.sendError(NexusToriiError.ambiguousSubmission))
                } else {
                    sendFlow?.showUnsentError(WalletUX.sendError(error))
                }
                reload()
            }
        }
    }

    /// Send stays off while a review or a send of this screen is running.
    private func setSendEntryEnabled(_ enabled: Bool) {
        guard sendEntry.isAvailable else { return }
        sendEntry.isEnabled = enabled
        renderBalance()
    }

    private func selectedAccountSnapshot() -> NetworkAccount? {
        guard
            let store = try? networkStore(),
            let snapshot = try? store.load(),
            SelectedWalletSettings.shared.currentAccount?.address ==
                account.walletId
        else {
            return nil
        }
        return snapshot.accounts.first(where: { $0.id == account.id })
    }

    private func show(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Activity rows

enum NexusActivityRows {
    static let pendingPrefix = "pending:"

    /// A finalized transfer, as SORA2 lists a transfer.
    static func history(_ item: NexusTransferHistoryItem, account: String, xorImage: UIImage?) -> ActivityContentViewModel {
        let outgoing = item.sender == account
        let type: TransferTransaction.TransferType = outgoing ? .outcoming : .incoming
        let isRTL = LocalizationManager.shared.isRightToLeft
        return ActivityContentViewModel(
            txHash: item.transactionHash,
            title: type.title,
            subtitle: outgoing ? item.receiver : item.sender,
            typeTransactionImage: type.image,
            firstAssetImageViewModel: xorImage,
            firstBalanceText: NexusSora2Presentation.amountText(
                item.amount.rawValue, incoming: !outgoing, font: FontType.textM,
                alignment: isRTL ? .left : .right),
            status: .success)
    }

    /// A send of this wallet the network has not finalized, with the
    /// status the journal keeps for it.
    static func pending(_ row: NexusPortfolioPresentationPolicy.PendingRow, xorImage: UIImage?) -> ActivityContentViewModel {
        let item = row.transaction
        let isRTL = LocalizationManager.shared.isRightToLeft
        let amount: SoramitsuTextItem
        let title: String
        switch row.kind {
        case .currentXor:
            title = TransferTransaction.TransferType.outcoming.title
            amount = NexusSora2Presentation.amountText(item.amount.rawValue, incoming: false,
                                                        font: FontType.textM, alignment: isRTL ? .left : .right)
        case .assetRecovery:
            title = WalletUX.text("Pending asset recovery")
            amount = SoramitsuTextItem(text: WalletUX.format("%@ units", item.amount.rawValue),
                                       fontData: FontType.textM, textColor: .fgPrimary,
                                       alignment: isRTL ? .left : .right)
        }
        return ActivityContentViewModel(
            txHash: pendingPrefix + item.id.uuidString,
            title: title,
            subtitle: WalletUX.status(item.state),
            typeTransactionImage: TransferTransaction.TransferType.outcoming.image,
            firstAssetImageViewModel: xorImage,
            firstBalanceText: amount,
            status: NexusSora2Presentation.status(of: item.state))
    }
}
