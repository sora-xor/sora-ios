// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import Foundation
import SoraFoundation
import SoraKeystore
import UIKit

enum PolkamarktExternalLinkPolicy {
    static func validated(_ url: URL?) -> URL? {
        guard
            let url,
            url.absoluteString.utf8.count <= 2_048,
            url.scheme?.lowercased() == "https",
            url.host?.isEmpty == false,
            url.user == nil,
            url.password == nil
        else {
            return nil
        }
        return url
    }
}

enum PolkamarktPresentationPolicy {
    static func canCommitCatalogAccountState(
        featureEnabled: Bool,
        capturedAccount: String?,
        selectedAccount: String?
    ) -> Bool {
        featureEnabled && capturedAccount == selectedAccount
    }

    static func canPresentAccountDetail(
        featureEnabled: Bool,
        capturedAccount: String?,
        selectedAccount: String?
    ) -> Bool {
        canCommitCatalogAccountState(
            featureEnabled: featureEnabled,
            capturedAccount: capturedAccount,
            selectedAccount: selectedAccount
        )
    }

    static func matchesOwnerFilter(
        creator: String?,
        selectedAccount: String?,
        mineOnly: Bool
    ) -> Bool {
        guard mineOnly else {
            return true
        }
        guard let selectedAccount, !selectedAccount.isEmpty else {
            return false
        }
        // SORA account strings are case-sensitive identifiers. Never fold
        // case when deciding whether a market belongs to the selected wallet.
        return creator == selectedAccount
    }
}

private enum PolkamarktTaskPolicy {
    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError ||
            (error as? URLError)?.code == .cancelled
    }
}

enum PolkamarktPendingObservationPolicy {
    private static let backoffNanoseconds: [UInt64] = [
        2_000_000_000,
        3_000_000_000,
        5_000_000_000,
        8_000_000_000,
        13_000_000_000,
        21_000_000_000,
        30_000_000_000,
    ]

    static func delayNanoseconds(afterAttempt attempt: Int) -> UInt64 {
        backoffNanoseconds[
            min(max(0, attempt), backoffNanoseconds.count - 1)
        ]
    }

    static func requiresObservation(
        _ values: [PolkamarktPendingMutation],
        account: String
    ) -> Bool {
        !account.isEmpty && values.contains {
            $0.account == account && !$0.state.isTerminal
        }
    }
}

private enum PolkamarktL10n {
    static func pageTitle(
        _ languages: [String]? = .currentLocale
    ) -> String {
        R.string.localizable.pageTitlePolkamarkt(
            preferredLanguages: languages
        )
    }

    static func outcome(
        _ outcome: PolkamarktOutcome,
        languages: [String]? = .currentLocale
    ) -> String {
        switch outcome {
        case .yes:
            return R.string.localizable.polkamarktOutcomesYes(
                preferredLanguages: languages
            )
        case .no:
            return R.string.localizable.polkamarktOutcomesNo(
                preferredLanguages: languages
            )
        }
    }

    static func side(
        _ side: PolkamarktSide,
        languages: [String]? = .currentLocale
    ) -> String {
        switch side {
        case .buy:
            return R.string.localizable.polkamarktActionsBuy(
                preferredLanguages: languages
            )
        case .sell:
            return R.string.localizable.polkamarktActionsSell(
                preferredLanguages: languages
            )
        }
    }

    static func claimTrader(_ languages: [String]? = .currentLocale) -> String {
        R.string.localizable.polkamarktActionsClaimTraderPayout(
            preferredLanguages: languages
        )
    }

    static func claimCreator(_ languages: [String]? = .currentLocale) -> String {
        R.string.localizable.polkamarktActionsClaimCreatorFees(
            preferredLanguages: languages
        )
    }

    static func sharesOut(_ languages: [String]? = .currentLocale) -> String {
        R.string.localizable.polkamarktTicketSharesOut(
            preferredLanguages: languages
        )
    }

    static func collateralOut(
        _ languages: [String]? = .currentLocale
    ) -> String {
        R.string.localizable.polkamarktTicketCollateralOut(
            preferredLanguages: languages
        )
    }

    static func slippage(_ languages: [String]? = .currentLocale) -> String {
        R.string.localizable.polkamarktTicketSlippage(
            preferredLanguages: languages
        )
    }

    static func takerFee(_ languages: [String]? = .currentLocale) -> String {
        R.string.localizable.polkamarktTicketTakerFee(
            preferredLanguages: languages
        )
    }

    static func networkFee(_ languages: [String]? = .currentLocale) -> String {
        R.string.localizable.networkFeeText(
            preferredLanguages: languages
        )
    }
}

