// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CoreImage
import Foundation
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

    static func portfolioSubtitle(tairaAdmitted: Bool) -> String {
        tairaAdmitted
            ? "SORA2 · Minamoto · Taira Testnet"
            : "SORA2 · Minamoto"
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
            readsAvailable: readsAvailable,
            mutationSurfaceAvailable:
                readsAvailable && mutationCoordinatorAvailable
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

private func readCurrentNexusXorBalance(
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

private enum NexusPortfolioTaskPolicy {
    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError ||
            (error as? URLError)?.code == .cancelled
    }
}

@MainActor
final class NexusPortfolioViewController: UITableViewController {
    private struct Row {
        let account: NetworkAccount
        var balance: String
        var error: String?
    }

    private let assetsProvider: AssetProviderProtocol
    private let readClient: NexusToriiReading
    private let openSora2Experience: @MainActor () -> Bool
    private let settings = SettingsManager.shared
    private var coordinator: NexusTransactionCoordinator?
    private var nexusInfrastructureError: String?
    private var rows: [Row] = []
    private var loadTask: Task<Void, Never>?

    init(
        assetsProvider: AssetProviderProtocol,
        readClient: NexusToriiReading = NexusToriiReadClient(),
        openSora2Experience: @escaping @MainActor () -> Bool = { false }
    ) {
        self.assetsProvider = assetsProvider
        self.readClient = readClient
        self.openSora2Experience = openSora2Experience
        super.init(style: .insetGrouped)
        let runtime = NexusTransactionRuntime.shared
        coordinator = runtime.coordinator
        if runtime.initializationFailed {
            nexusInfrastructureError =
                "The protected pending-transaction journal is unavailable. Receive addresses, balances, and finalized history remain read-only; Nexus sends are disabled until the journal is recovered."
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SORA Portfolio"
        view.backgroundColor = .systemGroupedBackground
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
        assetsProvider.add(observer: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Tab navigation retains this controller across wallet changes. Always
        // rebuild from the currently selected wallet before exposing receive
        // addresses, balances, pending transactions, or history again.
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
                    let snapshot = try WalletNetworkStore().load(),
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
                    .sorted {
                        Self.order($0.networkId) < Self.order($1.networkId)
                    }
                if !settings.nexusEnabled {
                    accounts.removeAll { $0.networkId != .sora2 }
                }

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
                rows[index].balance = assetsProvider
                    .getBalances(with: [WalletAssetId.xor.rawValue])
                    .first?
                    .balance
                    .stringValue ?? "—"
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
        "XOR by network"
    }

    override func tableView(
        _ tableView: UITableView,
        titleForFooterInSection section: Int
    ) -> String? {
        if rows.contains(where: { $0.account.networkId != .sora2 }) {
            return "Addresses, receives, sends, history, pending transactions, and explorers are always scoped to the network badge shown above."
        }
        return "This wallet has no master phrase available for Nexus derivation. Import its phrase explicitly to activate Minamoto and Taira; the existing SORA2 key has not been changed."
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
        configuration.text = Self.title(for: row.account.networkId)
        configuration.secondaryText = "\(row.balance) XOR\n\(Self.short(row.account.address))"
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
                    title: "SORA2",
                    account: row.account,
                    notice:
                        "Open Wallet and select XOR for SORA2 send, history, QR, and explorer actions."
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
        guard access.readsAvailable else {
            clearRowsAfterContextChange()
            return
        }
        navigationController?.pushViewController(
            NexusNetworkDetailViewController(
                account: row.account,
                configuration: configuration,
                coordinator: coordinator,
                readClient: readClient,
                mutationUnavailableReason: nexusInfrastructureError
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
            UIAlertAction(title: "Copy", style: .default) {
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
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }

    private func showError(_ error: Error) {
        showErrorMessage(error.localizedDescription)
    }

    private func showErrorMessage(_ message: String) {
        let alert = UIAlertController(
            title: "Portfolio unavailable",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private static func title(for network: NetworkId) -> String {
        switch network {
        case .sora2:
            return "SORA2 · MAINNET"
        case .minamoto:
            return "MINAMOTO · MAINNET"
        case .taira:
            return "TAIRA · TESTNET"
        }
    }

    private static func order(_ network: NetworkId) -> Int {
        switch network {
        case .sora2:
            return 0
        case .minamoto:
            return 1
        case .taira:
            return 2
        }
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
private final class NexusNetworkDetailViewController: UITableViewController {
    private let account: NetworkAccount
    private let configuration: NexusNetworkConfiguration
    private let coordinator: NexusTransactionCoordinator?
    private let readClient: NexusToriiReading
    private let mutationUnavailableReason: String?
    private var history: [NexusTransferHistoryItem] = []
    private var pendingRows: [NexusPortfolioPresentationPolicy.PendingRow] = []
    private var pendingLoadError: String?
    private var historyLoadError: String?
    private var balance = "Loading…"
    private var mutationReady = false
    private var loadTask: Task<Void, Never>?

    init(
        account: NetworkAccount,
        configuration: NexusNetworkConfiguration,
        coordinator: NexusTransactionCoordinator?,
        readClient: NexusToriiReading,
        mutationUnavailableReason: String?
    ) {
        self.account = account
        self.configuration = configuration
        self.coordinator = coordinator
        self.readClient = readClient
        self.mutationUnavailableReason = mutationUnavailableReason
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = configuration.displayName
        view.backgroundColor = .systemGroupedBackground
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
                title: "Send",
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
            setMutationReady(false)
            navigationController?.popViewController(animated: false)
            return
        }
        reload()
    }

    @objc private func refresh() {
        reload()
    }

    private func reload() {
        loadTask?.cancel()
        setMutationReady(false)
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
                    let value = try await readClient.committedXorTransfers(
                        account: account.address,
                        configuration: configuration,
                        assetDefinitionID: currentXorAssetDefinitionID
                    )
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    history = value
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
                    featureEnabled: SettingsManager.shared.nexusSendsEnabled
                )
            )
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
            navigationController?.popViewController(animated: false)
            return false
        }
        return true
    }

    private func setMutationReady(_ ready: Bool) {
        mutationReady = ready
        navigationItem.rightBarButtonItem?.isEnabled = ready
    }

    private func networkActionContextIsCurrent() -> Bool {
        // Copy, explorer and send entry points can be invoked after a retained
        // controller receives an account/feature change but before navigation
        // teardown completes. Revalidate at the action boundary as well.
        reloadContextIsCurrent()
    }

    private func makeReceiveHeader() -> UIView {
        let container = UIView(
            frame: CGRect(x: 0, y: 0, width: 1, height: 310)
        )
        let badge = UILabel()
        badge.font = .preferredFont(forTextStyle: .caption1)
        badge.textAlignment = .center
        badge.textColor = configuration.isTestnet ? .systemOrange : .systemGreen
        badge.text = configuration.isTestnet ? "TAIRA · TESTNET" : "MINAMOTO · MAINNET"

        let image = UIImageView(image: qrImage(account.address))
        image.contentMode = .scaleAspectFit

        let address = UILabel()
        address.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        address.textAlignment = .center
        address.numberOfLines = 3
        address.text = account.address

        let copy = UIButton(type: .system)
        copy.setTitle("Copy receive address", for: .normal)
        copy.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)

        let explorer = UIButton(type: .system)
        explorer.setTitle("Open explorer", for: .normal)
        explorer.addTarget(self, action: #selector(openExplorer), for: .touchUpInside)

        let stack = UIStackView(
            arrangedSubviews: [badge, image, address, copy, explorer]
        )
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            image.heightAnchor.constraint(equalToConstant: 170)
        ])
        return container
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
        guard networkActionContextIsCurrent() else {
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
        guard SettingsManager.shared.nexusSendsEnabled else {
            show(
                title: "Sends paused",
                message: "Nexus sends are temporarily disabled."
            )
            return
        }
        let alert = UIAlertController(
            title: "Send XOR · \(configuration.displayName)",
            message: "The destination must be an I105 address for this exact network. A transaction with an unknown submission result is never retried.",
            preferredStyle: .alert
        )
        alert.addTextField {
            $0.placeholder = "Recipient I105 address"
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }
        alert.addTextField {
            $0.placeholder = "Amount XOR"
            $0.keyboardType = .decimalPad
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Review", style: .default) { [weak self, weak alert] _ in
                guard
                    let self,
                    let fields = alert?.textFields,
                    fields.count == 2
                else {
                    return
                }
                self.reviewSend(
                    receiver: fields[0].text ?? "",
                    amount: fields[1].text ?? ""
                )
            }
        )
        present(alert, animated: true)
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
            show(title: "Invalid send", message: error.localizedDescription)
            return
        }

        navigationItem.rightBarButtonItem?.isEnabled = false
        Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                navigationItem.rightBarButtonItem?.isEnabled = mutationReady
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
                let confirmation = UIAlertController(
                    title: "Confirm \(configuration.displayName) send",
                    message: "Send \(prepared.request.amount.rawValue) XOR\nFee: \(prepared.quote.fee.rawValue) XOR\nAvailable: \(prepared.availableBalance.rawValue) XOR\nTo: \(prepared.canonicalReceiver)\n\nThe wallet, network, balance and quote will be checked again before signing.",
                    preferredStyle: .alert
                )
                confirmation.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                confirmation.addAction(
                    UIAlertAction(title: "Sign and send", style: .destructive) {
                        [weak self] _ in
                        self?.performSend(prepared)
                    }
                )
                present(confirmation, animated: true)
            } catch {
                guard networkActionContextIsCurrent() else {
                    return
                }
                show(title: "Send unavailable", message: error.localizedDescription)
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
        Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                navigationItem.rightBarButtonItem?.isEnabled = mutationReady
            }
            do {
                let transaction = try await coordinator.send(
                    prepared,
                    selectedAccount: selectedAccountSnapshot
                )
                guard networkActionContextIsCurrent() else {
                    return
                }
                show(
                    title: "Transaction \(transaction.state.rawValue)",
                    message: transaction.hash ?? "No transaction hash was returned."
                )
                reload()
            } catch {
                guard networkActionContextIsCurrent() else {
                    return
                }
                show(title: "Send not completed", message: error.localizedDescription)
                reload()
            }
        }
    }

    private func selectedAccountSnapshot() -> NetworkAccount? {
        guard
            let store = try? WalletNetworkStore(),
            let snapshot = try? store.load(),
            SelectedWalletSettings.shared.currentAccount?.address ==
                account.walletId
        else {
            return nil
        }
        return snapshot.accounts.first(where: { $0.id == account.id })
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        3
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
            return historyLoadError == nil ? history.count : 1
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        switch section {
        case 0:
            return "Balance"
        case 1:
            return "Pending and recent local sends"
        default:
            return "Finalized network history"
        }
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
            content.text = "\(balance) XOR"
            content.secondaryText = configuration.displayName
        case 1:
            if let pendingLoadError {
                content.text = "Recovery required"
                content.secondaryText = pendingLoadError
                content.secondaryTextProperties.numberOfLines = 0
                cell.contentConfiguration = content
                return cell
            }
            let row = pendingRows[indexPath.row]
            let item = row.transaction
            switch row.kind {
            case .currentXor:
                content.text = "\(item.amount.rawValue) XOR · \(item.state.rawValue)"
            case .assetRecovery:
                content.text =
                    "\(item.amount.rawValue) units · Pending asset recovery"
            }
            content.secondaryText = item.hash ?? "Local \(item.id.uuidString)"
            content.secondaryTextProperties.numberOfLines = 2
        default:
            if let historyLoadError {
                content.text = "History unavailable"
                content.secondaryText = historyLoadError
                content.secondaryTextProperties.numberOfLines = 0
                cell.contentConfiguration = content
                return cell
            }
            let item = history[indexPath.row]
            let direction = item.sender == account.address ? "Sent" : "Received"
            content.text = "\(direction) \(item.amount.rawValue) XOR · Finalized"
            content.secondaryText =
                "\(item.transactionHash)\n\(direction == "Sent" ? item.receiver : item.sender)"
            content.secondaryTextProperties.numberOfLines = 2
        }
        cell.contentConfiguration = content
        return cell
    }

    private func show(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
