// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import CoreImage
import Foundation
import NexusTransferCodec
import SoraFoundation
import SoraKeystore
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

@MainActor
final class NexusNetworkDetailViewController: WalletTableViewController {
    private let account: NetworkAccount
    private let configuration: NexusNetworkConfiguration
    private let coordinator: NexusTransactionCoordinator?
    private let readClient: NexusToriiReading
    private let networkStore: () throws -> WalletNetworkStore
    private let mutationUnavailableReason: String?
    private var history: [NexusTransferHistoryItem] = []
    private var pendingRows: [NexusPortfolioPresentationPolicy.PendingRow] = []
    private var pendingLoadError: String?
    private var historyLoadError: String?
    private var balance = "Loading…"
    private var mutationReady = false
    private var sendAvailabilityMessage: String? = WalletUX.text("Checking the network and pending transfers before enabling Send.")
    private weak var sendForm: NexusSendViewController?
    private var loadTask: Task<Void, Never>?
    private var historyPageTask: Task<Void, Never>?
    private var historyCursor = NexusHistoryCursor()
    private var historyAssetDefinitionID: String?
    private var historyPageError: String?
    private var faucetTask: Task<Void, Never>?
    private var faucetButton: UIButton?
    private var faucetStatus: UILabel?
    private var faucetHasPending = false
    private var faucetRetryAfter: Date?
    private let faucetService: TairaFaucetServing
    /// Opened from the wallet's Send: show the send form once the checks
    /// below have made sending safe. Used once; a later refresh never
    /// reopens it.
    private var opensSendWhenReady: Bool