@MainActor
final class PolkamarktViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case activity
        case positions
        case markets
    }

    private let walletContext: CommonWalletContextProtocol
    private let client = PIIndexerClient()
    private var markets: [PIMarket] = []
    private var visibleMarkets: [PIMarket] = []
    private var positions: [PIAccountPosition] = []
    private var positionsAccount: String?
    private var positionsLoadError: String?
    private var positionsFromCache = false
    private var reviewedClaims: [UInt32: PolkamarktClaimable] = [:]
    private var claimReviewAccount: String?
    private var claimReviewFinalizedBlockHash: String?
    private var signals: PIPolkamarktSignals?
    private var marketsFromCache = false
    private var indexedDataFromCache = false
    private var selectedCategory: String?
    private var mineOnly = false
    private var loadTask: Task<Void, Never>?
    private var pendingReconciliationTask: Task<Void, Never>?
    private let searchController = UISearchController(
        searchResultsController: nil
    )

    init(walletContext: CommonWalletContextProtocol) {
        self.walletContext = walletContext
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        loadTask?.cancel()
        pendingReconciliationTask?.cancel()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pendingReconciliationTask?.cancel()
        if isMovingFromParent ||
            navigationController?.isBeingDismissed == true {
            loadTask?.cancel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = PolkamarktL10n.pageTitle()
        view.backgroundColor = .systemGroupedBackground
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Markets, categories, tags"
        searchController.searchBar.scopeButtonTitles = [
            "Active",
            "Finalized",
            "All"
        ]
        searchController.searchBar.delegate = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(
            self,
            action: #selector(refresh),
            for: .valueChanged
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard SettingsManager.shared.polkamarktEnabled else {
            loadTask?.cancel()
            navigationController?.popViewController(animated: false)
            return
        }
        // Account positions and emergency capabilities can change while this
        // retained tab is not visible. Refresh before showing account-scoped
        // catalog enrichment or claim actions again.
        reload()
    }

    @objc private func refresh() {
        reload()
    }

    private func reload() {
        loadTask?.cancel()
        pendingReconciliationTask?.cancel()
        pendingReconciliationTask = nil
        clearClaimReview()
        updateNavigationItems()
        let selectedAccount = Self.selectedAccount
        loadTask = Task { [weak self] in
            guard let self else {
                return
            }
            guard catalogContextIsCurrent(
                capturedAccount: selectedAccount
            ) else {
                handleCatalogContextChange(
                    capturedAccount: selectedAccount
                )
                return
            }
            var shouldObservePending = false
            do {
                async let marketsResult = client.qualifiedAllMarkets(
                    pageSize: 50,
                    maximumPages: 20
                )
                async let signalsResult =
                    client.qualifiedPolkamarktSignals()
                let loadedMarkets = try await marketsResult
                guard catalogContextIsCurrent(
                    capturedAccount: selectedAccount
                ) else {
                    handleCatalogContextChange(
                        capturedAccount: selectedAccount
                    )
                    return
                }
                markets = loadedMarkets.value.sorted {
                    ($0.timestamp ?? 0) > ($1.timestamp ?? 0)
                }
                let loadedSignals = try? await signalsResult
                guard catalogContextIsCurrent(
                    capturedAccount: selectedAccount
                ) else {
                    handleCatalogContextChange(
                        capturedAccount: selectedAccount
                    )
                    return
                }
                signals = loadedSignals?.value
                var qualifications = [
                    loadedMarkets.qualification,
                    loadedSignals?.qualification,
                ]
                if let account = selectedAccount {
                    let loadedPositions = try? await
                        client.qualifiedAllAccountPositions(
                            account: account,
                            pageSize: 100,
                            maximumPages: 20
                        )
                    guard catalogContextIsCurrent(
                        capturedAccount: selectedAccount
                    ) else {
                        handleCatalogContextChange(
                            capturedAccount: selectedAccount
                        )
                        return
                    }
                    positions = loadedPositions?.value ?? []
                    positionsAccount = account
                    positionsLoadError = loadedPositions == nil
                        ? "Indexed positions are unavailable."
                        : nil
                    positionsFromCache = loadedPositions?
                        .qualification?.source == .cache
                    qualifications.append(
                        loadedPositions?.qualification
                    )
                    let candidateMarketIds = claimReviewCandidateMarketIds
                    var pendingReadCompleted = false
                    do {
                        let pendingStore = try PolkamarktPendingStore()
                        let coordinator = PolkamarktTransactionCoordinator(
                            walletContext: walletContext,
                            pendingStore: pendingStore
                        )
                        let pending: [PolkamarktPendingMutation]
                        if let coordinator {
                            pending = try await
                                coordinator.reconcilePending(
                                    account: account
                                )
                        } else {
                            pending = try await pendingStore.all()
                        }
                        guard catalogContextIsCurrent(
                            capturedAccount: selectedAccount
                        ) else {
                            handleCatalogContextChange(
                                capturedAccount: selectedAccount
                            )
                            return
                        }
                        shouldObservePending =
                            PolkamarktPendingObservationPolicy
                                .requiresObservation(
                                    pending,
                                    account: account
                                )
                        pendingReadCompleted = true
                        if shouldObservePending {
                            clearClaimReview()
                        } else if
                            SettingsManager.shared
                                .polkamarktMutationsEnabled,
                            let coordinator,
                            !candidateMarketIds.isEmpty
                        {
                            let review = try await
                                coordinator.authoritativeClaimables(
                                    account: account,
                                    marketIds: candidateMarketIds
                                )
                            guard catalogContextIsCurrent(
                                capturedAccount: selectedAccount
                            ) else {
                                handleCatalogContextChange(
                                    capturedAccount: selectedAccount
                                )
                                return
                            }
                            reviewedClaims = review.claims.reduce(
                                into: [:]
                            ) { result, claim in
                                result[claim.marketId] = claim
                            }
                            claimReviewAccount = review.account
                            claimReviewFinalizedBlockHash =
                                review.finalizedBlockHash
                        } else {
                            clearClaimReview()
                        }
                    } catch {
                        if PolkamarktTaskPolicy.isCancellation(error) {
                            refreshControl?.endRefreshing()
                            return
                        }
                        // A failed status read is not terminal evidence. Only
                        // that failure starts the durable-journal retry loop;
                        // an authoritative claim-read failure stays disabled
                        // without pretending a transaction is pending.
                        shouldObservePending = !pendingReadCompleted
                        clearClaimReview()
                    }
                } else {
                    positions = []
                    positionsAccount = nil
                    positionsLoadError = nil
                    positionsFromCache = false
                    clearClaimReview()
                }
                guard catalogContextIsCurrent(
                    capturedAccount: selectedAccount
                ) else {
                    handleCatalogContextChange(
                        capturedAccount: selectedAccount
                    )
                    return
                }
                marketsFromCache =
                    loadedMarkets.qualification?.source == .cache
                indexedDataFromCache = qualifications
                    .compactMap { $0 }
                    .contains { $0.source == .cache }
                if shouldObservePending {
                    navigationItem.prompt =
                        "Pending SORA2 transaction — reconciling finalized status"
                } else {
                    navigationItem.prompt = indexedDataFromCache
                        ? "Offline PI snapshot — runtime actions still require live checks"
                        : nil
                }
                if let account = selectedAccount, shouldObservePending {
                    beginPendingReconciliation(account: account)
                }
                applyFilter()
            } catch {
                if PolkamarktTaskPolicy.isCancellation(error) {
                    refreshControl?.endRefreshing()
                    return
                }
                guard catalogContextIsCurrent(
                    capturedAccount: selectedAccount
                ) else {
                    handleCatalogContextChange(
                        capturedAccount: selectedAccount
                    )
                    return
                }
                if !markets.isEmpty {
                    // Preserve the last readable catalog for continuity, but
                    // never continue presenting it as a fresh PI response.
                    marketsFromCache = true
                    indexedDataFromCache = true
                    navigationItem.prompt =
                        "Refresh failed — displayed PI data may be stale"
                    tableView.reloadData()
                }
                if let account = selectedAccount {
                    beginPendingReconciliation(
                        account: account,
                        reloadWhenSettled: false
                    )
                }
                showError(
                    title: "Markets unavailable",
                    message: error.localizedDescription
                )
            }
            refreshControl?.endRefreshing()
        }
    }

    private func catalogContextIsCurrent(
        capturedAccount: String?
    ) -> Bool {
        guard !Task.isCancelled else {
            return false
        }
        return PolkamarktPresentationPolicy.canCommitCatalogAccountState(
            featureEnabled: SettingsManager.shared.polkamarktEnabled,
            capturedAccount: capturedAccount,
            selectedAccount: Self.selectedAccount
        )
    }

    private func canPresentCatalogMutationResult(account: String) -> Bool {
        viewIfLoaded?.window != nil &&
            PolkamarktPresentationPolicy.canCommitCatalogAccountState(
                featureEnabled: SettingsManager.shared.polkamarktEnabled,
                capturedAccount: account,
                selectedAccount: Self.selectedAccount
            )
    }

    private func handleCatalogContextChange(
        capturedAccount: String?
    ) {
        guard !Task.isCancelled else {
            return
        }
        positions = []
        positionsAccount = nil
        positionsLoadError = nil
        positionsFromCache = false
        clearClaimReview()
        applyFilter()
        refreshControl?.endRefreshing()
        guard SettingsManager.shared.polkamarktEnabled else {
            navigationController?.popViewController(animated: false)
            return
        }
        guard Self.selectedAccount != capturedAccount else {
            return
        }
        reload()
    }

    private func beginPendingReconciliation(
        account: String,
        reloadWhenSettled: Bool = true
    ) {
        pendingReconciliationTask?.cancel()
        pendingReconciliationTask = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds: PolkamarktPendingObservationPolicy
                            .delayNanoseconds(afterAttempt: attempt)
                    )
                } catch {
                    return
                }
                guard let self, self.viewIfLoaded?.window != nil else {
                    return
                }
                guard catalogContextIsCurrent(
                    capturedAccount: account
                ) else {
                    handleCatalogContextChange(
                        capturedAccount: account
                    )
                    return
                }
                do {
                    let pendingStore = try PolkamarktPendingStore()
                    let current = try await pendingStore.all()
                    let values: [PolkamarktPendingMutation]
                    if PolkamarktPendingObservationPolicy
                        .requiresObservation(current, account: account)
                    {
                        if let coordinator = PolkamarktTransactionCoordinator(
                            walletContext: walletContext,
                            pendingStore: pendingStore
                        ) {
                            values = try await coordinator.reconcilePending(
                                account: account
                            )
                        } else {
                            values = current
                        }
                    } else {
                        values = current
                    }
                    guard catalogContextIsCurrent(
                        capturedAccount: account
                    ) else {
                        handleCatalogContextChange(
                            capturedAccount: account
                        )
                        return
                    }
                    guard PolkamarktPendingObservationPolicy
                        .requiresObservation(values, account: account)
                    else {
                        pendingReconciliationTask = nil
                        if reloadWhenSettled {
                            reload()
                        }
                        return
                    }
                } catch {
                    if PolkamarktTaskPolicy.isCancellation(error) {
                        return
                    }
                    guard catalogContextIsCurrent(
                        capturedAccount: account
                    ) else {
                        handleCatalogContextChange(
                            capturedAccount: account
                        )
                        return
                    }
                    clearClaimReview()
                    updateNavigationItems()
                }
                if attempt < Int.max {
                    attempt += 1
                }
            }
        }
    }

    private func applyFilter() {
        let query = (searchController.searchBar.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let scope = searchController.searchBar.selectedScopeButtonIndex
        visibleMarkets = markets.filter { market in
            let matchesText = query.isEmpty || [
                market.title,
                market.category,
                market.tags,
                market.description,
                market.creator,
                market.status
            ]
            .compactMap { $0?.lowercased() }
            .contains(where: { $0.contains(query) })
            guard matchesText else {
                return false
            }
            let status = market.status?.lowercased() ?? ""
            let matchesStatus: Bool
            switch scope {
            case 0:
                matchesStatus = PolkamarktRuntimeContract.openStatuses
                    .contains(status)
            case 1:
                matchesStatus = PolkamarktRuntimeContract.finalizedStatuses
                    .contains(status)
            default:
                matchesStatus = true
            }
            let matchesCategory = selectedCategory == nil ||
                market.category?.caseInsensitiveCompare(
                    selectedCategory ?? ""
                ) == .orderedSame
            let matchesOwner =
                PolkamarktPresentationPolicy.matchesOwnerFilter(
                    creator: market.creator,
                    selectedAccount: Self.selectedAccount,
                    mineOnly: mineOnly
                )
            return matchesStatus && matchesCategory && matchesOwner
        }
        updateNavigationItems()
        tableView.reloadData()
    }

    private static var selectedAccount: String? {
        SelectedWalletSettings.shared.currentAccount?.address
    }

    private var displayedPositions: [PIAccountPosition] {
        guard
            let account = Self.selectedAccount,
            positionsAccount == account
        else {
            return []
        }
        return positions
    }

    private var claimReviewCandidateMarketIds: [UInt32] {
        Array(
            Set(
                displayedPositions.compactMap { position -> UInt32? in
                    guard
                        let rawMarketId = position.marketId,
                        rawMarketId >= 0
                    else {
                        return nil
                    }
                    return UInt32(exactly: rawMarketId)
                }
            )
            .sorted()
            .prefix(PolkamarktRuntimeContract.maximumBatchClaims)
        )
    }

    private func clearClaimReview() {
        reviewedClaims = [:]
        claimReviewAccount = nil
        claimReviewFinalizedBlockHash = nil
    }

    private func updateNavigationItems() {
        let filterItem = UIBarButtonItem(
            title: "Filters",
            image: nil,
            primaryAction: nil,
            menu: filterMenu()
        )
        var items = [filterItem]
        if batchClaimMarketIds.count > 1,
           SettingsManager.shared.polkamarktMutationsEnabled {
            items.append(
                UIBarButtonItem(
                    title: "Claim",
                    style: .plain,
                    target: self,
                    action: #selector(presentBatchClaim)
                )
            )
        }
        navigationItem.rightBarButtonItems = items
    }

    private func filterMenu() -> UIMenu {
        let mineAction = UIAction(
            title: "My markets",
            state: mineOnly ? .on : .off
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                mineOnly.toggle()
                applyFilter()
            }
        }
        let allCategories = UIAction(
            title: "All categories",
            state: selectedCategory == nil ? .on : .off
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.selectedCategory = nil
                self?.applyFilter()
            }
        }
        let categoryActions = PolkamarktRuntimeContract.categories.map {
            category in
            UIAction(
                title: category,
                state: selectedCategory == category ? .on : .off
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.selectedCategory = category
                    self?.applyFilter()
                }
            }
        }
        let categoryMenu = UIMenu(
            title: selectedCategory ?? "All categories",
            children: [allCategories] + categoryActions
        )
        return UIMenu(children: [mineAction, categoryMenu])
    }

    private var batchClaimMarketIds: [UInt32] {
        guard
            let account = Self.selectedAccount,
            claimReviewAccount == account,
            claimReviewFinalizedBlockHash != nil
        else {
            return []
        }
        return reviewedClaims.values
            .filter {
                $0.account == account &&
                    PolkamarktClaimValidator.hasClaimableStatus($0) &&
                    $0.claimablePayout > 0
            }
            .map(\.marketId)
            .sorted()
    }

    @objc private func presentBatchClaim() {
        guard
            SettingsManager.shared.polkamarktMutationsEnabled,
            let account = Self.selectedAccount
        else {
            return
        }
        let marketIds = batchClaimMarketIds
        guard
            marketIds.count > 1,
            let reviewedAt = claimReviewFinalizedBlockHash,
            let authorization = try?
                PolkamarktClaimValidator.reviewedTraderAuthorization(
                    claims: marketIds.compactMap { reviewedClaims[$0] },
                    account: account,
                    source: .reviewedPositions,
                    finalizedBlockHash: reviewedAt
                ),
            authorization.marketIds == marketIds
        else {
            return
        }
        let reviewedAmounts = authorization.claims.map {
            "Market \($0.marketId) · " +
                "\(PolkamarktAmountCodec.format($0.claimablePayout)) KUSD"
        }.joined(separator: "\n")
        let alert = UIAlertController(
            title: String(
                format: PolkamarktRuntimeContract
                    .ClaimConfirmation.batchTitle,
                locale: Locale.current,
                marketIds.count
            ),
            message: [
                PolkamarktRuntimeContract.ClaimConfirmation.body,
                reviewedAmounts,
                "Finalized checkpoint \(reviewedAt)",
                PolkamarktRuntimeContract.ClaimConfirmation.feeNotice
            ].joined(separator: "\n\n"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Review and sign", style: .destructive) {
                [weak self] _ in
                self?.submitBatchClaim(
                    authorization: authorization
                )
            }
        )
        present(alert, animated: true)
    }

    private func submitBatchClaim(
        authorization: PolkamarktClaimAuthorization
    ) {
        guard canPresentCatalogMutationResult(
            account: authorization.account
        ) else {
            return
        }
        clearClaimReview()
        updateNavigationItems()
        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let pendingStore = try PolkamarktPendingStore()
                guard let coordinator = PolkamarktTransactionCoordinator(
                    walletContext: walletContext,
                    pendingStore: pendingStore
                ) else {
                    throw PolkamarktRuntimeError.unavailable
                }
                let pending = try await coordinator.submitBatchClaim(
                    authorization
                )
                guard canPresentCatalogMutationResult(
                    account: authorization.account
                ) else {
                    return
                }
                showError(
                    title: "Claims submitted",
                    message: pending.extrinsicHash
                        ?? "Submission is being reconciled."
                )
                reload()
            } catch {
                guard canPresentCatalogMutationResult(
                    account: authorization.account
                ) else {
                    return
                }
                showError(
                    title: "Claims not completed",
                    message: error.localizedDescription
                )
                reload()
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }
        switch section {
        case .activity:
            return signals == nil ? 0 : 1
        case .positions:
            return max(1, displayedPositions.count)
        case .markets:
            return visibleMarkets.count
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        guard let section = Section(rawValue: section) else {
            return nil
        }
        switch section {
        case .activity:
            return "SORA2 market activity"
        case .positions:
            return "Your indexed positions"
        case .markets:
            return "Markets"
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForFooterInSection section: Int
    ) -> String? {
        switch Section(rawValue: section) {
        case .positions:
            return Self.selectedAccount == nil
                ? nil
                : "PI supplies account-wide position discovery. Open a position for finalized SORA2 state and claimability."
        case .markets:
            let provenance = indexedDataFromCache
                ? "Offline PI snapshot: discovery or history may be stale. "
                : ""
            return provenance +
                "PI supplies discovery and history. Market state, quotes, fees, claims, and every mutation are checked against the finalized SORA2 runtime immediately before signing."
        default:
            return nil
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
        guard let section = Section(rawValue: indexPath.section) else {
            return cell
        }
        switch section {
        case .activity:
            guard let signals else {
                return cell
            }
            content.text = "\(signals.activeMarkets) active · \(signals.activeAccounts) traders"
            content.secondaryText = "Volume $\(Self.shortNumber(signals.totalVolumeUsd)) · Liquidity $\(Self.shortNumber(signals.liquidityUsd))"
            cell.selectionStyle = .none
        case .positions:
            configurePositionCell(
                cell,
                content: &content,
                row: indexPath.row
            )
        case .markets:
            let market = visibleMarkets[indexPath.row]
            content.text = market.title ?? "Market #\(market.marketId ?? 0)"
            let probability = market.probability.map {
                "\(Self.percentage($0)) \(PolkamarktL10n.outcome(.yes))"
            } ?? market.priceYes.map {
                "\(Self.percent($0)) \(PolkamarktL10n.outcome(.yes))"
            } ?? "Probability unavailable"
            content.secondaryText = [
                Self.statusLabel(market.status),
                probability,
                market.liquidityUSD.map { "Liquidity \($0.rawValue)" },
                market.volumeUSD.map { "Volume \($0.rawValue)" }
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
            content.secondaryTextProperties.numberOfLines = 2
            cell.accessoryType = .disclosureIndicator
        }
        cell.contentConfiguration = content
        return cell
    }

    private func configurePositionCell(
        _ cell: UITableViewCell,
        content: inout UIListContentConfiguration,
        row: Int
    ) {
        guard Self.selectedAccount != nil else {
            content.text = "Connect a SORA2 wallet to see positions"
            cell.selectionStyle = .none
            return
        }
        guard displayedPositions.indices.contains(row) else {
            content.text = positionsLoadError ?? "No indexed positions"
            cell.selectionStyle = .none
            return
        }
        let position = displayedPositions[row]
        let resolvedMarket = market(for: position)
        content.text = resolvedMarket?.title
            ?? position.marketId.map { "Market #\($0)" }
            ?? "Unknown market"
        var details: [String] = []
        if let status = position.status, !status.isEmpty {
            details.append(status.uppercased())
        }
        if let outcome = position.outcome, let shares = position.shares {
            details.append(
                "\(outcome.uppercased()) \(shares.rawValue) shares"
            )
        } else {
            if let yesShares = position.yesShares {
                details.append(
                    "\(PolkamarktL10n.outcome(.yes)) \(yesShares.rawValue)"
                )
            }
            if let noShares = position.noShares {
                details.append(
                    "\(PolkamarktL10n.outcome(.no)) \(noShares.rawValue)"
                )
            }
        }
        if let marketValue = position.marketValueUsd {
            details.append("Value $\(marketValue.rawValue)")
        }
        if let unrealized = position.unrealizedPnlUsd {
            details.append("Unrealized P/L $\(unrealized.rawValue)")
        } else if let realized = position.realizedPnlUsd {
            details.append("Realized P/L $\(realized.rawValue)")
        }
        content.secondaryText = details.isEmpty
            ? "Indexed position details unavailable"
            : details.joined(separator: " · ")
        content.secondaryTextProperties.numberOfLines = 3
        if resolvedMarket != nil {
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.selectionStyle = .none
        }
    }

    private func market(for position: PIAccountPosition) -> PIMarket? {
        guard
            let marketId = position.marketId,
            marketId >= 0,
            UInt32(exactly: marketId) != nil
        else {
            return nil
        }
        if let loaded = markets.first(where: { $0.marketId == marketId }) {
            return loaded
        }
        guard position.market?.marketId == marketId else {
            return nil
        }
        return position.market
    }

    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else {
            return
        }
        let selectedMarket: PIMarket?
        let selectedMarketDataFromCache: Bool
        switch section {
        case .positions:
            guard displayedPositions.indices.contains(indexPath.row) else {
                return
            }
            selectedMarket = market(for: displayedPositions[indexPath.row])
            selectedMarketDataFromCache =
                marketsFromCache || positionsFromCache
        case .markets:
            guard visibleMarkets.indices.contains(indexPath.row) else {
                return
            }
            selectedMarket = visibleMarkets[indexPath.row]
            selectedMarketDataFromCache = marketsFromCache
        case .activity:
            selectedMarket = nil
            selectedMarketDataFromCache = false
        }
        guard let selectedMarket else {
            return
        }
        openMarket(
            selectedMarket,
            marketDataFromCache: selectedMarketDataFromCache
        )
    }

    private func openMarket(
        _ market: PIMarket,
        marketDataFromCache: Bool
    ) {
        do {
            let pendingStore = try PolkamarktPendingStore()
            let coordinator = PolkamarktTransactionCoordinator(
                walletContext: walletContext,
                pendingStore: pendingStore
            )
            let controller = PolkamarktMarketViewController(
                market: market,
                client: client,
                coordinator: coordinator,
                pendingStore: pendingStore,
                account: SelectedWalletSettings.shared.currentAccount?.address,
                marketDataFromCache: marketDataFromCache
            )
            controller.localizationManager = localizationManager
            navigationController?.pushViewController(controller, animated: true)
        } catch {
            showError(
                title: "Market unavailable",
                message: error.localizedDescription
            )
        }
    }

    private func showError(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private static func statusLabel(_ status: String?) -> String? {
        guard let status, !status.isEmpty else {
            return nil
        }
        return status.uppercased()
    }

    private static func shortNumber(_ quantity: PIQuantity) -> String {
        guard let decimal = Decimal(
            string: quantity.rawValue,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            return quantity.rawValue
        }
        let value = NSDecimalNumber(decimal: decimal)
        let absolute = value.compare(NSDecimalNumber.zero) == .orderedAscending
            ? value.multiplying(by: NSDecimalNumber(value: -1))
            : value
        let million = NSDecimalNumber(value: 1_000_000)
        let thousand = NSDecimalNumber(value: 1_000)
        if absolute.compare(million) != .orderedAscending {
            return "\(formatted(value.dividing(by: million), digits: 1))M"
        }
        if absolute.compare(thousand) != .orderedAscending {
            return "\(formatted(value.dividing(by: thousand), digits: 1))K"
        }
        return formatted(value, digits: 2)
    }

    private static func percent(_ quantity: PIQuantity) -> String {
        guard let decimal = Decimal(
            string: quantity.rawValue,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            return quantity.rawValue
        }
        let scaled = NSDecimalNumber(decimal: decimal).multiplying(
            by: NSDecimalNumber(value: 100)
        )
        return formatted(scaled, digits: 1) + "%"
    }

    private static func percentage(_ quantity: PIQuantity) -> String {
        guard let decimal = Decimal(
            string: quantity.rawValue,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            return quantity.rawValue
        }
        return formatted(NSDecimalNumber(decimal: decimal), digits: 1) + "%"
    }

    private static func formatted(
        _ value: NSDecimalNumber,
        digits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = digits
        return formatter.string(from: value) ?? value.stringValue
    }
}

extension PolkamarktViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applyFilter()
    }
}

