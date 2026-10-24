// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit
import SoraKeystore
import SoraUIKit

final class RootWireframe: RootWireframeProtocol {
    func showOnboarding(on view: UIWindow) {
        installOnboarding(on: view)
    }

    /// Used after the recovery screen set the blocking state aside: open the
    /// flow the user picked once the onboarding root is on screen.
    func showOnboarding(on view: UIWindow, continuingWith intent: WalletRecoveryStartOverIntent) {
        let presenter = (installOnboarding(on: view) as? WelcomeViewController)?.presenter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            switch intent {
            case .createWallet:
                presenter?.activateSignup()
            case .restoreWallet:
                presenter?.activateAccountRestore()
            }
        }
    }

    @discardableResult
    private func installOnboarding(on view: UIWindow) -> OnboardingMainViewProtocol? {
        RetainedMigrationEvidenceHarness.shared.observeApplicationRoute(
            .onboarding
        )
        let containerView = WelcomeBackgroundViewController()
        
        let onboardingView = OnboardingMainViewFactory.createWelcomeViewForRoot()
        
        let nc = UINavigationController(rootViewController: onboardingView?.controller ?? UIViewController())
        nc.navigationBar.backgroundColor = .clear
        nc.navigationBar.setBackgroundImage(UIImage(), for: .default)
        nc.addCustomTransitioning()
        
        containerView.add(nc)
        
        view.rootViewController = containerView
        return onboardingView
    }

    func showLegacyWalletUpgrade(
        on view: UIWindow,
        onConfirm: @escaping () -> Void
    ) {
        RetainedMigrationEvidenceHarness.shared.observeApplicationRoute(
            .legacyUpgradeReady
        )
        let controller = LegacyWalletUpgradeViewController(
            onConfirm: onConfirm
        )
        let navigation = UINavigationController(
            rootViewController: controller
        )
        navigation.navigationBar.isHidden = true
        view.rootViewController = navigation
    }

    @MainActor
    func showLocalAuthentication(on view: UIWindow) {
        RetainedMigrationEvidenceHarness.shared.observeApplicationRoute(
            .localAuthentication
        )
        let pinView = PinViewFactory.createRedesignSecuredPinView()?.controller ?? UIViewController()
        
        let containerView = BlurViewController()
        containerView.backgroundColor = .bgPage
        containerView.isClosable = false
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(pinView)

        view.rootViewController = containerView
    }

    func showPincodeSetup(on view: UIWindow) {
        RetainedMigrationEvidenceHarness.shared.observeApplicationRoute(
            .pincodeSetup
        )
        guard let controller = PinViewFactory.createRedesignPinSetupView()?.controller else {
            return
        }

        view.rootViewController = controller
    }

    func showBroken(on view: UIWindow) {
        RetainedMigrationEvidenceHarness.shared.observeApplicationRoute(
            .recovery
        )
        var onRetry: (() -> Void)?
        if let window = view as? SoraWindow {
            onRetry = { [weak window] in
                guard let window else { return }
                // Restart the full storage/account checks. Only their verified
                // activation may clear recovery; this action changes no data.
                // This process already ran the network bootstrap, and the
                // checks need the store closed, as it is at launch: the WAL
                // checkpoint waits forever on a connection left open here.
                try? UserDataStorageFacade.shared.databaseService.close()
                SplashPresenterFactory.createSplashPresenter(with: window, reusingNetworkBootstrap: true)
            }
        }
        let controller = WalletRecoveryViewController(
            reason: SettingsManager.shared.walletMigrationRecoveryReason,
            diagnostic: WalletStartupDiagnostic.current(SettingsManager.shared),
            onRetry: onRetry,
            onStartOver: { [weak view] intent in
                guard let view else { return }
                RootWireframe().showOnboarding(on: view, continuingWith: intent)
            }
        )
        let navigation = UINavigationController(rootViewController: controller)
        navigation.navigationBar.isHidden = true
        view.rootViewController = navigation
    }
}

/// An explicit confirmation replaces the historical silent-import path. The
/// old entropy remains in its original Keychain tag throughout the journaled
/// account commit and is retained after success for dual-read recovery.
private final class LegacyWalletUpgradeViewController: UIViewController {
    private let onConfirm: () -> Void
    private let continueButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let progress = UIActivityIndicatorView(style: .medium)
    private var didConfirm = false

    init(onConfirm: @escaping () -> Void) {
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.numberOfLines = 0
        titleLabel.text = "Protect and upgrade your wallet"

        let bodyLabel = UILabel()
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.text = [
            "SORA found a wallet created by an older app version.",
            "Continue only when you are ready. SORA will verify the protected recovery entropy, derive the same deterministic SORA account, and commit it through the interruption-safe wallet journal.",
            "The original Keychain entry will not be deleted or replaced in this release. If any check fails, the app will stop in recovery mode instead of creating another wallet."
        ].joined(separator: "\n\n")

        continueButton.setTitle(
            "Continue protected upgrade",
            for: .normal
        )
        continueButton.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .continueUpgradeAccessibilityIdentifier
        continueButton.titleLabel?.font = .preferredFont(
            forTextStyle: .headline
        )
        continueButton.addTarget(
            self,
            action: #selector(confirmUpgrade),
            for: .touchUpInside
        )

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        progress.hidesWhenStopped = true

        let stack = UIStackView(
            arrangedSubviews: [
                titleLabel,
                bodyLabel,
                continueButton,
                progress,
                statusLabel,
            ]
        )
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 24
            ),
            stack.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -24
            ),
            stack.centerYAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.centerYAnchor
            ),
        ])
    }

    @objc private func confirmUpgrade() {
        guard !didConfirm else {
            return
        }
        didConfirm = true
        continueButton.isEnabled = false
        progress.startAnimating()
        statusLabel.text =
            "Verifying and preserving your wallet. Do not delete the app."
        onConfirm()
    }
}