    init(
        account: NetworkAccount,
        configuration: NexusNetworkConfiguration,
        coordinator: NexusTransactionCoordinator?,
        readClient: NexusToriiReading,
        mutationUnavailableReason: String?,
        opensSendWhenReady: Bool = false,
        faucetService: TairaFaucetServing = TairaFaucetService.shared,
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
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        loadTask?.cancel()
        historyPageTask?.cancel()
        faucetTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshVisible), name: UIApplication.didBecomeActiveNotification, object: nil)
        title = WalletUX.format("XOR on %@", network.name)
        view.backgroundColor = WalletUX.page
        tableView.tableHeaderView = makeReceiveHeader()
        let access = NexusPortfolioPresentationPolicy.networkDetailAccess(
            networkId: account.networkId,
            nexusEnabled: SettingsManager.shared.nexusEnabled,
            tairaEnabled: SettingsManager.shared.isTairaEnabled,
            tairaAdmitted: NexusNetworkAdmissionPolicy
                .current.isTairaAdmitted,
            mutationCoordinatorAvailable: coordinator != nil
        )
        if access.mutationSurfaceAvailable {
            let sendButton = UIBarButtonItem(
                title: WalletUX.text("Send"),
                style: .done,
                target: self,
                action: #selector(send)
            )
            sendButton.isEnabled = false
            navigationItem.rightBarButtonItem = sendButton
        }
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(
            self,
            action: #selector(refresh),
            for: .valueChanged
        )
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
            navigationController?.popViewController(animated: false)
            return
        }
        reload()
        restoreFaucetRequest()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || navigationController?.isBeingDismissed == true {
            faucetTask?.cancel()
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

    private func reload() {
        loadTask?.cancel()
        historyPageTask?.cancel()
        historyPageTask = nil
        historyCursor = NexusHistoryCursor()
        historyAssetDefinitionID = nil
        historyPageError = nil
        setMutationReady(false)
        if !configuration.isLive {
            balance = WalletUX.text("Coming soon")
            history = []
            pendingRows = []
            sendAvailabilityMessage = WalletUX.text("Your production address is ready to copy or share. Balances, activity, and transfers will be available when the SORA Nexus production network launches.")
            refreshControl?.endRefreshing()
            tableView.reloadData()
            return
        }
        loadTask = Task { [weak self] in
            guard let self else {
                return
            }
            guard reloadContextIsCurrent() else {
                return
            }
            async let balanceResult = readCurrentNexusXorBalance(
                account: account,
                configuration: configuration,
                readClient: readClient
            )
            var loadedPending: [NexusPendingTransaction]?
            var currentXorAssetDefinitionID: String?
            if let coordinator {
                do {
                    loadedPending = try await coordinator.resumePending()
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
                    if NexusPortfolioTaskPolicy.isCancellation(error) {
                        refreshControl?.endRefreshing()
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
                balance = value.quantity.rawValue
                currentXorAssetDefinitionID = value.assetDefinitionID
                pendingRows = NexusPortfolioPresentationPolicy.pendingRows(
                    loadedPending ?? [],
                    currentXorAssetDefinitionID: currentXorAssetDefinitionID
                )
            } catch {
                if NexusPortfolioTaskPolicy.isCancellation(error) {
                    refreshControl?.endRefreshing()
                    return
                }
                guard reloadContextIsCurrent() else {
                    return
                }
                balance = "Unavailable"
                pendingRows = NexusPortfolioPresentationPolicy.pendingRows(
                    loadedPending ?? [],
                    currentXorAssetDefinitionID: nil
                )
            }
            if let currentXorAssetDefinitionID {
                do {
                    let value = try await readClient.transferHistoryPage(
                        account: account.address,
                        configuration: configuration,
                        assetDefinitionID: currentXorAssetDefinitionID,
                        cursor: nil
                    )
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    try historyCursor.accept(value)
                    history = value.items
                    historyAssetDefinitionID = currentXorAssetDefinitionID
                    historyLoadError = nil
                } catch {
                    if NexusPortfolioTaskPolicy.isCancellation(error) {
                        refreshControl?.endRefreshing()
                        return
                    }
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    history = []
                    historyLoadError =
                        "Finalized history is temporarily unavailable. No local transaction was retried."
                }
            } else {
                history = []
                historyLoadError =
                    "Finalized history is unavailable until the current XOR asset identity can be verified."
            }
            guard reloadContextIsCurrent() else {
                return
            }
            setMutationReady(
                NexusPortfolioPresentationPolicy.mutationIsReady(
                    mutationCoordinatorAvailable: coordinator != nil,
                    pendingJournalLoaded: pendingLoadError == nil,
                    containsAssetRecovery: pendingRows.contains(where: {
                        $0.kind == .assetRecovery
                    }),
                    currentXorIdentityVerified:
                        currentXorAssetDefinitionID != nil,
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
            refreshControl?.endRefreshing()
            tableView.reloadData()
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
            refreshControl?.endRefreshing()
            setMutationReady(false)
            faucetTask?.cancel()
            faucetButton?.isEnabled = false
            if presentedViewController != nil { dismiss(animated: false) }
            navigationController?.popViewController(animated: false)
            return false
        }
        return true
    }

    private func setMutationReady(_ ready: Bool) {
        mutationReady = ready
        navigationItem.rightBarButtonItem?.isEnabled = ready
        guard ready, opensSendWhenReady, view.window != nil, presentedViewController == nil else {
            return
        }
        opensSendWhenReady = false
        // The checks can finish while this screen is still being pushed.
        if let transition = navigationController?.transitionCoordinator {
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
        let directory = WalletNetworkDirectory.current
        let main = directory.mainNetwork(walletNetworks: [.sora2, account.networkId])
        return directory.tag(for: account.networkId, main: main)
            .map { "\(network.name) · \($0.title)" } ?? network.name
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
                    tableView.reloadData()
                }
            }
            do {
                let page = try await readClient.transferHistoryPage(
                    account: account.address, configuration: configuration,
                    assetDefinitionID: assetID, cursor: historyCursor.nextCursor
                )
                guard reloadContextIsCurrent() else { return }
                try historyCursor.accept(page)
                history.append(contentsOf: page.items)
            } catch {
                guard !NexusPortfolioTaskPolicy.isCancellation(error),
                      reloadContextIsCurrent() else { return }
                historyPageError = WalletUX.text("Could not load more activity. Retry, or pull down to refresh if new transfers arrived.")
            }
        }
        tableView.reloadData()
    }

    private func networkActionContextIsCurrent() -> Bool {
        // Copy, explorer and send entry points can be invoked after a retained
        // controller receives an account/feature change but before navigation
        // teardown completes. Revalidate at the action boundary as well.
        reloadContextIsCurrent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = tableView.tableHeaderView else { return }
        let size = header.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width, height: 0),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        if abs(header.frame.height - size.height) > 1 || header.frame.width != tableView.bounds.width {
            header.frame.size = CGSize(width: tableView.bounds.width, height: size.height)
            tableView.tableHeaderView = header
        }
    }

    private func makeReceiveHeader() -> UIView {
        let container = UIView(
            frame: CGRect(x: 0, y: 0, width: 1, height: 310)
        )
        let badge = UILabel()
        badge.font = .preferredFont(forTextStyle: .subheadline)
        badge.adjustsFontForContentSizeCategory = true
        badge.numberOfLines = 0
        badge.textAlignment = .center
        badge.textColor = configuration.isTestnet ? .systemOrange : .secondaryLabel
        badge.text = networkLabel

        let image = UIImageView(image: qrImage(account.address))
        image.contentMode = .scaleAspectFit

        let address = UILabel()
        address.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .monospacedSystemFont(ofSize: 13, weight: .regular))
        address.adjustsFontForContentSizeCategory = true
        address.lineBreakMode = .byCharWrapping
        address.textAlignment = .center
        address.numberOfLines = 0
        address.text = account.address

        let copy = UIButton(type: .system)
        copy.setTitle(WalletUX.text(configuration.isLive ? "Copy receive address" : "Copy address"), for: .normal)
        copy.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)

        let explorer = UIButton(type: .system)
        explorer.setTitle(WalletUX.text("Open explorer"), for: .normal)
        explorer.addTarget(self, action: #selector(openExplorer), for: .touchUpInside)
        explorer.isHidden = !configuration.isLive

        var headerViews: [UIView] = [badge, image, address, copy]
        if account.networkId == .taira, configuration.satisfiesCurrentTairaContract {
            let button = WalletUX.button("Get test XOR", primary: true) { [weak self] in
                self?.requestTestXor()
            }
            button.accessibilityIdentifier = "taira.faucet.request"
            let status = WalletUX.label(WalletUX.text("Free XOR for testing on Taira."), style: .footnote)
            status.textColor = WalletUX.secondary
            status.textAlignment = .center
            status.accessibilityIdentifier = "taira.faucet.status"
            faucetButton = button
            faucetStatus = status
            headerViews += [button, status]
        }
        headerViews.append(explorer)
        let stack = UIStackView(arrangedSubviews: headerViews)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            image.heightAnchor.constraint(equalToConstant: 170),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            copy.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            explorer.heightAnchor.constraint(greaterThanOrEqualToConstant: configuration.isLive ? 48 : 0)
        ])
        return container
    }

    private func updateFaucet(message: String? = nil, busy: Bool = false) {
        if let message { faucetStatus?.text = message }
        var style = faucetButton?.configuration
        style?.title = WalletUX.text(faucetHasPending ? "Check faucet request" : "Get test XOR")
        style?.showsActivityIndicator = busy
        faucetButton?.configuration = style
        // Keep the button tappable during a cooldown to explain when to retry.
        faucetButton?.isEnabled = !busy
        view.setNeedsLayout()
    }

    private func restoreFaucetRequest() {
        guard faucetButton != nil, faucetTask == nil else { return }
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
                faucetButton?.isEnabled = false
            }
        }
    }

    private func requestTestXor() {
        guard faucetButton != nil, faucetTask == nil, networkActionContextIsCurrent() else { return }
        if let retry = faucetRetryAfter, retry > Date() {
            updateFaucet(message: WalletUX.format("Please wait %@ seconds before requesting more test XOR.", String(Int(ceil(retry.timeIntervalSinceNow)))))
            return
        }
        updateFaucet(busy: true)
        faucetTask = Task { [weak self] in
            guard let self else { return }
            defer {
                faucetTask = nil
                if networkActionContextIsCurrent() {
                    updateFaucet()
                } else {
                    faucetButton?.isEnabled = false
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
                            self.updateFaucet(message: WalletUX.text(text), busy: true)
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
                        : "Could not get test XOR. Check your connection and try again."))
                }
            }
        }
    }

    private func qrImage(_ value: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        filter.setValue(Data(value.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        else {
            return nil
        }
        let context = CIContext()
        guard let image = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    @objc private func copyAddress() {
        guard networkActionContextIsCurrent() else {
            return
        }
        UIPasteboard.general.string = account.address
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    @objc private func openExplorer() {
        guard configuration.isLive, networkActionContextIsCurrent() else {
            return
        }
        UIApplication.shared.open(configuration.explorerURL)
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
        let form = NexusSendViewController(
            network: networkLabel,
            balance: balance
        )
        form.onReview = { [weak self] receiver, amount in self?.reviewSend(receiver: receiver, amount: amount) }
        form.onConfirm = { [weak self] prepared in self?.performSend(prepared) }
        form.onActivity = { [weak self] in
            guard let self else { return }
            self.reload()
            self.tableView.layoutIfNeeded()
            if self.tableView.numberOfSections > 1 {
                self.tableView.scrollRectToVisible(self.tableView.rectForHeader(inSection: 1), animated: true)
            }
        }
        sendForm = form
        let navigation = SoraNavigationController(rootViewController: form)
        navigation.modalPresentationStyle = .fullScreen
        present(navigation, animated: true)
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
            sendForm?.showError(WalletUX.text("Check the recipient address and enter a valid XOR amount for this network."))
            return
        }

        navigationItem.rightBarButtonItem?.isEnabled = false
        sendForm?.setBusy(true)
        Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                navigationItem.rightBarButtonItem?.isEnabled = mutationReady
                sendForm?.setBusy(false)
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
                sendForm?.showReview(prepared)
            } catch {
                guard networkActionContextIsCurrent() else {
                    return
                }
                sendForm?.showError(WalletUX.sendError(error))
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
        navigationItem.rightBarButtonItem?.isEnabled = false
        sendForm?.setBusy(true)
        Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                navigationItem.rightBarButtonItem?.isEnabled = mutationReady
                sendForm?.setBusy(false)
            }
            do {
                let transaction = try await coordinator.send(
                    prepared,
                    selectedAccount: selectedAccountSnapshot
                )
                guard networkActionContextIsCurrent() else {
                    return
                }
                sendForm?.showResult(transaction)
                reload()
            } catch {
                guard networkActionContextIsCurrent() else {
                    return
                }
                if WalletUX.sendOutcomeNeedsChecking(error, submissionMayHaveStarted: prepared.submissionMayHaveStarted) {
                    sendForm?.showUncertainSubmission(WalletUX.sendError(NexusToriiError.ambiguousSubmission))
                } else {
                    sendForm?.showUnsentError(WalletUX.sendError(error))
                }
                reload()
            }
        }
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

    override func numberOfSections(in tableView: UITableView) -> Int {
        configuration.isLive ? 3 : 1
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return pendingLoadError == nil ? pendingRows.count : 1
        default:
            return historyLoadError == nil
                ? history.count + (historyCursor.hasMore && historyAssetDefinitionID != nil ? 1 : 0)
                : 1
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        switch section {
        case 0:
            return WalletUX.text(configuration.isLive ? "Balance" : "Production network")
        case 1:
            return WalletUX.text("Pending and recent local sends")
        default:
            return WalletUX.text("Finalized network history")
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? sendAvailabilityMessage : nil
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = UITableViewCell(
            style: .subtitle,
            reuseIdentifier: nil
        )
        var content = cell.defaultContentConfiguration()
        switch indexPath.section {
        case 0:
            content.text = configuration.isLive ? "\(balance) XOR" : balance
            content.secondaryText = networkLabel
        case 1:
            if let pendingLoadError {
                content.text = WalletUX.text("Recovery required")
                content.secondaryText = WalletUX.text("Sending is paused while pending transfers are unavailable. Tap to check again.")
                content.secondaryTextProperties.numberOfLines = 0
                cell.contentConfiguration = content
                return cell
            }
            let row = pendingRows[indexPath.row]
            let item = row.transaction
            switch row.kind {
            case .currentXor:
                content.text = "\(item.amount.rawValue) XOR · \(WalletUX.status(item.state))"
            case .assetRecovery:
                content.text =
                    WalletUX.format("%@ units · Pending asset recovery", item.amount.rawValue)
            }
            content.secondaryText = WalletUX.statusDetail(item.state)
            content.secondaryTextProperties.numberOfLines = 0
        default:
            if let historyLoadError {
                content.text = WalletUX.text("History unavailable")
                content.secondaryText = WalletUX.text("Activity could not be loaded. Tap to refresh.")
                content.secondaryTextProperties.numberOfLines = 0
                cell.contentConfiguration = content
                return cell
            }
            if indexPath.row == history.count {
                content.text = WalletUX.text(historyPageTask == nil ? "Load more activity" : "Loading…")
                content.secondaryText = historyPageError
                content.secondaryTextProperties.numberOfLines = 0
                cell.contentConfiguration = content
                return cell
            }
            let item = history[indexPath.row]
            let direction = WalletUX.text(item.sender == account.address ? "Sent" : "Received")
            content.text = "\(direction) \(item.amount.rawValue) XOR · \(WalletUX.text("Completed"))"
            content.secondaryText =
                Date(timeIntervalSince1970: TimeInterval(item.timestampMilliseconds) / 1000).formatted(date: .abbreviated, time: .shortened)
            content.secondaryTextProperties.numberOfLines = 0
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard networkActionContextIsCurrent() else { return }
        if indexPath.section == 2, historyLoadError == nil,
           indexPath.row == history.count {
            loadMoreHistory()
            return
        }
        if (indexPath.section == 1 && pendingLoadError != nil) || (indexPath.section == 2 && historyLoadError != nil) {
            let error = indexPath.section == 1 ? pendingLoadError : historyLoadError
            let alert = UIAlertController(title: WalletUX.text("Check connection"),
                message: WalletUX.text("Check your internet connection, then refresh. Pending transfers will be checked without sending them again."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: WalletUX.text("Refresh"), style: .default) { [weak self] _ in self?.reload() })
            alert.addAction(UIAlertAction(title: WalletUX.text("Technical details"), style: .default) { [weak self] _ in
                self?.show(title: WalletUX.text("Technical details"), message: error ?? "")
            })
            alert.addAction(UIAlertAction(title: WalletUX.text("Close"), style: .cancel))
            present(alert, animated: true)
        } else if indexPath.section == 1, pendingRows.indices.contains(indexPath.row) {
            let transaction = pendingRows[indexPath.row].transaction
            show(title: WalletUX.status(transaction.state), message: WalletUX.statusDetail(transaction.state) +
                (transaction.hash.map { "\n\n\(WalletUX.text("Transaction ID"))\n\($0)" } ?? ""))
        } else if indexPath.section == 2, history.indices.contains(indexPath.row) {
            let transaction = history[indexPath.row]
            show(title: WalletUX.text("Transfer completed"), message:
                "\(WalletUX.text("From"))\n\(transaction.sender)\n\n\(WalletUX.text("To"))\n\(transaction.receiver)\n\n\(WalletUX.text("Transaction ID"))\n\(transaction.transactionHash)")
        }
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