extension PolkamarktViewController: Localizable {
    func applyLocalization() {
        title = PolkamarktL10n.pageTitle(
            localizationManager?.preferredLocalizations
        )
        guard isViewLoaded else {
            return
        }
        updateNavigationItems()
        tableView.reloadData()
    }
}

extension PolkamarktViewController: UISearchBarDelegate {
    func searchBar(
        _ searchBar: UISearchBar,
        selectedScopeButtonIndexDidChange selectedScope: Int
    ) {
        applyFilter()
    }
}

@MainActor
private final class PolkamarktMarketViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case overview
        case position
        case trades
        case pending
        case links
    }

    private let market: PIMarket
    private let client: PIIndexerClient
    private let coordinator: PolkamarktTransactionCoordinator?
    private let pendingStore: PolkamarktPendingStore
    private let account: String?
    private var state: PolkamarktMarketState?
    private var claimable: PolkamarktClaimable?
    private var runtimeReviewFinalizedBlockHash: String?
    private var runtimeReviewLoadError: String?
    private var trades: [PIAccountTrade] = []
    private var pending: [PolkamarktPendingMutation] = []
    private var pendingLoadError: String?
    private var hasOtherMarketPending = false
    private var mutationAdmissionAvailable = false
    private var snapshots: [PIMarketSnapshot] = []
    private var snapshotLoadError: String?
    private var tradesLoadError: String?
    private var links: [(String, URL)] = []
    private var loadTask: Task<Void, Never>?
    private var pendingReconciliationTask: Task<Void, Never>?
    private var quoteTask: Task<Void, Never>?
    private var quoteRequestID: UUID?
    private let marketDataFromCache: Bool
    private var indexedDataFromCache: Bool

    init(
        market: PIMarket,
        client: PIIndexerClient,
        coordinator: PolkamarktTransactionCoordinator?,
        pendingStore: PolkamarktPendingStore,
        account: String?,
        marketDataFromCache: Bool
    ) {
        self.market = market
        self.client = client
        self.coordinator = coordinator
        self.pendingStore = pendingStore
        self.account = account
        self.marketDataFromCache = marketDataFromCache
        indexedDataFromCache = marketDataFromCache
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        loadTask?.cancel()
        pendingReconciliationTask?.cancel()
        quoteTask?.cancel()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pendingReconciliationTask?.cancel()
        quoteTask?.cancel()
        quoteTask = nil
        quoteRequestID = nil
        if isMovingFromParent ||
            navigationController?.isBeingDismissed == true {
            loadTask?.cancel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = market.title ?? PolkamarktL10n.pageTitle()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Trade",
            style: .done,
            target: self,
            action: #selector(trade)
        )
        navigationItem.rightBarButtonItem?.isEnabled = false
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(
            self,
            action: #selector(refresh),
            for: .valueChanged
        )
        links = [
            ("Rules", market.rulesUri),
            ("Resolution source", URL(string: market.resolutionSource ?? "")),
            ("Resolution evidence", market.resolutionEvidenceUri),
            ("Cancellation evidence", market.cancellationEvidenceUri),
            ("Governance", market.governanceUrl)
        ].compactMap { title, url in
            PolkamarktExternalLinkPolicy.validated(url).map {
                (title, $0)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard PolkamarktPresentationPolicy.canPresentAccountDetail(
            featureEnabled: SettingsManager.shared.polkamarktEnabled,
            capturedAccount: account,
            selectedAccount:
                SelectedWalletSettings.shared.currentAccount?.address
        )
        else {
            // Position, trade, pending, and claim state is bound to the account
            // captured when this detail was opened. Return to the catalog when
            // that identity changes instead of displaying stale wallet data.
            loadTask?.cancel()
            navigationController?.popViewController(animated: false)
            return
        }
        reload()
    }

    @objc private func refresh() {
        reload()
    }

    private var marketId: UInt32? {
        guard
            let raw = market.marketId,
            raw >= 0,
            let value = UInt32(exactly: raw)
        else {
            return nil
        }
        return value
    }

    private func reload() {
        loadTask?.cancel()
        pendingReconciliationTask?.cancel()
        pendingReconciliationTask = nil
        quoteTask?.cancel()
        quoteTask = nil
        quoteRequestID = nil
        state = nil
        claimable = nil
        runtimeReviewFinalizedBlockHash = nil
        runtimeReviewLoadError = nil
        mutationAdmissionAvailable = false
        navigationItem.rightBarButtonItem?.isEnabled = false
        tableView.reloadData()
        loadTask = Task { [weak self] in
            guard let self, let marketId else {
                return
            }
            guard reloadContextIsCurrent() else {
                return
            }
            var shouldObservePending = false
            if let coordinator {
                do {
                    let review = try await
                        coordinator.authoritativeMarketReview(
                            account: account,
                            marketId: marketId
                        )
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    state = review.state
                    claimable = review.claimable
                    runtimeReviewFinalizedBlockHash =
                        review.finalizedBlockHash
                    runtimeReviewLoadError = nil
                } catch {
                    if PolkamarktTaskPolicy.isCancellation(error) {
                        refreshControl?.endRefreshing()
                        return
                    }
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    state = nil
                    claimable = nil
                    runtimeReviewFinalizedBlockHash = nil
                    runtimeReviewLoadError =
                        "Finalized SORA2 market state is unavailable."
                }
            } else {
                runtimeReviewLoadError =
                    "Finalized SORA2 market state is unavailable."
            }
            var qualifications: [PIReadQualification?] = []
            do {
                let snapshotRead =
                    try await client.qualifiedAllMarketSnapshots(
                        marketId: Int(marketId),
                        pageSize: 100,
                        maximumPages: 20
                    )
                guard reloadContextIsCurrent() else {
                    return
                }
                snapshots = snapshotRead.value
                snapshotLoadError = nil
                qualifications.append(snapshotRead.qualification)
            } catch {
                if PolkamarktTaskPolicy.isCancellation(error) {
                    refreshControl?.endRefreshing()
                    return
                }
                guard reloadContextIsCurrent() else {
                    return
                }
                snapshots = []
                snapshotLoadError =
                    "Indexed probability history is unavailable."
            }
            if let account {
                do {
                    let accountTrades =
                        try await client.qualifiedAllAccountTrades(
                            account: account,
                            pageSize: 100,
                            maximumPages: 20
                        )
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    trades = accountTrades.value.filter {
                        $0.includesMarket(marketId)
                    }
                    tradesLoadError = nil
                    qualifications.append(
                        accountTrades.qualification
                    )
                } catch {
                    if PolkamarktTaskPolicy.isCancellation(error) {
                        refreshControl?.endRefreshing()
                        return
                    }
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    trades = []
                    tradesLoadError =
                        "Indexed trade history is unavailable."
                }
                do {
                    let durableValues = try await pendingStore.all()
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    applyPendingOverlay(
                        durableValues,
                        account: account,
                        marketId: marketId
                    )
                    tableView.reloadData()
                    let pendingValues: [PolkamarktPendingMutation]
                    if let coordinator {
                        pendingValues = try await coordinator.reconcilePending(
                            account: account
                        )
                    } else {
                        pendingValues = durableValues
                    }
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    applyPendingOverlay(
                        pendingValues,
                        account: account,
                        marketId: marketId
                    )
                    shouldObservePending =
                        PolkamarktPendingObservationPolicy
                            .requiresObservation(
                                pendingValues,
                                account: account
                            )
                    pendingLoadError = nil
                } catch {
                    if PolkamarktTaskPolicy.isCancellation(error) {
                        refreshControl?.endRefreshing()
                        return
                    }
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    mutationAdmissionAvailable = false
                    shouldObservePending = true
                    pendingLoadError =
                        "The protected pending-transaction journal or its finalized checkpoint is unavailable. Mutations are disabled until recovery succeeds."
                }
            } else {
                trades = []
                tradesLoadError = nil
                pending = []
                pendingLoadError = nil
                hasOtherMarketPending = false
                mutationAdmissionAvailable = false
            }
            guard reloadContextIsCurrent() else {
                return
            }
            indexedDataFromCache = marketDataFromCache ||
                qualifications
                    .compactMap { $0 }
                    .contains { $0.source == .cache }
            if shouldObservePending {
                navigationItem.prompt =
                    "Pending SORA2 transaction — reconciling finalized status"
            } else {
                navigationItem.prompt = indexedDataFromCache
                    ? "Offline PI snapshot — runtime actions still require live checks"
                    : nil
            }
            navigationItem.rightBarButtonItem?.isEnabled =
                coordinator != nil &&
                account != nil &&
                state?.finalizedStatus == .open &&
                runtimeReviewFinalizedBlockHash != nil &&
                mutationAdmissionAvailable &&
                pendingLoadError == nil &&
                SettingsManager.shared.polkamarktMutationsEnabled
            if shouldObservePending {
                beginPendingReconciliation()
            }
            updateChart()
            refreshControl?.endRefreshing()
            tableView.reloadData()
        }
    }

    private func applyPendingOverlay(
        _ values: [PolkamarktPendingMutation],
        account: String,
        marketId: UInt32
    ) {
        mutationAdmissionAvailable = values.allSatisfy {
            $0.account != account || $0.state.isTerminal
        }
        pending = values
            .filter {
                $0.account == account && $0.marketIds.contains(marketId)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        hasOtherMarketPending = values.contains {
            $0.account == account &&
                !$0.state.isTerminal &&
                !$0.marketIds.contains(marketId)
        }
    }

    private func beginPendingReconciliation() {
        pendingReconciliationTask?.cancel()
        guard let account else {
            pendingReconciliationTask = nil
            return
        }
        pendingReconciliationTask = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds: PolkamarktPendingObservationPolicy
                            .delayNanoseconds(afterAttempt: attempt)
                    )
                } catch {
                    return
                }
                guard let self, self.viewIfLoaded?.window != nil else {
                    return
                }
                guard reloadContextIsCurrent() else {
                    return
                }
                do {
                    let current = try await pendingStore.all()
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    if let marketId {
                        applyPendingOverlay(
                            current,
                            account: account,
                            marketId: marketId
                        )
                        tableView.reloadData()
                    }
                    let values: [PolkamarktPendingMutation]
                    if PolkamarktPendingObservationPolicy
                        .requiresObservation(current, account: account),
                       let coordinator {
                        values = try await coordinator.reconcilePending(
                            account: account
                        )
                    } else {
                        values = current
                    }
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    let shouldContinue =
                        PolkamarktPendingObservationPolicy
                            .requiresObservation(
                                values,
                                account: account
                            )
                    if let marketId {
                        applyPendingOverlay(
                            values,
                            account: account,
                            marketId: marketId
                        )
                    }
                    pendingLoadError = nil
                    navigationItem.prompt = shouldContinue
                        ? "Pending SORA2 transaction — reconciling finalized status"
                        : nil
                    tableView.reloadData()
                    guard shouldContinue else {
                        pendingReconciliationTask = nil
                        reload()
                        return
                    }
                } catch {
                    if PolkamarktTaskPolicy.isCancellation(error) {
                        return
                    }
                    guard reloadContextIsCurrent() else {
                        return
                    }
                    mutationAdmissionAvailable = false
                    pendingLoadError =
                        "Pending status is temporarily unavailable. The protected journal is retained and reconciliation will retry."
                    navigationItem.rightBarButtonItem?.isEnabled = false
                    navigationItem.prompt =
                        "Pending SORA2 transaction — recovery retry scheduled"
                    tableView.reloadData()
                }
                if attempt < Int.max {
                    attempt += 1
                }
            }
        }
    }

    private func reloadContextIsCurrent() -> Bool {
        guard !Task.isCancelled else {
            return false
        }
        guard accountContextIsCurrent() else {
            refreshControl?.endRefreshing()
            navigationController?.popViewController(animated: false)
            return false
        }
        return true
    }

    private func accountContextIsCurrent() -> Bool {
        PolkamarktPresentationPolicy.canPresentAccountDetail(
            featureEnabled: SettingsManager.shared.polkamarktEnabled,
            capturedAccount: account,
            selectedAccount:
                SelectedWalletSettings.shared.currentAccount?.address
        )
    }

    private func canPresentAccountScopedResult() -> Bool {
        viewIfLoaded?.window != nil && accountContextIsCurrent()
    }

    private func updateChart() {
        let chart = PolkamarktLineChartView(
            frame: CGRect(x: 0, y: 0, width: 1, height: 180)
        )
        if Self.isDPMMarket(state: state, market: market) {
            let points = Self.dpmPricingCurve()
            chart.caption = state == nil
                ? "Indexed DPM curve · \(PolkamarktL10n.outcome(.yes)) / \(PolkamarktL10n.outcome(.no))"
                : "Finalized DPM state · \(PolkamarktL10n.outcome(.yes)) / \(PolkamarktL10n.outcome(.no))"
            chart.values = points.map { $0.yesQuote }
            chart.secondaryValues = points.map { $0.noQuote }
            if let state {
                chart.markerFraction =
                    Double(state.impliedYesProbabilityBps) / 10_000.0
            } else if let marginalYesPriceBps = market.marginalYesPriceBps {
                chart.markerFraction = Double(marginalYesPriceBps) / 10_000.0
            } else if let priceYes = market.priceYes {
                chart.markerFraction = priceYes.unitIntervalDoubleForRendering
            } else {
                chart.markerFraction =
                    market.probability?.percentageFractionForRendering
            }
        } else {
            chart.caption = snapshotLoadError ??
                "\(PolkamarktL10n.outcome(.yes)) probability history"
            chart.values = snapshots.compactMap { snapshot in
                snapshot.priceYes?.unitIntervalDoubleForRendering ??
                    snapshot.probability?.percentageFractionForRendering
            }
        }
        tableView.tableHeaderView = chart
    }

    private static func isDPMMarket(
        state: PolkamarktMarketState?,
        market: PIMarket
    ) -> Bool {
        let mechanism = (state?.mechanism ?? market.mechanism ?? "")
            .replacingOccurrences(
                of: #"[_\s-]"#,
                with: "",
                options: .regularExpression
            )
            .lowercased()
        if mechanism == "dynamicparimutuel" {
            return true
        }
        if !mechanism.isEmpty {
            return false
        }
        return market.virtualDepth != nil ||
            market.dpmCollateral != nil ||
            market.realYesShares != nil ||
            market.realNoShares != nil ||
            market.marginalYesPriceBps != nil ||
            market.marginalNoPriceBps != nil
    }

    private static func dpmPricingCurve() -> [
        (yesQuote: Double, noQuote: Double)
    ] {
        (1 ... PolkamarktRuntimeContract.dpmCurvePointCount).map { percent in
            let yesShare = Double(percent) / 100
            let noShare = 1 - yesShare
            let denominator = sqrt(
                yesShare * yesShare + noShare * noShare
            )
            return (
                yesQuote: yesShare / denominator,
                noQuote: noShare / denominator
            )
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }
        switch section {
        case .overview:
            return 6
        case .position:
            return claimable == nil ? 1 : 3
        case .trades:
            return max(1, trades.count)
        case .pending:
            return max(1, pending.count)
        case .links:
            return links.count
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        guard let section = Section(rawValue: section) else {
            return nil
        }
        switch section {
        case .overview:
            return "Finalized runtime state and indexed activity"
        case .position:
            return "Your position and claims"
        case .trades:
            return "Your indexed trades"
        case .pending:
            return "Pending overlay"
        case .links:
            return "Rules and evidence"
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForFooterInSection section: Int
    ) -> String? {
        guard Section(rawValue: section) == .overview else {
            return nil
        }
        return market.description
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = UITableViewCell(
            style: .value1,
            reuseIdentifier: nil
        )
        guard let section = Section(rawValue: indexPath.section) else {
            return cell
        }
        switch section {
        case .overview:
            configureOverview(cell, row: indexPath.row)
        case .position:
            configurePosition(cell, row: indexPath.row)
        case .trades:
            configureTrades(cell, row: indexPath.row)
        case .pending:
            configurePending(cell, row: indexPath.row)
        case .links:
            cell.textLabel?.text = links[indexPath.row].0
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    private func configureOverview(_ cell: UITableViewCell, row: Int) {
        let yesBps = state?.marginalYesPriceBps
        let noBps = state?.marginalNoPriceBps
        let values: [(String, String)] = [
            (
                "Status",
                state?.finalizedStatus?.rawValue.uppercased()
                    ?? "—"
            ),
            (
                PolkamarktL10n.outcome(.yes).uppercased(),
                Self.basisPoints(yesBps)
            ),
            (
                PolkamarktL10n.outcome(.no).uppercased(),
                Self.basisPoints(noBps)
            ),
            (
                "Indexed liquidity",
                market.liquidityUSD?.rawValue ?? "—"
            ),
            (
                "Indexed volume",
                market.volumeUSD?.rawValue ?? "—"
            ),
            ("Mechanism", state?.mechanism ?? "—")
        ]
        cell.textLabel?.text = values[row].0
        cell.detailTextLabel?.text = values[row].1
        cell.selectionStyle = .none
    }

    private func configurePosition(_ cell: UITableViewCell, row: Int) {
        guard let claimable else {
            cell.textLabel?.text = account == nil
                ? "Connect a SORA2 wallet to see positions"
                : runtimeReviewLoadError ??
                    "No finalized runtime position"
            cell.textLabel?.numberOfLines = 0
            cell.selectionStyle = .none
            return
        }
        switch row {
        case 0:
            cell.textLabel?.text =
                "\(PolkamarktL10n.outcome(.yes)) shares"
            cell.detailTextLabel?.text =
                PolkamarktAmountCodec.format(claimable.yesShares)
        case 1:
            cell.textLabel?.text =
                "\(PolkamarktL10n.outcome(.no)) shares"
            cell.detailTextLabel?.text =
                PolkamarktAmountCodec.format(claimable.noShares)
        default:
            cell.textLabel?.text = "Claimable"
            cell.detailTextLabel?.text =
                PolkamarktAmountCodec.format(claimable.claimablePayout)
            if
                PolkamarktClaimValidator.hasClaimableStatus(claimable),
                mutationAdmissionAvailable,
                claimable.claimablePayout > 0 || claimable.creatorFees > 0
            {
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.selectionStyle = .none
            }
        }
    }

    private func configureTrades(_ cell: UITableViewCell, row: Int) {
        guard !trades.isEmpty else {
            cell.textLabel?.text =
                tradesLoadError ?? "No indexed trades"
            cell.textLabel?.numberOfLines = 0
            cell.selectionStyle = .none
            return
        }
        let trade = trades[row]
        var labels = [
            trade.side?.uppercased(),
            trade.outcome?.uppercased()
        ].compactMap { $0 }
        if let marketIds = trade.marketIds, marketIds.count > 1 {
            labels.append("\(marketIds.count) MARKETS")
        }
        cell.textLabel?.text = labels.joined(separator: " · ")
        cell.detailTextLabel?.text = trade.shares?.rawValue
            ?? trade.collateralUsd?.rawValue
            ?? "—"
        cell.selectionStyle = .none
    }

    private func configurePending(_ cell: UITableViewCell, row: Int) {
        if let pendingLoadError, pending.isEmpty {
            cell.textLabel?.text = "Recovery required"
            cell.detailTextLabel?.text = pendingLoadError
            cell.detailTextLabel?.numberOfLines = 0
            cell.selectionStyle = .none
            return
        }
        guard !pending.isEmpty else {
            cell.textLabel?.text = hasOtherMarketPending
                ? "Another Polkamarkt transaction is pending"
                : "No pending transaction"
            if hasOtherMarketPending {
                cell.detailTextLabel?.text =
                    "New mutations remain disabled until it reaches finality."
                cell.detailTextLabel?.numberOfLines = 0
            }
            cell.selectionStyle = .none
            return
        }
        let mutation = pending[row]
        cell.textLabel?.text = mutation.action
        let durableStatusDetails = [
            mutation.state.rawValue,
            pendingLoadError,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
        cell.detailTextLabel?.text = durableStatusDetails
        cell.detailTextLabel?.numberOfLines = 0
        cell.selectionStyle = .none
    }

    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else {
            return
        }
        switch section {
        case .links:
            UIApplication.shared.open(links[indexPath.row].1)
        case .position where indexPath.row == 2:
            presentClaims()
        default:
            break
        }
    }

    @objc private func trade() {
        guard SettingsManager.shared.polkamarktMutationsEnabled else {
            show(
                title: "Trading paused",
                message: "Polkamarkt transactions are temporarily disabled."
            )
            return
        }
        guard
            let marketId,
            coordinator != nil,
            account != nil,
            state?.finalizedStatus == .open,
            runtimeReviewFinalizedBlockHash != nil,
            mutationAdmissionAvailable
        else {
            show(
                title: "Trading unavailable",
                message: "Select a SORA2 wallet and refresh finalized market state."
            )
            return
        }
        let alert = UIAlertController(
            title: "Market #\(marketId)",
            message: "Choose a side and outcome.",
            preferredStyle: .actionSheet
        )
        for side in [PolkamarktSide.buy, .sell] {
            for outcome in PolkamarktOutcome.allCases {
                alert.addAction(
                    UIAlertAction(
                        title: "\(PolkamarktL10n.side(side)) \(PolkamarktL10n.outcome(outcome))",
                        style: .default
                    ) { [weak self] _ in
                        self?.presentTradeInput(side: side, outcome: outcome)
                    }
                )
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.barButtonItem =
            navigationItem.rightBarButtonItem
        present(alert, animated: true)
    }

    private func presentTradeInput(
        side: PolkamarktSide,
        outcome: PolkamarktOutcome
    ) {
        let localizedOutcome = PolkamarktL10n.outcome(outcome)
        let inputName = side == .buy
            ? "KUSD"
            : "\(localizedOutcome) shares"
        let alert = UIAlertController(
            title: "\(PolkamarktL10n.side(side)) \(localizedOutcome)",
            message: "Enter \(inputName). The quote will be refreshed from finalized runtime state.",
            preferredStyle: .alert
        )
        alert.addTextField {
            $0.placeholder = "Amount"
            $0.keyboardType = .decimalPad
        }
        alert.addTextField {
            $0.placeholder = "\(PolkamarktL10n.slippage()) %"
            $0.keyboardType = .decimalPad
            $0.text = Self.slippagePercent(
                PolkamarktRuntimeContract.defaultSlippageBasisPoints
            )
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Get quote", style: .default) {
                [weak self, weak alert] _ in
                guard let fields = alert?.textFields, fields.count == 2 else {
                    return
                }
                self?.loadQuote(
                    side: side,
                    outcome: outcome,
                    amount: fields[0].text ?? "",
                    slippage: fields[1].text ?? ""
                )
            }
        )
        present(alert, animated: true)
    }

    private func loadQuote(
        side: PolkamarktSide,
        outcome: PolkamarktOutcome,
        amount: String,
        slippage: String
    ) {
        guard
            let marketId,
            let coordinator,
            let account,
            mutationAdmissionAvailable,
            canPresentAccountScopedResult()
        else {
            return
        }
        do {
            let input = try PolkamarktAmountCodec.parse(amount)
            let slippageBps = try Self.slippageBasisPoints(slippage)
            navigationItem.rightBarButtonItem?.isEnabled = false
            quoteTask?.cancel()
            let requestID = UUID()
            quoteRequestID = requestID
            quoteTask = Task { [weak self] in
                guard let self else {
                    return
                }
                defer {
                    if quoteRequestID == requestID {
                        quoteTask = nil
                        quoteRequestID = nil
                        if canPresentAccountScopedResult() {
                            navigationItem.rightBarButtonItem?.isEnabled =
                                self.coordinator != nil &&
                                self.account != nil &&
                                self.state?.finalizedStatus == .open &&
                                self.runtimeReviewFinalizedBlockHash != nil &&
                                self.mutationAdmissionAvailable &&
                                self.pendingLoadError == nil &&
                                SettingsManager.shared
                                    .polkamarktMutationsEnabled
                        }
                    }
                }
                do {
                    let quote = try await coordinator.quote(
                        account: account,
                        marketId: marketId,
                        outcome: outcome,
                        side: side,
                        input: input,
                        slippageBasisPoints: slippageBps
                    )
                    guard
                        !Task.isCancelled,
                        quoteRequestID == requestID,
                        canPresentAccountScopedResult()
                    else {
                        return
                    }
                    confirmTrade(
                        account: account,
                        marketId: marketId,
                        outcome: outcome,
                        side: side,
                        quote: quote
                    )
                } catch {
                    if PolkamarktTaskPolicy.isCancellation(error) {
                        return
                    }
                    guard
                        quoteRequestID == requestID,
                        canPresentAccountScopedResult()
                    else {
                        return
                    }
                    show(title: "Quote unavailable", message: error.localizedDescription)
                }
            }
        } catch {
            show(title: "Invalid amount", message: error.localizedDescription)
        }
    }

    private func confirmTrade(
        account: String,
        marketId: UInt32,
        outcome: PolkamarktOutcome,
        side: PolkamarktSide,
        quote: PolkamarktQuoteConfirmation
    ) {
        let localizedOutcome = PolkamarktL10n.outcome(outcome)
        let localizedSide = PolkamarktL10n.side(side)
        let inputAsset = side == .buy
            ? "KUSD"
            : "\(localizedOutcome) shares"
        let outputAsset = side == .buy
            ? "\(localizedOutcome) shares"
            : "KUSD"
        let outputLabel = side == .buy
            ? PolkamarktL10n.sharesOut()
            : PolkamarktL10n.collateralOut()
        let alert = UIAlertController(
            title: "Confirm \(localizedSide) \(localizedOutcome)",
            message: [
                "Input: \(PolkamarktAmountCodec.format(quote.input)) \(inputAsset)",
                "\(outputLabel): \(PolkamarktAmountCodec.format(quote.output)) \(outputAsset)",
                "Minimum received: \(PolkamarktAmountCodec.format(quote.minimumOutput)) \(outputAsset)",
                "\(PolkamarktL10n.takerFee()): \(PolkamarktAmountCodec.format(quote.marketFee))",
                "\(PolkamarktL10n.networkFee()): \(PolkamarktAmountCodec.format(quote.networkFee)) XOR",
                "Available: \(PolkamarktAmountCodec.format(quote.inputBalance)) \(inputAsset)",
                "XOR available: \(PolkamarktAmountCodec.format(quote.xorBalance)) XOR",
                "Authoritative status: \(quote.marketStatus.rawValue)",
                "Closes at block: \(quote.closeBlock)",
                "The quote, wallet, balances, fee, runtime identity, and market status will be checked again before signing."
            ].joined(separator: "\n"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Sign trade", style: .destructive) {
                [weak self] _ in
                self?.submitTrade(
                    PolkamarktTradeRequest(
                        account: account,
                        marketId: marketId,
                        outcome: outcome,
                        side: side,
                        input: quote.input,
                        minimumOutput: quote.minimumOutput,
                        confirmedCloseBlock: quote.closeBlock,
                        confirmedMarketFee: quote.marketFee,
                        maximumNetworkFee: quote.networkFee
                    )
                )
            }
        )
        present(alert, animated: true)
    }

    private func submitTrade(_ request: PolkamarktTradeRequest) {
        guard
            let coordinator,
            let account,
            request.account == account,
            canPresentAccountScopedResult(),
            SettingsManager.shared.polkamarktMutationsEnabled
        else {
            return
        }
        mutationAdmissionAvailable = false
        navigationItem.rightBarButtonItem?.isEnabled = false
        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let pending = try await coordinator.submitTrade(request)
                guard canPresentAccountScopedResult() else {
                    return
                }
                show(
                    title: "Trade submitted",
                    message: pending.extrinsicHash
                        ?? "Submission is being reconciled."
                )
                reload()
            } catch {
                guard canPresentAccountScopedResult() else {
                    return
                }
                show(
                    title: "Trade not completed",
                    message: error.localizedDescription
                )
                reload()
            }
        }
    }

    private func presentClaims() {
        guard
            SettingsManager.shared.polkamarktMutationsEnabled,
            mutationAdmissionAvailable,
            pendingLoadError == nil
        else {
            show(
                title: "Claims paused",
                message: "Polkamarkt transactions are disabled until pending recovery and live checks complete."
            )
            return
        }
        guard
            let claimable,
            let account,
            let marketId,
            let coordinator,
            let reviewedAt = runtimeReviewFinalizedBlockHash,
            claimable.marketId == marketId,
            PolkamarktClaimValidator.hasClaimableStatus(claimable)
        else {
            return
        }
        var reviewedAmounts: [String] = []
        if claimable.claimablePayout > 0 {
            reviewedAmounts.append(
                "Trader payout · " +
                    "\(PolkamarktAmountCodec.format(claimable.claimablePayout)) KUSD"
            )
        }
        if claimable.isCreator, claimable.creatorFees > 0 {
            reviewedAmounts.append(
                "Creator fees · " +
                    "\(PolkamarktAmountCodec.format(claimable.creatorFees)) KUSD"
            )
        }
        let alert = UIAlertController(
            title: PolkamarktRuntimeContract.ClaimConfirmation.title,
            message: [
                PolkamarktRuntimeContract.ClaimConfirmation.body,
                reviewedAmounts.joined(separator: "\n"),
                "Finalized checkpoint \(reviewedAt)",
                PolkamarktRuntimeContract.ClaimConfirmation.feeNotice
            ].joined(separator: "\n\n"),
            preferredStyle: .alert
        )
        if
            claimable.claimablePayout > 0,
            let authorization = try?
                PolkamarktClaimValidator.reviewedTraderAuthorization(
                    claims: [claimable],
                    account: account,
                    source: .selectedDetail,
                    finalizedBlockHash: reviewedAt
                )
        {
            alert.addAction(
                UIAlertAction(
                    title: PolkamarktL10n.claimTrader(),
                    style: .default
                ) {
                    [weak self] _ in
                    self?.submitClaim {
                        try await coordinator.submitTraderClaim(
                            authorization
                        )
                    }
                }
            )
        }
        if
            claimable.isCreator,
            claimable.creatorFees > 0,
            let authorization = try?
                PolkamarktClaimValidator.reviewedCreatorAuthorization(
                    claim: claimable,
                    account: account,
                    finalizedBlockHash: reviewedAt
                )
        {
            alert.addAction(
                UIAlertAction(
                    title: PolkamarktL10n.claimCreator(),
                    style: .default
                ) {
                    [weak self] _ in
                    self?.submitClaim {
                        try await coordinator.submitCreatorFeeClaim(
                            authorization
                        )
                    }
                }
            )
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func submitClaim(
        operation: @escaping () async throws -> PolkamarktPendingMutation
    ) {
        guard
            canPresentAccountScopedResult(),
            SettingsManager.shared.polkamarktMutationsEnabled
        else {
            return
        }
        mutationAdmissionAvailable = false
        navigationItem.rightBarButtonItem?.isEnabled = false
        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let pending = try await operation()
                guard canPresentAccountScopedResult() else {
                    return
                }
                show(
                    title: "Claim submitted",
                    message: pending.extrinsicHash ?? "Pending reconciliation."
                )
                reload()
            } catch {
                guard canPresentAccountScopedResult() else {
                    return
                }
                show(
                    title: "Claim not completed",
                    message: error.localizedDescription
                )
                reload()
            }
        }
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

    private static func basisPoints(_ value: UInt32?) -> String {
        guard let value else {
            return "—"
        }
        return String(format: "%.2f%%", Double(value) / 100)
    }

    private static func slippageBasisPoints(_ value: String) throws -> UInt16 {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            normalized.range(
                of: #"^(?:0|[1-9][0-9]*)(?:\.[0-9]{1,2})?$"#,
                options: .regularExpression
            ) != nil
        else {
            throw PolkamarktRuntimeError.invalidSlippage
        }
        let parts = normalized.split(
            separator: ".",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard let whole = UInt16(parts[0]), whole <= 100 else {
            throw PolkamarktRuntimeError.invalidSlippage
        }
        let fraction: UInt16
        if parts.count == 2 {
            let padded = String(parts[1]).padding(
                toLength: 2,
                withPad: "0",
                startingAt: 0
            )
            guard let value = UInt16(padded) else {
                throw PolkamarktRuntimeError.invalidSlippage
            }
            fraction = value
        } else {
            fraction = 0
        }
        let result = whole * 100 + fraction
        guard (
            PolkamarktRuntimeContract.minimumMobileSlippageBasisPoints ...
                PolkamarktRuntimeContract.maximumMobileSlippageBasisPoints
        ).contains(result) else {
            throw PolkamarktRuntimeError.invalidSlippage
        }
        return result
    }

    private static func slippagePercent(_ basisPoints: UInt16) -> String {
        let whole = basisPoints / 100
        let fraction = basisPoints % 100
        guard fraction != 0 else {
            return String(whole)
        }
        let fractional = String(format: "%02d", fraction)
            .replacingOccurrences(
                of: #"0+$"#,
                with: "",
                options: .regularExpression
            )
        return "\(whole).\(fractional)"
    }
}

extension PolkamarktMarketViewController: Localizable {
    func applyLocalization() {
        if market.title == nil {
            title = PolkamarktL10n.pageTitle(
                localizationManager?.preferredLocalizations
            )
        }
        guard isViewLoaded else {
            return
        }
        updateChart()
        tableView.reloadData()
    }
}

@MainActor
private final class PolkamarktLineChartView: UIView {
    var caption = "" {
        didSet {
            setNeedsDisplay()
        }
    }

    var values: [Double] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    var secondaryValues: [Double] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    var markerFraction: Double? {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard values.count > 1, let context = UIGraphicsGetCurrentContext() else {
            let text = "Probability history will appear after snapshots are indexed."
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .footnote),
                .foregroundColor: UIColor.secondaryLabel
            ]
            text.draw(
                in: rect.insetBy(dx: 24, dy: 60),
                withAttributes: attributes
            )
            return
        }

        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: UIColor.secondaryLabel
        ]
        caption.draw(
            in: CGRect(
                x: 20,
                y: 8,
                width: rect.width - 40,
                height: 20
            ),
            withAttributes: captionAttributes
        )
        let bounds = rect.inset(
            by: UIEdgeInsets(top: 32, left: 20, bottom: 20, right: 20)
        )
        stroke(
            values,
            color: .systemPink,
            lineWidth: 3,
            in: bounds,
            context: context
        )
        if secondaryValues.count > 1 {
            stroke(
                secondaryValues,
                color: .systemBlue,
                lineWidth: 2,
                in: bounds,
                context: context
            )
        }
        if let markerFraction {
            let normalized = min(max(markerFraction, 0.01), 0.99)
            let markerX = bounds.minX +
                CGFloat((normalized - 0.01) / 0.98) * bounds.width
            context.saveGState()
            context.setStrokeColor(UIColor.secondaryLabel.cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [4, 3])
            context.move(to: CGPoint(x: markerX, y: bounds.minY))
            context.addLine(to: CGPoint(x: markerX, y: bounds.maxY))
            context.strokePath()
            context.restoreGState()
        }
    }

    private func stroke(
        _ values: [Double],
        color: UIColor,
        lineWidth: CGFloat,
        in bounds: CGRect,
        context: CGContext
    ) {
        context.beginPath()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)
        let denominator = CGFloat(max(values.count - 1, 1))
        for (index, rawValue) in values.enumerated() {
            let value = min(max(rawValue, 0), 1)
            let point = CGPoint(
                x: bounds.minX + CGFloat(index) / denominator * bounds.width,
                y: bounds.maxY - CGFloat(value) * bounds.height
            )
            if index == 0 {
                context.move(to: point)
            } else {
                context.addLine(to: point)
            }
        }
        context.strokePath()
    }
}