/// Shown when wallet integrity or account-bound context cannot be proven.
/// It never deletes local state, and it always leaves the user a way forward:
/// rebuild a wallet whose keys are still on this iPhone, restore from a
/// recovery phrase or backup, or create a new wallet. The last two first set
/// the blocking state aside (moved, not deleted) and then continue in the
/// ordinary onboarding flows.
final class WalletRecoveryViewController: UIViewController {
    private enum ActionStyle {
        case primary
        case secondary
        case plain
    }

    private let reason: String?
    private let diagnostic: WalletStartupDiagnostic?
    private let onRetry: (() -> Void)?
    private let onStartOver: ((WalletRecoveryStartOverIntent) -> Void)?
    private let isWalletDatabaseMissing: Bool
    private let retryButton = UIButton(type: .system)
    private let restoreKeysButton = UIButton(type: .system)
    private let restoreCloudBackupButton = UIButton(type: .system)
    private let cloudRecoveryStatusLabel = UILabel()
    private var didRetry = false
    private let exportButton = UIButton(type: .system)
    private let exportProgress = UIActivityIndicatorView(style: .medium)
    private let exportStatusLabel = UILabel()
    private var isExporting = false
    private var isRestoringKeys = false
    private let guidanceLabel = UILabel()
    private let foundWalletsCard = UIView()
    private let foundWalletsList = UIStackView()
    private let restoreFoundButton = UIButton(type: .system)
    private let searchingView = UIStackView()
    private let searchingLabel = UILabel()
    private let restorePhraseButton = UIButton(type: .system)
    private let createWalletButton = UIButton(type: .system)
    private let actionProgress = UIActivityIndicatorView(style: .medium)
    private let actionStatusLabel = UILabel()
    private var foundWallets: [WalletRecoveryKeychainWallet] = []
    private var retainedSelectedAddress: String?
    private var isChangingWallet = false
    private var keychainRestorer: WalletRecoveryKeychainRestorer?

    init(reason: String?, diagnostic: WalletStartupDiagnostic? = nil, onRetry: (() -> Void)? = nil,
         onStartOver: ((WalletRecoveryStartOverIntent) -> Void)? = nil) {
        self.reason = reason
        self.diagnostic = diagnostic
        self.onRetry = onRetry
        self.onStartOver = onStartOver
        isWalletDatabaseMissing =
            (try? FileManager.default.attributesOfItem(atPath: UserStorageParams.storageURL.path)) == nil
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness.recoveryAccessibilityIdentifier

        let iconView = UIImageView(image: UIImage(systemName: "key.viewfinder"))
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40, weight: .semibold)
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .vertical)
        let iconRow = UIStackView(arrangedSubviews: [iconView, UIView()])

        let titleLabel = Self.label(.title1, color: .label)
        titleLabel.font = UIFont(
            descriptor: UIFont.preferredFont(forTextStyle: .title1).fontDescriptor
                .withSymbolicTraits(.traitBold) ?? UIFont.preferredFont(forTextStyle: .title1).fontDescriptor,
            size: 0
        )
        titleLabel.text = "Restore your wallet"
        titleLabel.accessibilityTraits = .header

        let bodyLabel = Self.label(.body, color: .secondaryLabel)
        bodyLabel.text = summaryText

        guidanceLabel.font = .preferredFont(forTextStyle: .body)
        guidanceLabel.adjustsFontForContentSizeCategory = true
        guidanceLabel.textColor = .secondaryLabel
        guidanceLabel.numberOfLines = 0
        guidanceLabel.isHidden = true

        let searchingProgress = UIActivityIndicatorView(style: .medium)
        searchingProgress.startAnimating()
        searchingLabel.font = .preferredFont(forTextStyle: .footnote)
        searchingLabel.adjustsFontForContentSizeCategory = true
        searchingLabel.textColor = .secondaryLabel
        searchingLabel.numberOfLines = 0
        searchingLabel.text = "Looking for wallet keys on this iPhone…"
        searchingView.addArrangedSubview(searchingProgress)
        searchingView.addArrangedSubview(searchingLabel)
        searchingView.spacing = 8
        searchingView.isHidden = true

        let cardTitle = Self.label(.headline, color: .label)
        cardTitle.text = "Found on this iPhone"
        let cardHint = Self.label(.footnote, color: .secondaryLabel)
        cardHint.text = "This wallet’s keys are still saved on this iPhone. Restore it, then unlock it with your SORA PIN."
        foundWalletsList.axis = .vertical
        foundWalletsList.spacing = 10
        Self.style(restoreFoundButton, title: "Restore my wallet", as: .primary)
        restoreFoundButton.accessibilityIdentifier = "wallet-recovery-restore-found"
        restoreFoundButton.addTarget(self, action: #selector(confirmRestoreFoundWallets), for: .touchUpInside)
        let cardStack = UIStackView(arrangedSubviews: [cardTitle, foundWalletsList, cardHint, restoreFoundButton])
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.setCustomSpacing(16, after: cardHint)
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        foundWalletsCard.backgroundColor = .secondarySystemBackground
        foundWalletsCard.layer.cornerRadius = 16
        foundWalletsCard.layer.cornerCurve = .continuous
        foundWalletsCard.addSubview(cardStack)
        foundWalletsCard.isHidden = true
        NSLayoutConstraint.activate([
            cardStack.leadingAnchor.constraint(equalTo: foundWalletsCard.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: foundWalletsCard.trailingAnchor, constant: -16),
            cardStack.topAnchor.constraint(equalTo: foundWalletsCard.topAnchor, constant: 16),
            cardStack.bottomAnchor.constraint(equalTo: foundWalletsCard.bottomAnchor, constant: -16),
        ])

        Self.style(restoreKeysButton, title: "Restore existing wallet keys", as: .secondary)
        restoreKeysButton.accessibilityIdentifier = "wallet-recovery-restore-keys"
        restoreKeysButton.isHidden = diagnostic?.cause != .missingSecret || onRetry == nil
        restoreKeysButton.addTarget(self, action: #selector(chooseKeyRecoveryAccount), for: .touchUpInside)

        Self.style(restoreCloudBackupButton, title: "Restore from Google Drive backup", as: .secondary)
        restoreCloudBackupButton.accessibilityIdentifier = "wallet-recovery-restore-cloud-backup"
        restoreCloudBackupButton.isHidden = restoreKeysButton.isHidden
        restoreCloudBackupButton.addTarget(self, action: #selector(chooseCloudRecoveryAccount), for: .touchUpInside)
        cloudRecoveryStatusLabel.font = .preferredFont(forTextStyle: .footnote)
        cloudRecoveryStatusLabel.textColor = .secondaryLabel
        cloudRecoveryStatusLabel.numberOfLines = 0
        cloudRecoveryStatusLabel.isHidden = true
        cloudRecoveryStatusLabel.accessibilityIdentifier = "wallet-recovery-cloud-status"

        Self.style(restorePhraseButton, title: "Restore with recovery phrase",
                   subtitle: "Or a raw seed or Google Drive backup", as: .primary)
        restorePhraseButton.accessibilityIdentifier = "wallet-recovery-restore-phrase"
        restorePhraseButton.isHidden = onStartOver == nil
        restorePhraseButton.addTarget(self, action: #selector(confirmRestoreWithPhrase), for: .touchUpInside)

        Self.style(createWalletButton, title: "Create a new wallet", as: .secondary)
        createWalletButton.accessibilityIdentifier = "wallet-recovery-create-wallet"
        createWalletButton.isHidden = onStartOver == nil
        createWalletButton.addTarget(self, action: #selector(confirmCreateWallet), for: .touchUpInside)

        actionProgress.hidesWhenStopped = true
        actionStatusLabel.font = .preferredFont(forTextStyle: .footnote)
        actionStatusLabel.adjustsFontForContentSizeCategory = true
        actionStatusLabel.textColor = .secondaryLabel
        actionStatusLabel.numberOfLines = 0
        actionStatusLabel.textAlignment = .center
        actionStatusLabel.isHidden = true
        actionStatusLabel.accessibilityIdentifier = "wallet-recovery-action-status"

        Self.style(retryButton, title: "Try again", as: .plain)
        retryButton.accessibilityIdentifier = "wallet-recovery-retry"
        retryButton.isHidden = onRetry == nil
        retryButton.addTarget(self, action: #selector(retryWalletVerification), for: .touchUpInside)

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true

        let helpTitle = Self.label(.headline, color: .label)
        helpTitle.text = "Need help?"
        let helpBody = Self.label(.footnote, color: .secondaryLabel)
        helpBody.text = "SORA keeps the wallet data it couldn’t open on this iPhone, so keep the app installed. Contact SORA support with the details below. Never share your recovery phrase with anyone, including support."

        let diagnosticLabel = Self.label(.footnote, color: .secondaryLabel)
        diagnosticLabel.accessibilityIdentifier = "wallet-recovery-diagnostic"
        diagnosticLabel.text = diagnostic?.summary ?? "No detailed check was recorded by the previous build. Tap Try again to collect the current failure."

        let versionLabel = Self.label(.footnote, color: .tertiaryLabel)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        versionLabel.text = "SORA \(version) (\(build))"

        let supportButton = UIButton(type: .system)
        Self.style(supportButton, title: "Open SORA support", as: .plain)
        supportButton.addTarget(
            self,
            action: #selector(openSupport),
            for: .touchUpInside
        )

        let detailsButton = UIButton(type: .system)
        Self.style(detailsButton, title: "Copy recovery details", as: .plain)
        detailsButton.accessibilityIdentifier = "wallet-recovery-copy-details"
        detailsButton.addTarget(
            self,
            action: #selector(copyRecoveryDetails),
            for: .touchUpInside
        )

        Self.style(exportButton, title: "Create protected recovery export", as: .plain)
        exportButton.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .recoveryExportAccessibilityIdentifier
        exportButton.addTarget(
            self,
            action: #selector(confirmRecoveryExport),
            for: .touchUpInside
        )

        exportProgress.hidesWhenStopped = true

        exportStatusLabel.font = .preferredFont(forTextStyle: .footnote)
        exportStatusLabel.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .recoveryExportSuccessAccessibilityIdentifier
        exportStatusLabel.textColor = .secondaryLabel
        exportStatusLabel.numberOfLines = 0
        exportStatusLabel.textAlignment = .center

        let backupHelpButton = UIButton(type: .system)
        Self.style(backupHelpButton, title: "Recovery export help", as: .plain)
        backupHelpButton.addTarget(
            self,
            action: #selector(showBackupHelp),
            for: .touchUpInside
        )

        let stack = UIStackView(
            arrangedSubviews: [
                iconRow,
                titleLabel,
                bodyLabel,
                guidanceLabel,
                searchingView,
                foundWalletsCard,
                restoreKeysButton,
                restoreCloudBackupButton,
                cloudRecoveryStatusLabel,
                restorePhraseButton,
                createWalletButton,
                actionProgress,
                actionStatusLabel,
                retryButton,
                separator,
                helpTitle,
                helpBody,
                supportButton,
                detailsButton,
                exportButton,
                exportProgress,
                exportStatusLabel,
                backupHelpButton,
                diagnosticLabel,
                versionLabel
            ]
        )
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(8, after: iconRow)
        stack.setCustomSpacing(8, after: titleLabel)
        stack.setCustomSpacing(20, after: guidanceLabel)
        stack.setCustomSpacing(20, after: foundWalletsCard)
        stack.setCustomSpacing(24, after: retryButton)
        stack.setCustomSpacing(20, after: separator)
        stack.setCustomSpacing(4, after: helpTitle)
        stack.setCustomSpacing(16, after: backupHelpButton)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor
            ),
            scrollView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor
            ),
            stack.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor,
                constant: 24
            ),
            stack.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor,
                constant: -24
            ),
            stack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor,
                constant: 24
            ),
            stack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -24
            ),
            stack.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor,
                constant: -48
            )
        ])

        searchForKeychainWallets()
    }

    private var summaryText: String {
        if diagnostic?.cause == .missingStore || isWalletDatabaseMissing {
            return "SORA couldn’t open the wallet saved on this iPhone, so it stopped before showing it. Nothing has been deleted."
        }
        return diagnostic?.userMessage ??
            "SORA couldn’t verify your wallet, so it stopped before opening it. Nothing has been deleted."
    }

    private static func label(_ style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private static func style(_ button: UIButton, title: String, subtitle: String? = nil, as style: ActionStyle) {
        var configuration: UIButton.Configuration
        switch style {
        case .primary: configuration = .filled()
        case .secondary: configuration = .gray()
        case .plain: configuration = .plain()
        }
        configuration.title = title
        configuration.subtitle = subtitle
        configuration.titleAlignment = .center
        configuration.cornerStyle = .large
        configuration.buttonSize = style == .plain ? .medium : .large
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: style == .plain ? .body : .headline)
            return attributes
        }
        button.configuration = configuration
        // Keep the state title readable for code that inspects `title(for:)`.
        button.setTitle(title, for: .normal)
        button.contentHorizontalAlignment = style == .plain ? .leading : .fill
    }

    private static func shortAddress(_ address: String) -> String {
        address.count > 16 ? "\(address.prefix(6))…\(address.suffix(6))" : address
    }

    private var isBusy: Bool {
        didRetry || isExporting || isRestoringKeys || isChangingWallet
    }

    // MARK: Ways forward

    /// Only a missing or account-less database means the Keychain may hold
    /// wallets that no other record describes. Other causes keep their own
    /// targeted actions.
    private func searchForKeychainWallets() {
        guard onRetry != nil else {
            showFoundWallets([])
            return
        }
        searchingView.isHidden = false
        guard UIApplication.shared.isProtectedDataAvailable else {
            searchingLabel.text = "Unlock this iPhone so SORA can look for your wallet keys."
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(protectedDataBecameAvailable),
                name: UIApplication.protectedDataDidBecomeAvailableNotification,
                object: nil
            )
            return
        }
        searchingLabel.text = "Looking for wallet keys on this iPhone…"
        let settings = SettingsManager.shared
        DispatchQueue.global(qos: .userInitiated).async {
            let names = WalletRecoveryKeychainScanner.retainedDisplayNames(settings: settings)
            let selected = WalletRecoveryKeychainScanner.retainedSelectedAccount(settings: settings)?.address
            let result = Result {
                guard WalletRecoveryKeychainScanner.walletDatabaseHasNoAccounts() else {
                    return [WalletRecoveryKeychainWallet]()
                }
                return try WalletRecoveryKeychainScanner.wallets(keystore: Keychain(), settings: settings, displayNames: names)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.retainedSelectedAddress = selected
                switch result {
                case let .success(wallets):
                    self.showFoundWallets(wallets)
                case .failure:
                    self.searchingView.isHidden = true
                    self.showFoundWallets([])
                    self.guidanceLabel.text = "SORA couldn’t read this iPhone’s secure storage just now. Tap Try again to look for your wallet keys again, or restore with your recovery phrase."
                }
            }
        }
    }

    @objc private func protectedDataBecameAvailable() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
        searchForKeychainWallets()
    }

    private func showFoundWallets(_ wallets: [WalletRecoveryKeychainWallet]) {
        foundWallets = wallets
        searchingView.isHidden = true
        foundWalletsList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for wallet in wallets {
            let name = Self.label(.body, color: .label)
            name.text = wallet.displayName
            let address = UILabel()
            address.font = .monospacedSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize,
                weight: .regular
            )
            address.textColor = .secondaryLabel
            address.text = Self.shortAddress(wallet.address)
            let row = UIStackView(arrangedSubviews: [name, address])
            row.axis = .vertical
            row.spacing = 2
            row.isAccessibilityElement = true
            row.accessibilityLabel = "\(wallet.displayName), address \(Self.shortAddress(wallet.address))"
            foundWalletsList.addArrangedSubview(row)
        }
        let found = !wallets.isEmpty
        foundWalletsCard.isHidden = !found
        if found {
            Self.style(restoreFoundButton,
                       title: wallets.count == 1 ? "Restore my wallet" : "Restore \(wallets.count) wallets",
                       as: .primary)
            Self.style(restorePhraseButton, title: "Restore with recovery phrase",
                       subtitle: "Or a raw seed or Google Drive backup", as: .secondary)
            Self.style(createWalletButton, title: "Create a new wallet", as: .plain)
            createWalletButton.contentHorizontalAlignment = .center
            guidanceLabel.isHidden = true
        } else if onStartOver != nil {
            guidanceLabel.text = isWalletDatabaseMissing
                ? "No wallet keys were found on this iPhone. Restore your wallet with its recovery phrase or a backup, or create a new wallet."
                : "You can also restore your wallet with its recovery phrase or a backup, or create a new wallet."
            guidanceLabel.isHidden = false
        }
    }

    @objc private func confirmRestoreFoundWallets() {
        guard !foundWallets.isEmpty, !isBusy else { return }
        let names = foundWallets
            .map { "\($0.displayName) · \(Self.shortAddress($0.address))" }
            .joined(separator: "\n")
        let alert = UIAlertController(
            title: foundWallets.count == 1 ? "Restore this wallet?" : "Restore \(foundWallets.count) wallets?",
            message: names + "\n\nSORA rebuilds the wallet from the keys saved on this iPhone and keeps the data it couldn’t open in a separate folder. Then unlock it with your SORA PIN.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Restore", style: .default) { [weak self] _ in
            self?.restoreFoundWallets()
        })
        present(alert, animated: true)
    }

    private func restoreFoundWallets() {
        guard !foundWallets.isEmpty, !isBusy else { return }
        let wallets = foundWallets
        let selectedAddress = retainedSelectedAddress
        setChangingWallet(true, status: "Restoring your wallet…")
        DispatchQueue.global(qos: .userInitiated).async {
            let setAside = Result {
                try WalletRecoveryFreshStart.setAsideInstalledState(retiringKeychainMaterial: false)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if case let .failure(error) = setAside {
                    self.finishWalletChange(error: error, restartAfterAlert: false)
                    return
                }
                let restorer = WalletRecoveryKeychainRestorer()
                self.keychainRestorer = restorer
                restorer.restore(wallets, selectedAddress: selectedAddress) { [weak self] result in
                    guard let self else { return }
                    self.keychainRestorer = nil
                    switch result {
                    case .success:
                        self.actionStatusLabel.text = "Wallet restored. Checking it before it opens…"
                        self.restartStartup()
                    case let .failure(error):
                        self.finishWalletChange(error: error, restartAfterAlert: true)
                    }
                }
            }
        }
    }

    @objc private func confirmRestoreWithPhrase() {
        confirmStartOver(.restoreWallet)
    }

    @objc private func confirmCreateWallet() {
        confirmStartOver(.createWallet)
    }

    private func confirmStartOver(_ intent: WalletRecoveryStartOverIntent) {
        guard onStartOver != nil, !isBusy else { return }
        let title: String
        let confirm: String
        var lines: [String]
        switch intent {
        case .restoreWallet:
            title = "Restore with your recovery phrase?"
            confirm = "Continue"
            lines = [
                "SORA moves the wallet data it couldn’t open to a separate folder on this iPhone. Nothing is deleted.",
                "Next, choose your recovery phrase, raw seed or Google Drive backup."
            ]
        case .createWallet:
            title = "Create a new wallet?"
            confirm = "Create new wallet"
            lines = [
                "SORA moves the wallet data it couldn’t open to a separate folder on this iPhone. Nothing is deleted, and any funds stay in your old wallet.",
                "To use your old wallet again later, you’ll need its recovery phrase."
            ]
        }
        if !foundWallets.isEmpty {
            lines.append("Keys for your wallet were found on this iPhone. If you continue, they’re set aside too and can only be restored with the wallet’s recovery phrase. To keep them, tap Cancel and choose Restore my wallet.")
        }
        let alert = UIAlertController(title: title, message: lines.joined(separator: "\n\n"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: confirm, style: foundWallets.isEmpty ? .default : .destructive) { [weak self] _ in
            self?.startOver(intent)
        })
        present(alert, animated: true)
    }

    private func startOver(_ intent: WalletRecoveryStartOverIntent) {
        guard let onStartOver, !isBusy else { return }
        setChangingWallet(true, status: "Setting aside the wallet data SORA couldn’t open…")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try WalletRecoveryFreshStart.setAsideInstalledState(retiringKeychainMaterial: true)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch result {
                case .success:
                    onStartOver(intent)
                case let .failure(error):
                    self.finishWalletChange(error: error, restartAfterAlert: false)
                }
            }
        }
    }

    private func restartStartup() {
        guard let onRetry else {
            actionStatusLabel.text = "Close SORA and open it again to finish."
            return
        }
        didRetry = true
        onRetry()
    }

    private func setChangingWallet(_ busy: Bool, status: String?) {
        isChangingWallet = busy
        for button in [restoreFoundButton, restorePhraseButton, createWalletButton, restoreKeysButton,
                       restoreCloudBackupButton, exportButton] {
            button.isEnabled = !busy
        }
        retryButton.isEnabled = !busy && !didRetry
        if busy { actionProgress.startAnimating() } else { actionProgress.stopAnimating() }
        actionStatusLabel.text = status
        actionStatusLabel.isHidden = status == nil
    }

    private func finishWalletChange(error: Error, restartAfterAlert: Bool) {
        setChangingWallet(false, status: nil)
        let message: String
        if case AccountCreateError.duplicated = error {
            message = "A different key is already saved for this wallet on this iPhone, so SORA didn’t replace it. Use Restore with recovery phrase instead."
        } else {
            let code = "\((error as NSError).domain) \((error as NSError).code)"
            message = "Nothing was deleted. Try again, or restore with your recovery phrase.\n\n(\(code))"
        }
        let alert = UIAlertController(title: "Your wallet wasn’t restored", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            // A failed restore may already have saved some accounts; let the
            // full startup checks decide what opens next.
            if restartAfterAlert { self?.restartStartup() }
        })
        present(alert, animated: true)
    }

    @objc private func retryWalletVerification() {
        guard let onRetry, !didRetry, !isExporting, !isRestoringKeys, !isChangingWallet else { return }
        didRetry = true
        for button in [retryButton, restoreKeysButton, restoreCloudBackupButton, restoreFoundButton,
                       restorePhraseButton, createWalletButton] {
            button.isEnabled = false
        }
        onRetry()
    }

    private func keyRecoveryMigrator() -> UserStorageMigrator {
        UserStorageMigrator(targetVersion: UserStorageParams.modelVersion,
            storeURL: UserStorageParams.storageURL, modelDirectory: UserStorageParams.modelDirectory,
            keystore: Keychain(), settings: SettingsManager.shared, fileManager: .default)
    }

    @objc private func chooseKeyRecoveryAccount() {
        selectKeyRecoveryAccount(useCloudBackup: false)
    }

    @objc private func chooseCloudRecoveryAccount() {
        selectKeyRecoveryAccount(useCloudBackup: true)
    }

    private func selectKeyRecoveryAccount(useCloudBackup: Bool) {
        guard !isBusy, diagnostic?.cause == .missingSecret else { return }
        setKeyRecoveryBusy(true)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = Result { try self.keyRecoveryMigrator().accountsForMissingKeyRecovery() }
            DispatchQueue.main.async {
                self.setKeyRecoveryBusy(false)
                guard !self.didRetry else { return }
                switch result {
                case .success(let accounts) where accounts.count == 1:
                    self.beginKeyRecovery(for: accounts[0], useCloudBackup: useCloudBackup)
                case .success(let accounts) where !accounts.isEmpty:
                    let chooser = UIAlertController(title: "Choose the existing wallet",
                        message: "Choose the saved wallet whose keys you want to restore.", preferredStyle: .alert)
                    for account in accounts {
                        chooser.addAction(UIAlertAction(title: "\(account.username) · \(account.address.prefix(8))…",
                            style: .default) { [weak self] _ in
                                self?.beginKeyRecovery(for: account, useCloudBackup: useCloudBackup)
                            })
                    }
                    chooser.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    self.present(chooser, animated: true)
                default:
                    self.showKeyRecoveryError("The retained account could not be read for recovery. Its data has not been changed.")
                }
            }
        }
    }

    private func beginKeyRecovery(for account: AccountItem, useCloudBackup: Bool) {
        if useCloudBackup { readCloudBackup(for: account) }
        else { presentKeyRecovery(for: account) }
    }

    private func readCloudBackup(for account: AccountItem) {
        guard !isBusy else { return }
        guard UIApplication.shared.isProtectedDataAvailable else {
            showKeyRecoveryError("Unlock this iPhone, then try again.")
            return
        }
        setKeyRecoveryBusy(true)
        setCloudRecoveryStatus("Sign in to the Google account used for this wallet’s backup. SORA will read its encrypted backup.")
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let reader = WalletCloudBackupRecoveryService(viewController: self)
                let encryptedBackup = try await reader.readBackup(for: account.address)
                self.setKeyRecoveryBusy(false)
                self.setCloudRecoveryStatus("Encrypted backup found. Enter its backup password to verify and restore the saved account.")
                self.presentCloudBackupPassword(for: account, encryptedBackup: encryptedBackup)
            } catch {
                self.setKeyRecoveryBusy(false)
                let message = WalletCloudBackupRecoveryError.userMessage(for: error)
                self.setCloudRecoveryStatus(message)
                self.showKeyRecoveryError(message, title: WalletCloudBackupRecoveryError.title(for: error))
            }
        }
    }

    private func presentCloudBackupPassword(for account: AccountItem, encryptedBackup: Data) {
        let prompt = UIAlertController(title: "Unlock your existing backup",
            message: "Enter the password you set for this SORA Google Drive backup. The password stays on this iPhone. SORA will verify that the backup matches your saved account before restoring missing keys.",
            preferredStyle: .alert)
        prompt.addTextField { field in
            field.placeholder = "Backup password"
            field.isSecureTextEntry = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.accessibilityIdentifier = "wallet-recovery-backup-password"
        }
        prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak prompt] _ in
            prompt?.textFields?.forEach { $0.text = nil }
        })
        prompt.addAction(UIAlertAction(title: "Verify and restore", style: .default) { [weak self, weak prompt] _ in
            guard let self, let prompt, !self.isBusy else { return }
            var password = prompt.textFields?.first?.text ?? ""
            prompt.textFields?.forEach { $0.text = nil }
            self.setKeyRecoveryBusy(true)
            self.setCloudRecoveryStatus("Verifying the backup against the saved account…")
            DispatchQueue.global(qos: .userInitiated).async {
                defer { password.removeAll(keepingCapacity: false) }
                let result = Result {
                    try WalletCloudBackupRecoveryService.restore(data: encryptedBackup, password: password,
                        account: account, migrator: self.keyRecoveryMigrator())
                }
                DispatchQueue.main.async {
                    self.setKeyRecoveryBusy(false)
                    switch result {
                    case .success:
                        self.setCloudRecoveryStatus("Missing credentials restored. Verifying the complete wallet…")
                        self.retryWalletVerification()
                    case .failure(let error):
                        let message = WalletCloudBackupRecoveryError.userMessage(for: error)
                        self.setCloudRecoveryStatus(message)
                        self.showKeyRecoveryError(message)
                    }
                }
            }
        })
        present(prompt, animated: true)
    }

    private func setCloudRecoveryStatus(_ message: String) {
        cloudRecoveryStatusLabel.text = message
        cloudRecoveryStatusLabel.isHidden = false
    }

    private func presentKeyRecovery(for account: AccountItem) {
        let prompt = UIAlertController(title: "Restore existing wallet keys",
            message: "Enter this wallet’s recovery phrase on this iPhone. It must match the existing account. Add your original derivation path only if you used one.", preferredStyle: .alert)
        prompt.addTextField { field in
            field.placeholder = "Recovery phrase"
            field.isSecureTextEntry = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.accessibilityIdentifier = "wallet-recovery-phrase"
        }
        prompt.addTextField { field in
            field.placeholder = "Original derivation path (optional)"
            field.isSecureTextEntry = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.spellCheckingType = .no
        }
        prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak prompt] _ in
            prompt?.textFields?.forEach { $0.text = nil }
        })
        prompt.addAction(UIAlertAction(title: "Verify and restore", style: .default) { [weak self, weak prompt] _ in
            guard let self, let prompt else { return }
            var phrase = prompt.textFields?.first?.text ?? ""
            var path = prompt.textFields?.last?.text ?? ""
            prompt.textFields?.forEach { $0.text = nil }
            self.setKeyRecoveryBusy(true)
            DispatchQueue.global(qos: .userInitiated).async {
                defer { phrase.removeAll(keepingCapacity: false); path.removeAll(keepingCapacity: false) }
                let result = Result {
                    try self.keyRecoveryMigrator().restoreMissingEntropy(address: account.address,
                        mnemonic: phrase, derivationPath: path)
                }
                DispatchQueue.main.async {
                    self.setKeyRecoveryBusy(false)
                    switch result {
                    case .success:
                        self.retryWalletVerification()
                    case .failure:
                        self.showKeyRecoveryError("The phrase and derivation path could not be verified for this account, or the keys could not be saved. Existing accounts and keys were not replaced. Check your original backup and try again.")
                    }
                }
            }
        })
        present(prompt, animated: true)
    }

    private func setKeyRecoveryBusy(_ busy: Bool) {
        isRestoringKeys = busy
        restoreKeysButton.isEnabled = !busy
        restoreCloudBackupButton.isEnabled = !busy
        retryButton.isEnabled = !busy && !didRetry
        exportButton.isEnabled = !busy && !isExporting
        for button in [restoreFoundButton, restorePhraseButton, createWalletButton] {
            button.isEnabled = !busy
        }
    }

    private func showKeyRecoveryError(_ message: String, title: String = "Wallet keys not restored") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func openSupport() {
        UIApplication.shared.open(ApplicationConfig.shared.supportURL)
    }

    @objc private func copyRecoveryDetails() {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "unknown"
        let operatingSystem = ProcessInfo.processInfo.operatingSystemVersion
        let protection = UIApplication.shared.isProtectedDataAvailable ? "available" : "unavailable"
        UIPasteboard.general.string = [
            "SORA \(version) (\(build))",
            "Recovery report format: 2",
            diagnostic?.summary ?? "Latest verification: not recorded; retry required",
            diagnostic.map { "Current failure: \($0.userMessage)" },
            cloudRecoveryStatusLabel.isHidden ? nil : cloudRecoveryStatusLabel.text.map { "Backup recovery: \($0)" },
            originalRecoverySummary,
            "iOS: \(operatingSystem.majorVersion).\(operatingSystem.minorVersion).\(operatingSystem.patchVersion)",
            "Protected data when copied: \(protection)"
        ].compactMap { $0 }.joined(separator: "\n")
    }

    /// Old marker text is history, not the latest failure. Copy only the known
    /// fixed-code format; arbitrary historical errors can contain account data.
    private var originalRecoverySummary: String {
        let prefix = "Wallet storage could not be verified safely ("
        let suffix = "). Existing wallet data and recovery copies were preserved."
        if let reason, reason.hasPrefix(prefix), reason.hasSuffix(suffix) {
            let code = String(reason.dropFirst(prefix.count).dropLast(suffix.count))
            if WalletStartupDiagnostic.Cause(rawValue: code) != nil {
                return "Original recovery trigger: \(reason)"
            }
        }
        return "Original recovery trigger: legacy record (details unavailable)"
    }

    @objc private func showBackupHelp() {
        let instructions = [
            "Do not delete or reinstall SORA.",
            "Keep any existing recovery phrase or encrypted JSON backup offline.",
            "A protected recovery export contains public wallet metadata but no phrase, seed, private key, PIN, signed payload, or Keychain item.",
            "Keychain secrets stay only on this device.",
            "Use Copy recovery details when contacting SORA support.",
            "Never send anyone your phrase, seed, private key, or PIN."
        ].joined(separator: "\n")
        let alert = UIAlertController(
            title: "Protect your recovery options",
            message: instructions,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: "Copy instructions",
                style: .default
            ) { _ in
                UIPasteboard.general.string = instructions
            }
        )
        alert.addAction(
            UIAlertAction(
                title: "Open SORA support",
                style: .default
            ) { _ in
                UIApplication.shared.open(
                    ApplicationConfig.shared.supportURL
                )
            }
        )
        alert.addAction(
            UIAlertAction(title: "Cancel", style: .cancel)
        )
        present(alert, animated: true)
    }

    @objc private func confirmRecoveryExport() {
        guard !isExporting, !isRestoringKeys, !isChangingWallet else {
            return
        }
        let alert = UIAlertController(
            title: "Create protected recovery export?",
            message: [
                "The export can contain public wallet metadata, including addresses, account names, preferences, and transaction history.",
                "It does not contain your phrase, seed, private key, PIN, signed transaction payloads, or any Keychain item. Keychain secrets stay only on this device.",
                "Keep the export private and share it only through an official support channel whose identity you have verified."
            ].joined(separator: "\n\n"),
            preferredStyle: .alert
        )
        alert.view.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .recoveryExportConfirmAccessibilityIdentifier
        alert.addAction(
            UIAlertAction(title: "Cancel", style: .cancel)
        )
        alert.addAction(
            UIAlertAction(
                title: "Create export",
                style: .default
            ) { [weak self] _ in
                self?.createRecoveryExport()
            }
        )
        present(alert, animated: true)
    }

    private func createRecoveryExport() {
        guard !isExporting, !isRestoringKeys, !isChangingWallet else {
            return
        }
        isExporting = true
        exportButton.isEnabled = false
        exportProgress.startAnimating()
        exportStatusLabel.text =
            "Verifying preserved files. Wallet data and Keychain will not be changed."

        let exporter = WalletRecoveryExporter()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try exporter.createRecoveryPackage()
                DispatchQueue.main.async {
                    self?.presentRecoveryExport(result.packageURL)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.finishRecoveryExport(
                        error: error.localizedDescription
                    )
                }
            }
        }
    }

    private func presentRecoveryExport(_ url: URL) {
        isExporting = false
        exportButton.isEnabled = true
        exportProgress.stopAnimating()
        exportStatusLabel.text = [
            "Protected export created.",
            "Keychain secrets remain only on this device."
        ].joined(separator: " ")
        RetainedMigrationEvidenceHarness.shared
            .recordRecoveryArchiveExport(url)

        let activity = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        if let popover = activity.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton.bounds
        }
        present(activity, animated: true)
    }

    private func finishRecoveryExport(error: String) {
        isExporting = false
        exportButton.isEnabled = true
        exportProgress.stopAnimating()
        exportStatusLabel.text =
            "No recovery package was published."

        let alert = UIAlertController(
            title: "Recovery export stopped safely",
            message: [
                error,
                "The installed wallet, settings, recovery marker, and Keychain were not changed."
            ].joined(separator: "\n\n"),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: "OK", style: .default)
        )
        present(alert, animated: true)
    }
}
