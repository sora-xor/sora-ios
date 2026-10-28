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
import SoraFoundation
import SoraKeystore
import SoraUIKit

final class RootWireframe: RootWireframeProtocol {
    private let keystore: KeystoreProtocol
    private let settings: SettingsManagerProtocol

    init(keystore: KeystoreProtocol = Keychain(), settings: SettingsManagerProtocol = SettingsManager.shared) {
        self.keystore = keystore
        self.settings = settings
    }

    func showOnboarding(on view: UIWindow) {
        showOnboarding(on: view, restoreFromDrive: nil)
    }

    func showOnboarding(on view: UIWindow, restoreFromDrive: Bool?) {
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
        if let restoreFromDrive, let welcome = onboardingView as? WelcomeViewController {
            DispatchQueue.main.async {
                if restoreFromDrive { welcome.presenter.activateCloudStorageConnection() }
                else { OnboardingRootWireframe().showAccountRestoreRedesign(from: welcome, sourceType: .mnemonic) }
            }
        }
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

    func showWelcomeBack(on view: UIWindow) {
        RetainedMigrationEvidenceHarness.shared.observeApplicationRoute(
            .onboarding
        )
        let restart: () -> Void = { [weak view] in
            guard let window = view as? SoraWindow else { return }
            // Re-run the full startup checks with the restored wallets.
            Self.restartStartup(on: window)
        }
        // The wireframe is captured strongly: it holds no state and does not
        // own the controller, so there is no cycle. A weak capture let the
        // phrase, Google Drive and set-up actions do nothing once launch
        // routing had returned and the Root module was released.
        let controller = WalletWelcomeBackViewController(
            keystore: keystore,
            settings: settings,
            onContinueToOnboarding: { [weak view] in
                guard let view else { return }
                self.showOnboarding(on: view)
            },
            onWalletsRestored: restart,
            onRestore: { [weak view] drive in
                guard let view else { return }
                self.showOnboarding(on: view, restoreFromDrive: drive)
            }
        )
        let navigation = UINavigationController(rootViewController: controller)
        navigation.navigationBar.isHidden = true
        view.rootViewController = navigation
    }

    /// Runs the startup checks again in this process. The app's own Core
    /// Data stack is closed first (it reopens on next use): the first
    /// migration backup of a store checkpoints its WAL, which needs the store
    /// not to be held open by this process.
    static func restartStartup(on window: SoraWindow) {
        try? UserDataStorageFacade.shared.databaseService.close()
        SplashPresenterFactory.createSplashPresenter(with: window)
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
                Self.restartStartup(on: window)
            }
        }
        let controller = WalletRecoveryViewController(
            reason: SettingsManager.shared.walletMigrationRecoveryReason,
            diagnostic: WalletStartupDiagnostic.current(SettingsManager.shared),
            onRetry: onRetry,
            onSetAside: onRetry,
            onRestore: { [weak view] drive in
                guard let view else { return }
                self.showOnboarding(on: view, restoreFromDrive: drive)
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
final class LegacyWalletUpgradeViewController: UIViewController {
    private let onConfirm: () -> Void
    private let continueButton = WalletSafeMode.button(.safe, title: WalletUX.text("Upgrade wallet"))
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

    /// Safe Mode (spec §9.2 U3): calm copy, verified assurances only, one
    /// Safe action. The technical description moved behind
    /// "What happens during the upgrade?".
    override func viewDidLoad() {
        super.viewDidLoad()
        WalletSafeMode.installBackdrop(in: view)

        let titleLabel = UILabel()
        WalletSafeMode.title(titleLabel, WalletUX.text("Upgrade your wallet"))

        let bodyLabel = UILabel()
        WalletSafeMode.body(bodyLabel)
        bodyLabel.text = WalletUX.text("This version moves your wallet to a safer storage format. It only takes a moment.")

        // Both facts hold for this flow: the 1.x entropy stays in its
        // original Keychain item, and any failed check routes to recovery.
        let assurances = UIStackView(arrangedSubviews: [
            Self.assurance(WalletUX.text("Your original keys are not deleted or replaced")),
            Self.assurance(WalletUX.text("If a check fails, SORA stops safely and shows your options"))
        ])
        assurances.axis = .vertical
        assurances.spacing = 12

        continueButton.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .continueUpgradeAccessibilityIdentifier
        continueButton.addTarget(
            self,
            action: #selector(confirmUpgrade),
            for: .touchUpInside
        )

        let detailsButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("What happens during the upgrade?"))
        detailsButton.addTarget(self, action: #selector(showUpgradeDetails), for: .touchUpInside)

        WalletSafeMode.detail(statusLabel)
        progress.hidesWhenStopped = true
        progress.color = WalletUX.tokens.cyan

        let stack = UIStackView(
            arrangedSubviews: [
                WalletSafeMode.centered(WalletSafeMode.shieldEmblem()),
                titleLabel,
                bodyLabel,
                assurances,
                continueButton,
                progress,
                statusLabel,
                detailsButton,
            ]
        )
        stack.axis = .vertical
        stack.spacing = 20
        stack.setCustomSpacing(28, after: assurances)
        // Centred when it fits; scrolls at large text sizes so "Upgrade
        // wallet" and the details are always reachable (spec §9.4).
        WalletSafeMode.installScrollingContent(stack, in: view)
    }

    /// A row with a cyan check and `text.primary` copy (spec §7.17).
    static func assurance(_ text: String) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle"))
        icon.tintColor = WalletUX.tokens.cyan
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        icon.isAccessibilityElement = false
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: FontType.textM.font)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = WalletUX.tokens.textPrimary
        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 12
        row.alignment = .firstBaseline
        return row
    }

    @objc private func showUpgradeDetails() {
        let alert = UIAlertController(
            title: WalletUX.text("What happens during the upgrade?"),
            message: [
                WalletUX.text("SORA found a wallet created by an older app version."),
                WalletUX.text("SORA checks the recovery data saved by the older version, derives the same SORA account from it, and saves that account in a way that survives interruptions."),
                WalletUX.text("The original Keychain entry is not deleted or replaced in this release. If any check fails, SORA stops and shows your recovery options instead of creating another wallet.")
            ].joined(separator: "\n\n"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
        present(alert, animated: true)
    }

    @objc private func confirmUpgrade() {
        guard !didConfirm else {
            return
        }
        didConfirm = true
        continueButton.isEnabled = false
        progress.startAnimating()
        statusLabel.text = WalletUX.text("Updating your wallet. Keep SORA open until this finishes.")
        onConfirm()
    }
}

/// A fail-closed surface used when wallet integrity or account-bound context
/// cannot be proven.
/// It has no reset or logout action: it never deletes wallet data. Every
/// state offers a way forward (see `WalletRecoveryOptions`); "Set up this
/// iPhone again" moves this install's wallet files aside and never touches
/// the Keychain.
final class WalletRecoveryViewController: UIViewController {
    private let optionsLoader: (() -> WalletRecoveryOptions)?
    private let reason: String?
    private let diagnostic: WalletStartupDiagnostic?
    private let onRetry: (() -> Void)?
    private let onSetAside: (() -> Void)?
    private let onRestore: ((Bool) -> Void)?
    // Safe Mode action order (spec §9.2 U6): one Safe action, then
    // secondary restore options, then quieter text actions.
    private let retryButton = WalletSafeMode.button(.safe, title: WalletUX.text("Try again"))
    private let restorePhraseButton = WalletSafeMode.button(.secondary, title: WalletUX.text("Restore with recovery phrase"))
    private let restoreKeysButton = WalletSafeMode.button(.secondary, title: WalletUX.text("Restore existing wallet keys"))
    private let restoreCloudBackupButton = WalletSafeMode.button(
        .secondary, title: WalletUX.text("Restore from Google Drive backup"))
    private let showPhraseButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Show my recovery phrase"))
    private let setUpAgainButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Set up this iPhone again"))
    private let setAsideRecordsButton = WalletSafeMode.button(
        .secondary, title: WalletUX.text("Set aside unfinished transaction records"))
    private let cloudRecoveryStatusLabel = UILabel()
    private let bodyLabel = UILabel()
    private var didLoadOptions = false
    private var didRetry = false
    private let exportButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Create protected recovery export"))
    private let exportProgress = UIActivityIndicatorView(style: .medium)
    private let exportStatusLabel = UILabel()
    private var isExporting = false
    private var isRestoringKeys = false
    private(set) var options = WalletRecoveryOptions()

    init(reason: String?, diagnostic: WalletStartupDiagnostic? = nil, onRetry: (() -> Void)? = nil,
         onSetAside: (() -> Void)? = nil, onRestore: ((Bool) -> Void)? = nil,
         optionsLoader: (() -> WalletRecoveryOptions)? = nil) {
        self.optionsLoader = optionsLoader
        self.reason = reason
        self.diagnostic = diagnostic
        self.onRetry = onRetry
        self.onSetAside = onSetAside
        self.onRestore = onRestore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        WalletSafeMode.installBackdrop(in: view)
        view.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness.recoveryAccessibilityIdentifier

        let titleLabel = UILabel()
        WalletSafeMode.title(titleLabel, WalletUX.text("We paused to keep your wallet safe"))

        retryButton.accessibilityIdentifier = "wallet-recovery-retry"
        retryButton.isHidden = onRetry == nil
        retryButton.addTarget(self, action: #selector(retryWalletVerification), for: .touchUpInside)

        restorePhraseButton.accessibilityIdentifier = "wallet-recovery-restore-phrase"
        restorePhraseButton.isHidden = true
        restorePhraseButton.addTarget(self, action: #selector(chooseKeyRecoveryAccount), for: .touchUpInside)

        // Restore actions are shown from facts (accounts whose keys are
        // missing), not from the cause recorded by the latest check.
        restoreKeysButton.accessibilityIdentifier = "wallet-recovery-restore-keys"
        restoreKeysButton.isHidden = true
        restoreKeysButton.addTarget(self, action: #selector(chooseKeyRecoveryAccount), for: .touchUpInside)

        restoreCloudBackupButton.accessibilityIdentifier = "wallet-recovery-restore-cloud-backup"
        restoreCloudBackupButton.isHidden = true
        restoreCloudBackupButton.addTarget(self, action: #selector(chooseCloudRecoveryAccount), for: .touchUpInside)

        showPhraseButton.accessibilityIdentifier = "wallet-recovery-show-phrase"
        showPhraseButton.isHidden = true
        showPhraseButton.addTarget(self, action: #selector(showRecoveryPhrase), for: .touchUpInside)

        setUpAgainButton.accessibilityIdentifier = "wallet-recovery-set-up-again"
        setUpAgainButton.isHidden = onSetAside == nil
        setUpAgainButton.addTarget(self, action: #selector(confirmSetUpAgain), for: .touchUpInside)

        // Shown from a fact (the records folder cannot be read), like the
        // restore actions. It is the action that lets "Try again" pass.
        setAsideRecordsButton.accessibilityIdentifier = "wallet-recovery-set-aside-transaction-records"
        setAsideRecordsButton.isHidden = true
        setAsideRecordsButton.addTarget(self, action: #selector(confirmSetAsideTransactionRecords), for: .touchUpInside)
        WalletSafeMode.detail(cloudRecoveryStatusLabel)
        cloudRecoveryStatusLabel.isHidden = true
        cloudRecoveryStatusLabel.accessibilityIdentifier = "wallet-recovery-cloud-status"

        WalletSafeMode.body(bodyLabel)
        bodyLabel.accessibilityIdentifier = "wallet-recovery-body"
        refreshBody()

        let diagnosticLabel = UILabel()
        WalletSafeMode.technical(diagnosticLabel)
        diagnosticLabel.accessibilityIdentifier = "wallet-recovery-diagnostic"
        diagnosticLabel.text = diagnostic?.summary ?? WalletUX.text("No detailed check was recorded by the previous build.")

        let versionLabel = UILabel()
        WalletSafeMode.technical(versionLabel)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        versionLabel.text = "SORA \(version) (\(build))"

        let supportButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Contact support"))
        supportButton.addTarget(
            self,
            action: #selector(openSupport),
            for: .touchUpInside
        )

        let detailsButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Copy recovery details"))
        detailsButton.accessibilityIdentifier = "wallet-recovery-copy-details"
        detailsButton.addTarget(
            self,
            action: #selector(copyRecoveryDetails),
            for: .touchUpInside
        )

        exportButton.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .recoveryExportAccessibilityIdentifier
        exportButton.addTarget(
            self,
            action: #selector(confirmRecoveryExport),
            for: .touchUpInside
        )

        exportProgress.hidesWhenStopped = true
        exportProgress.color = WalletUX.tokens.cyan

        WalletSafeMode.detail(exportStatusLabel)
        exportStatusLabel.isHidden = true
        exportStatusLabel.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .recoveryExportSuccessAccessibilityIdentifier

        let backupHelpButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Recovery export help"))
        backupHelpButton.addTarget(
            self,
            action: #selector(showBackupHelp),
            for: .touchUpInside
        )

        // Technical details: the code and version, never in the title or body.
        let technicalCard = GlassView()
        technicalCard.fill = .solid
        technicalCard.shape = .rounded(16)
        let technicalStack = UIStackView(arrangedSubviews: [diagnosticLabel, versionLabel])
        technicalStack.axis = .vertical
        technicalStack.spacing = 8
        technicalStack.translatesAutoresizingMaskIntoConstraints = false
        technicalCard.contentView.addSubview(technicalStack)
        NSLayoutConstraint.activate([
            technicalStack.leadingAnchor.constraint(equalTo: technicalCard.contentView.leadingAnchor, constant: 16),
            technicalStack.trailingAnchor.constraint(equalTo: technicalCard.contentView.trailingAnchor, constant: -16),
            technicalStack.topAnchor.constraint(equalTo: technicalCard.contentView.topAnchor, constant: 14),
            technicalStack.bottomAnchor.constraint(equalTo: technicalCard.contentView.bottomAnchor, constant: -14)
        ])

        let stack = UIStackView(
            arrangedSubviews: [
                WalletSafeMode.centered(WalletSafeMode.shieldEmblem()),
                titleLabel,
                bodyLabel,
                retryButton,
                setAsideRecordsButton,
                restorePhraseButton,
                restoreKeysButton,
                restoreCloudBackupButton,
                cloudRecoveryStatusLabel,
                showPhraseButton,
                setUpAgainButton,
                exportButton,
                exportProgress,
                exportStatusLabel,
                supportButton,
                backupHelpButton,
                detailsButton,
                technicalCard
            ]
        )
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(20, after: titleLabel)
        stack.setCustomSpacing(24, after: bodyLabel)
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
        refreshOptions()
    }

    /// Reads the available actions from the device in the background.
    private func refreshOptions() {
        if let optionsLoader {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let options = optionsLoader()
                DispatchQueue.main.async { self?.apply(options) }
            }
            return
        }
        let settings = SettingsManager.shared
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let state = WalletRecoveryStateProbe.recovery(
                migrator: self.keyRecoveryMigrator(), keystore: Keychain(), settings: settings)
            DispatchQueue.main.async {
                self.apply(state.options)
            }
        }
    }

    func apply(_ options: WalletRecoveryOptions) {
        self.options = options
        didLoadOptions = true
        let canAct = onRetry != nil
        retryButton.isHidden = !(options.canRetry && canAct)
        restoreKeysButton.isHidden = !(options.canRestoreExistingKeys && canAct)
        restorePhraseButton.isHidden = !(options.canRestoreFromPhrase && (canAct || onRestore != nil))
        restoreCloudBackupButton.isHidden = !(options.canRestoreFromDrive && (canAct || onRestore != nil))
        showPhraseButton.isHidden = !options.canShowPhraseAfterPin
        setUpAgainButton.isHidden = !(options.canSetUpDeviceAgain && onSetAside != nil)
        setAsideRecordsButton.isHidden = !offersToSetAsideTransactionRecords
        exportButton.isHidden = !options.canExport
        refreshBody()
    }

    /// The one condition for the records button and for every sentence
    /// about it: the folder cannot be read now, and this screen can run the
    /// startup checks again afterwards.
    private var offersToSetAsideTransactionRecords: Bool {
        options.canSetAsideTransactionRecords && onRetry != nil
    }

    private func refreshBody() {
        var visible = options
        visible.canRetry = options.canRetry && onRetry != nil
        visible.canRestoreFromPhrase = !restorePhraseButton.isHidden
        visible.canRestoreFromDrive = !restoreCloudBackupButton.isHidden
        visible.canRestoreExistingKeys = !restoreKeysButton.isHidden
        visible.canSetAsideTransactionRecords = offersToSetAsideTransactionRecords
        visible.canSetUpDeviceAgain = !setUpAgainButton.isHidden
        bodyLabel.text = Self.bodyText(diagnostic: diagnostic, options: visible)
    }

    static func bodyText(diagnostic: WalletStartupDiagnostic?, options: WalletRecoveryOptions) -> String {
        let explanation: String
        if diagnostic?.phase == .pendingTransactions, !options.canSetAsideTransactionRecords {
            // The stored failure may predate a successful read. Never promise
            // a set-aside action that current options do not offer.
            explanation = WalletUX.text("SORA could not read its records of transactions that were still being confirmed when it last checked. Your accounts, keys and funds are not affected.")
        } else {
            explanation = diagnostic?.userMessage ?? WalletUX.text("SORA could not verify the wallet for this operation. Your existing wallet data has been kept.")
        }
        var paragraphs = [explanation]
        if options.canRetry { paragraphs.append(WalletUX.text("Try again to run the wallet checks once more.")) }
        if options.canSetAsideTransactionRecords {
            paragraphs.append(WalletUX.text("You can set aside the unreadable records of unfinished transactions below. Your wallet keys will not change."))
        }
        if options.canRestoreFromPhrase { paragraphs.append(WalletUX.text("Restore with your recovery phrase using the button below.")) }
        if options.canRestoreFromDrive { paragraphs.append(WalletUX.text("You can also restore from your encrypted Google Drive backup.")) }
        if options.canSetUpDeviceAgain {
            paragraphs.append(WalletUX.text("Set up this iPhone again keeps the earlier files in a separate folder on this iPhone."))
        }
        paragraphs.append(WalletUX.text("Contact SORA support if you need help. Never share your recovery phrase, private key or PIN."))
        return paragraphs.joined(separator: "\n\n")
    }

    /// Paths of the records action; replaced in tests.
    var transactionRecordsPaths: () throws -> WalletLocalStateSetAside.Paths = {
        try WalletLocalStateSetAside.Paths.production()
    }

    @objc private func confirmSetAsideTransactionRecords() {
        guard !didRetry, !isExporting, !isRestoringKeys else { return }
        let alert = UIAlertController(
            title: WalletUX.text("Set aside unfinished transaction records?"),
            message: WalletUX.text("SORA will move its records of transactions that were still being confirmed to a separate folder on this iPhone. Nothing is deleted, and your accounts, keys and funds are not changed. SORA will no longer be able to tell you whether your most recent transaction went through, so check your activity before you send it again."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: WalletUX.text("Set aside"), style: .default) { [weak self] _ in
            self?.setAsideTransactionRecords()
        })
        present(alert, animated: true)
    }

    /// The confirmed action. Not private so a test can run it without the
    /// confirmation alert.
    func setAsideTransactionRecords() {
        guard !didRetry, !isExporting, !isRestoringKeys else { return }
        // The same busy state as the other actions: while the folder moves,
        // "Try again" must not run the startup checks over a folder that is
        // still in place, and no export or second set-aside may start.
        setKeyRecoveryBusy(true)
        let resolvePaths = transactionRecordsPaths
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                let paths = try resolvePaths()
                try PendingTransactionRecords.setAside(
                    applicationSupportURL: paths.applicationSupportURL,
                    setAsideRootURL: paths.setAsideRootURL
                )
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.setKeyRecoveryBusy(false)
                switch result {
                case .success:
                    // The folder is readable again: read the actions from
                    // the device once more (the records button goes, and the
                    // text with it), and run the startup checks.
                    self.refreshOptions()
                    self.retryWalletVerification()
                case .failure:
                    self.showKeyRecoveryError(
                        WalletUX.text("Nothing was changed. Try again, or contact SORA support."),
                        title: WalletUX.text("Could not set the records aside")
                    )
                }
            }
        }
    }

    @objc private func retryWalletVerification() {
        guard let onRetry, !didRetry, !isExporting, !isRestoringKeys else { return }
        didRetry = true
        retryButton.isEnabled = false
        exportButton.isEnabled = false
        restorePhraseButton.isEnabled = false
        restoreKeysButton.isEnabled = false
        restoreCloudBackupButton.isEnabled = false
        setAsideRecordsButton.isEnabled = false
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
        guard !didRetry, !isExporting, !isRestoringKeys else { return }
        guard options.canRestoreExistingKeys else {
            beginExternalRestore(useCloudBackup: useCloudBackup)
            return
        }
        setKeyRecoveryBusy(true)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = Result { try self.keyRecoveryMigrator().accountsForCredentialRecovery() }
            DispatchQueue.main.async {
                self.setKeyRecoveryBusy(false)
                guard !self.didRetry else { return }
                switch result {
                case .success(let accounts) where accounts.count == 1:
                    self.beginKeyRecovery(for: accounts[0], useCloudBackup: useCloudBackup)
                case .success(let accounts) where !accounts.isEmpty:
                    let chooser = UIAlertController(title: WalletUX.text("Choose the existing wallet"),
                        message: WalletUX.text("Choose the saved wallet whose keys you want to restore."), preferredStyle: .alert)
                    for account in accounts {
                        chooser.addAction(UIAlertAction(title: "\(account.username) · \(account.address.prefix(8))…",
                            style: .default) { [weak self] _ in
                                self?.beginKeyRecovery(for: account, useCloudBackup: useCloudBackup)
                            })
                    }
                    chooser.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
                    self.present(chooser, animated: true)
                default:
                    self.showKeyRecoveryError(WalletUX.text("The retained account could not be read for recovery. Its data has not been changed."))
                }
            }
        }
    }

    private func beginExternalRestore(useCloudBackup: Bool) {
        guard let onRestore else { return }
        WalletSetUpAgainConfirmation.present(on: self, movesWalletData: true) { [weak self] in
            guard let self else { return }
            self.setKeyRecoveryBusy(true)
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result {
                    try WalletLocalStateSetAside.setAside(settings: SettingsManager.shared,
                        expectedMarker: WalletMigrationRecoveryMarker.capture(SettingsManager.shared),
                        paths: .production(), closeDatabase: { try? UserDataStorageFacade.shared.databaseService.close() })
                    SelectedWalletSettings.shared.commitInternalValue(nil)
                    let lease = WalletLifecycleCoordinator.shared.acquire()
                    do {
                        // A stopped repair can outlive the files just preserved.
                        // Archive that row-absent intent before onboarding changes
                        // PIN protection; a returned row requires fresh authority.
                        let rows = WalletPreservedGeneration.exists(UserStorageParams.storageURL)
                            ? try self.keyRecoveryMigrator().preservedAccountInventory() : []
                        try WalletCredentialRepair(keystore: Keychain(), settings: SettingsManager.shared)
                            .resumePending(accounts: rows)
                        lease.release()
                    } catch { lease.release(); throw error }
                    try WalletPendingPinSetup.leaveWelcomeBack(keystore: Keychain(), settings: SettingsManager.shared)
                }
                DispatchQueue.main.async {
                    self.setKeyRecoveryBusy(false)
                    switch result {
                    case .success: onRestore(useCloudBackup)
                    case .failure:
                        self.showKeyRecoveryError(WalletUX.text("The earlier files were kept. Reopen SORA to continue, or try again."))
                    }
                }
            }
        }
    }

    private func beginKeyRecovery(for account: AccountItem, useCloudBackup: Bool) {
        let migrator = keyRecoveryMigrator()
        setKeyRecoveryBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { () -> (WalletCredentialRepair, Bool) in
                let gate = try migrator.credentialRecoveryGate()
                let keys = Keychain()
                let missing = try [KeystoreTag.entropyTagForAddress(account.address),
                    KeystoreTag.seedTagForAddress(account.address), KeystoreTag.secretKeyTagForAddress(account.address)]
                    .allSatisfy { try !keys.checkKey(for: $0) }
                return (WalletCredentialRepair(keystore: keys, settings: SettingsManager.shared,
                                                recoveryGate: gate), missing)
            }
            DispatchQueue.main.async {
                self.setKeyRecoveryBusy(false)
                switch result {
                case let .success((service, true)):
                    // Missing credentials remain the existing add-only path,
                    // including restored phones with no usable app PIN yet.
                    _ = service
                    if useCloudBackup { self.readCloudBackup(for: account) }
                    else { self.presentKeyRecovery(for: account) }
                case let .success((service, false)):
                    let controller = WalletCredentialRepairViewController(account: account, service: service,
                        currentAccounts: { try migrator.preservedAccountInventory() },
                        onSuccess: { [weak self] _ in
                            self?.dismiss(animated: true) { self?.retryWalletVerification() }
                        }, startWithDrive: useCloudBackup)
                    self.present(UINavigationController(rootViewController: controller), animated: true)
                case .failure:
                    self.showKeyRecoveryError(WalletUX.text("The retained account could not be read for recovery. Its data has not been changed."))
                }
            }
        }
    }

    private func readCloudBackup(for account: AccountItem) {
        guard !didRetry, !isExporting, !isRestoringKeys else { return }
        guard UIApplication.shared.isProtectedDataAvailable else {
            showKeyRecoveryError(WalletUX.text("Unlock this iPhone, then try again."))
            return
        }
        setKeyRecoveryBusy(true)
        setCloudRecoveryStatus(WalletUX.text("Sign in to the Google account used for this wallet’s backup. SORA will read its encrypted backup."))
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let reader = WalletCloudBackupRecoveryService(viewController: self)
                let encryptedBackup = try await reader.readBackup(for: account.address)
                self.setKeyRecoveryBusy(false)
                self.setCloudRecoveryStatus(WalletUX.text("Encrypted backup found. Enter its backup password to verify and restore the saved account."))
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
        let prompt = UIAlertController(title: WalletUX.text("Unlock your existing backup"),
            message: WalletUX.text("Enter the password you set for this SORA Google Drive backup. The password stays on this iPhone. SORA will verify that the backup matches your saved account before restoring missing keys."),
            preferredStyle: .alert)
        prompt.addTextField { field in
            field.placeholder = WalletUX.text("Backup password")
            field.isSecureTextEntry = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.accessibilityIdentifier = "wallet-recovery-backup-password"
        }
        prompt.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel) { [weak prompt] _ in
            prompt?.textFields?.forEach { $0.text = nil }
        })
        prompt.addAction(UIAlertAction(title: WalletUX.text("Verify and restore"), style: .default) { [weak self, weak prompt] _ in
            guard let self, let prompt, !self.didRetry, !self.isExporting, !self.isRestoringKeys else { return }
            var password = prompt.textFields?.first?.text ?? ""
            prompt.textFields?.forEach { $0.text = nil }
            self.setKeyRecoveryBusy(true)
            self.setCloudRecoveryStatus(WalletUX.text("Verifying the backup against the saved account…"))
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
                        self.setCloudRecoveryStatus(WalletUX.text("Missing credentials restored. Verifying the complete wallet…"))
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
        let prompt = UIAlertController(title: WalletUX.text("Restore existing wallet keys"),
            message: WalletUX.text("Enter this wallet’s recovery phrase on this iPhone. It must match the existing account. Add your original derivation path only if you used one."), preferredStyle: .alert)
        prompt.addTextField { field in
            field.placeholder = WalletUX.text("Recovery phrase")
            field.isSecureTextEntry = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.accessibilityIdentifier = "wallet-recovery-phrase"
        }
        prompt.addTextField { field in
            field.placeholder = WalletUX.text("Original derivation path (optional)")
            field.isSecureTextEntry = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.spellCheckingType = .no
        }
        prompt.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel) { [weak prompt] _ in
            prompt?.textFields?.forEach { $0.text = nil }
        })
        prompt.addAction(UIAlertAction(title: WalletUX.text("Verify and restore"), style: .default) { [weak self, weak prompt] _ in
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
                        self.showKeyRecoveryError(WalletUX.text("The phrase and derivation path could not be verified for this account, or the keys could not be saved. Existing accounts and keys were not replaced. Check your original backup and try again."))
                    }
                }
            }
        })
        present(prompt, animated: true)
    }

    private func setKeyRecoveryBusy(_ busy: Bool) {
        isRestoringKeys = busy
        restorePhraseButton.isEnabled = !busy
        restoreKeysButton.isEnabled = !busy
        restoreCloudBackupButton.isEnabled = !busy
        showPhraseButton.isEnabled = !busy
        setUpAgainButton.isEnabled = !busy
        setAsideRecordsButton.isEnabled = !busy
        retryButton.isEnabled = !busy && !didRetry
        exportButton.isEnabled = !busy && !isExporting
    }

    @objc private func showRecoveryPhrase() {
        guard !didRetry, !isExporting, !isRestoringKeys, options.canShowPhraseAfterPin else { return }
        WalletPinPrompt.present(on: self, message: WalletUX.text(
            "Enter the PIN you used for SORA on this iPhone to show your recovery phrase."
        )) { [weak self] pin in
            guard let self else { return }
            self.setKeyRecoveryBusy(true)
            let migrator = self.keyRecoveryMigrator()
            DispatchQueue.global(qos: .userInitiated).async {
                var pin = pin
                defer { pin.removeAll(keepingCapacity: false) }
                let settings = SettingsManager.shared
                let marker = WalletMigrationRecoveryMarker.capture(settings)
                let result = Result {
                    try WalletRecoveryPhraseReveal.reveal(
                        pin: pin,
                        accounts: migrator.recoveryInventory(),
                        keystore: Keychain(),
                        settings: settings,
                        recoveryGate: WalletRecoveryCapabilityGate(
                            settings: settings,
                            unresolvedMigrationJournal: { false },
                            unresolvedWalletCommitJournal: { false },
                            startupVerificationMarker: marker.isRetryableStartupFailure ? marker : nil
                        )
                    )
                }
                DispatchQueue.main.async {
                    self.setKeyRecoveryBusy(false)
                    switch result {
                    case let .success(entries):
                        WalletPinPrompt.presentPhrases(entries, on: self)
                    case let .failure(error):
                        self.showKeyRecoveryError(WalletPinPrompt.message(for: error),
                                                  title: WalletUX.text("Recovery phrase not shown"))
                    }
                    self.refreshOptions()
                }
            }
        }
    }

    @objc private func confirmSetUpAgain() {
        guard !didRetry, !isExporting, !isRestoringKeys, let onSetAside else { return }
        let marker = WalletMigrationRecoveryMarker.capture(SettingsManager.shared)
        WalletSetUpAgainConfirmation.present(on: self, movesWalletData: true) { [weak self] in
            guard let self else { return }
            self.setKeyRecoveryBusy(true)
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result {
                    try WalletLocalStateSetAside.setAside(
                        settings: SettingsManager.shared,
                        expectedMarker: marker,
                        paths: .production(),
                        closeDatabase: { try? UserDataStorageFacade.shared.databaseService.close() }
                    )
                }
                DispatchQueue.main.async {
                    self.setKeyRecoveryBusy(false)
                    switch result {
                    case .success:
                        self.didRetry = true
                        onSetAside()
                    case .failure(WalletLocalStateSetAside.Failure.incomplete):
                        self.showKeyRecoveryError(
                            WalletUX.text("Some earlier wallet files were moved to a separate folder on this iPhone and the others were left in place. Nothing was deleted. Try again, or contact SORA support."),
                            title: WalletUX.text("Could not set up this iPhone again")
                        )
                    case .failure:
                        self.showKeyRecoveryError(
                            WalletUX.text("Nothing was changed. Try again, or contact SORA support."),
                            title: WalletUX.text("Could not set up this iPhone again")
                        )
                    }
                }
            }
        }
    }

    private func showKeyRecoveryError(_ message: String, title: String = WalletUX.text("Wallet keys not restored")) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
        present(alert, animated: true)
    }

    @objc private func openSupport() {
        UIApplication.shared.open(ApplicationConfig.shared.supportURL)
    }

    @objc private func copyRecoveryDetails() {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? WalletUX.text("Unknown")
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? WalletUX.text("Unknown")
        let operatingSystem = ProcessInfo.processInfo.operatingSystemVersion
        let protection = UIApplication.shared.isProtectedDataAvailable
            ? WalletUX.text("Available") : WalletUX.text("Unavailable")
        UIPasteboard.general.string = [
            "SORA \(version) (\(build))",
            WalletUX.text("Recovery report format: 2"),
            diagnostic?.summary ?? WalletUX.text("Latest verification: not recorded; retry required"),
            diagnostic.map { WalletUX.format("Current failure: %@", $0.userMessage) },
            cloudRecoveryStatusLabel.isHidden ? nil : cloudRecoveryStatusLabel.text.map { WalletUX.format("Backup recovery: %@", $0) },
            originalRecoverySummary,
            "iOS: \(operatingSystem.majorVersion).\(operatingSystem.minorVersion).\(operatingSystem.patchVersion)",
            WalletUX.format("Protected data when copied: %@", protection)
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
                return WalletUX.format("Original recovery trigger: %@", code)
            }
        }
        return WalletUX.text("Original recovery trigger: legacy record (details unavailable)")
    }

    @objc private func showBackupHelp() {
        let instructions = [
            WalletUX.text("Recovery never deletes wallet keys from this iPhone's Keychain."),
            WalletUX.text("Keep any existing recovery phrase or encrypted JSON backup offline."),
            WalletUX.text("A protected recovery export contains public wallet metadata but no phrase, seed, private key, PIN, signed payload, or Keychain item."),
            WalletUX.text("Keychain secrets stay only on this device."),
            WalletUX.text("Use Copy recovery details when contacting SORA support."),
            WalletUX.text("Never send anyone your phrase, seed, private key, or PIN.")
        ].joined(separator: "\n")
        let alert = UIAlertController(
            title: WalletUX.text("Protect your recovery options"),
            message: instructions,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: WalletUX.text("Copy instructions"),
                style: .default
            ) { _ in
                UIPasteboard.general.string = instructions
            }
        )
        alert.addAction(
            UIAlertAction(
                title: WalletUX.text("Open SORA support"),
                style: .default
            ) { _ in
                UIApplication.shared.open(
                    ApplicationConfig.shared.supportURL
                )
            }
        )
        alert.addAction(
            UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel)
        )
        present(alert, animated: true)
    }

    @objc private func confirmRecoveryExport() {
        guard !didRetry, !isExporting, !isRestoringKeys else {
            return
        }
        let alert = UIAlertController(
            title: WalletUX.text("Create protected recovery export?"),
            message: [
                WalletUX.text("The export can contain public wallet metadata, including addresses, account names, preferences, and transaction history."),
                WalletUX.text("It does not contain your phrase, seed, private key, PIN, signed transaction payloads, or any Keychain item. Keychain secrets stay only on this device."),
                WalletUX.text("Keep the export private and share it only through an official support channel whose identity you have verified.")
            ].joined(separator: "\n\n"),
            preferredStyle: .alert
        )
        alert.view.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .recoveryExportConfirmAccessibilityIdentifier
        alert.addAction(
            UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel)
        )
        alert.addAction(
            UIAlertAction(
                title: WalletUX.text("Create export"),
                style: .default
            ) { [weak self] _ in
                self?.createRecoveryExport()
            }
        )
        present(alert, animated: true)
    }

    private func createRecoveryExport() {
        guard !didRetry, !isExporting, !isRestoringKeys else {
            return
        }
        isExporting = true
        exportButton.isEnabled = false
        exportProgress.startAnimating()
        exportStatusLabel.text =
            WalletUX.text("Verifying preserved files. Wallet data and Keychain will not be changed.")
        exportStatusLabel.isHidden = false

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
            WalletUX.text("Protected export created."),
            WalletUX.text("Keychain secrets remain only on this device.")
        ].joined(separator: " ")
        exportStatusLabel.isHidden = false
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
            WalletUX.text("No recovery package was published.")
        exportStatusLabel.isHidden = false

        let alert = UIAlertController(
            title: WalletUX.text("Recovery export stopped safely"),
            message: [
                error,
                WalletUX.text("The installed wallet, settings, recovery marker, and Keychain were not changed.")
            ].joined(separator: "\n\n"),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: WalletUX.text("OK"), style: .default)
        )
        present(alert, animated: true)
    }
}

// MARK: - PIN prompt, phrase display and confirmation used by recovery screens

enum WalletPinPrompt {
    static func present(on controller: UIViewController, message: String, completion: @escaping (String) -> Void) {
        let prompt = UIAlertController(title: WalletUX.text("Enter your PIN"), message: message, preferredStyle: .alert)
        prompt.addTextField { field in
            field.placeholder = WalletUX.text("PIN")
            field.isSecureTextEntry = true
            field.keyboardType = .numberPad
            field.textContentType = .oneTimeCode
            field.accessibilityIdentifier = "wallet-retained-pin"
        }
        prompt.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel) { [weak prompt] _ in
            prompt?.textFields?.forEach { $0.text = nil }
        })
        prompt.addAction(UIAlertAction(title: WalletUX.text("Continue"), style: .default) { [weak prompt] _ in
            let pin = prompt?.textFields?.first?.text ?? ""
            prompt?.textFields?.forEach { $0.text = nil }
            completion(pin)
        })
        controller.present(prompt, animated: true)
    }

    static func message(for error: Error) -> String {
        switch error as? WalletRetainedPinGate.Failure {
        case let .incorrectPin(attemptsBeforeWait)?:
            return WalletUX.format("That PIN is not correct. Attempts left before a short wait: %d.",
                                   attemptsBeforeWait)
        case let .locked(until)?:
            let minutes = max(1, Int((until.timeIntervalSinceNow / 60).rounded(.up)))
            return WalletUX.format(
                "Too many attempts. Try again in %d min, or use your recovery phrase or Google Drive backup.",
                minutes)
        case .noRetainedPin?:
            return WalletUX.text("These wallets have no saved ownership PIN. Restore them with your recovery phrase or Google Drive backup.")
        case nil:
            if let error = error as? WalletOwnerPIN.Failure { return error.localizedDescription }
            if let error = error as? AccountCreateError, case .retainedKeyConflict = error {
                return WalletUX.text("This iPhone already has different saved keys for this wallet. Nothing was changed. Contact SORA support.")
            }
            return WalletUX.text("Nothing was changed. Try again, or contact SORA support.")
        }
    }

    /// Shows recovery phrases on a protected screen. The words are not
    /// copied anywhere and are hidden while the app is in the background or
    /// the screen is being recorded or mirrored.
    static func presentPhrases(_ entries: [WalletRecoveryPhraseReveal.Entry], on controller: UIViewController) {
        guard !entries.isEmpty else {
            let alert = UIAlertController(title: WalletUX.text("Recovery phrase not shown"),
                message: WalletUX.text("No recovery phrase is stored on this iPhone for these wallets."),
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
            controller.present(alert, animated: true)
            return
        }
        let screen = WalletRecoveryPhraseViewController(entries: entries)
        screen.modalPresentationStyle = .fullScreen
        controller.present(screen, animated: true)
    }
}

/// Shows recovery phrases after the PIN. Not an alert: an alert's text can
/// end up in the app switcher snapshot. The words are hidden while the app is
/// inactive or the screen is captured, and a screenshot shows the standard
/// warning.
final class WalletRecoveryPhraseViewController: UIViewController {
    private var entries: [WalletRecoveryPhraseReveal.Entry]
    private let wordsLabel = UILabel()
    private let derivationStack = UIStackView()
    /// Opaque card holding the words; hidden with them.
    private let wordsCard = GlassView()
    private let hiddenLabel = UILabel()
    private var observers: [NSObjectProtocol] = []
    private var revealed = false
    private var hideTimer: Timer?
    private lazy var revealButton = WalletSafeMode.button(.secondary, title: WalletUX.text("Show my recovery phrase"))

    init(entries: [WalletRecoveryPhraseReveal.Entry]) {
        self.entries = entries
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        hideTimer?.invalidate()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Secrets sit on opaque surfaces: no aurora, blur or glow behind the
        // words (spec §7.18).
        view.backgroundColor = WalletUX.page
        view.accessibilityIdentifier = "wallet-recovery-phrase"

        let titleLabel = UILabel()
        WalletSafeMode.title(titleLabel, WalletUX.text("Your recovery phrase"))
        titleLabel.textAlignment = .natural

        let warningLabel = UILabel()
        WalletSafeMode.body(warningLabel, alignment: .natural)
        warningLabel.text = [
            WalletUX.text("Write these words down in order and keep them offline. Anyone with them can take your funds."),
            R.string.localizable.screenshotAlertText(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages),
        ].joined(separator: "\n\n")

        wordsLabel.font = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                                                weight: .regular)
        wordsLabel.textColor = WalletUX.tokens.textPrimary
        wordsLabel.numberOfLines = 0
        wordsLabel.adjustsFontForContentSizeCategory = true
        wordsLabel.accessibilityIdentifier = "wallet-recovery-phrase-words"
        wordsCard.fill = .solid
        wordsCard.border = .safe
        wordsCard.shape = .rounded(16)
        wordsLabel.translatesAutoresizingMaskIntoConstraints = false
        wordsCard.contentView.addSubview(wordsLabel)
        NSLayoutConstraint.activate([
            wordsLabel.leadingAnchor.constraint(equalTo: wordsCard.contentView.leadingAnchor, constant: 20),
            wordsLabel.trailingAnchor.constraint(equalTo: wordsCard.contentView.trailingAnchor, constant: -20),
            wordsLabel.topAnchor.constraint(equalTo: wordsCard.contentView.topAnchor, constant: 18),
            wordsLabel.bottomAnchor.constraint(equalTo: wordsCard.contentView.bottomAnchor, constant: -18)
        ])
        WalletSafeMode.body(hiddenLabel, alignment: .natural)
        hiddenLabel.text = WalletUX.text("The words are hidden while the screen is being recorded or shared.")
        hiddenLabel.isHidden = true

        let doneButton = WalletSafeMode.button(.safe, title: WalletUX.text("Done"))
        doneButton.accessibilityIdentifier = "wallet-recovery-phrase-done"
        doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)

        derivationStack.axis = .vertical
        derivationStack.spacing = 12
        revealButton.accessibilityIdentifier = "wallet-recovery-phrase-reveal"
        revealButton.addTarget(self, action: #selector(toggleReveal), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [titleLabel, warningLabel, revealButton, wordsCard, derivationStack, hiddenLabel, doneButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48),
        ])

        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) {
                [weak self] _ in self?.hideWords()
            },
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) {
                [weak self] _ in self?.hideWords()
            },
            center.addObserver(forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main) {
                [weak self] _ in self?.hideWords()
            },
            center.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main) {
                [weak self] _ in self?.warnAboutScreenshot()
            },
        ]
        updateVisibility()
    }

    private var isCaptured: Bool {
        view.window?.windowScene?.screen.isCaptured ?? UIScreen.main.isCaptured
    }

    private func updateVisibility() {
        setWordsVisible(revealed && UIApplication.shared.applicationState == .active && !isCaptured)
        hiddenLabel.isHidden = !isCaptured
        revealButton.isEnabled = !isCaptured
    }

    override func viewWillDisappear(_ animated: Bool) {
        hideWords()
        super.viewWillDisappear(animated)
    }

    @objc private func toggleReveal() {
        if revealed { hideWords(); return }
        guard UIApplication.shared.applicationState == .active, !isCaptured else { return }
        revealed = true
        updateVisibility()
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: false) { [weak self] _ in self?.hideWords() }
        hideTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func hideWords() {
        revealed = false
        hideTimer?.invalidate(); hideTimer = nil
        updateVisibility()
    }

    private func setWordsVisible(_ visible: Bool) {
        revealButton.setTitle(visible ? R.string.localizable.commonHide(preferredLanguages: .currentLocale) : WalletUX.text("Show my recovery phrase"), for: .normal)
        derivationStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        derivationStack.isHidden = !visible
        if visible {
            wordsLabel.text = entries.map { entry in
                let words = entry.words.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                let name = entry.name.isEmpty ? String(entry.address.prefix(8)) + "…" : entry.name
                return "\(name)\n\(words)"
            }.joined(separator: "\n\n")
            for entry in entries {
                guard let path = entry.derivationPath, !path.isEmpty else { continue }
                let label = UILabel()
                WalletSafeMode.body(label, alignment: .natural)
                label.text = "\(entry.name)\n\(WalletUX.text("Also save this derivation path:"))\n\(path)"
                let button = WalletSafeMode.button(.tertiary, title: WalletUX.text("Copy derivation path"))
                button.addAction(UIAction { _ in
                    UIPasteboard.general.setItems([["public.utf8-plain-text": path]],
                        options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
                }, for: .touchUpInside)
                derivationStack.addArrangedSubview(label)
                derivationStack.addArrangedSubview(button)
            }
        } else {
            wordsLabel.text = nil
        }
        wordsLabel.isHidden = !visible
        wordsCard.isHidden = !visible
        hiddenLabel.isHidden = visible || UIApplication.shared.applicationState != .active
    }

    private func warnAboutScreenshot() {
        hideWords()
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        let alert = UIAlertController(
            title: R.string.localizable.screenshotAlertTitle(preferredLanguages: languages),
            message: R.string.localizable.screenshotAlertText(preferredLanguages: languages),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
        present(alert, animated: true)
    }

    @objc private func done() {
        entries = []
        setWordsVisible(false)
        dismiss(animated: true)
    }
}

enum WalletSetUpAgainConfirmation {
    /// Two confirmations, as for other actions that change local wallet data.
    /// `movesWalletData`: the recovery screen moves this install's wallet
    /// database aside; Welcome back has none and only starts onboarding.
    static func present(on controller: UIViewController, movesWalletData: Bool,
                        onConfirm: @escaping () -> Void) {
        let first = UIAlertController(
            title: WalletUX.text("Set up this iPhone again?"),
            message: movesWalletData
                ? WalletUX.text("SORA will start fresh on this iPhone. Wallet keys saved on this iPhone are not deleted, and the earlier wallet data is moved to a separate folder on this iPhone. You can restore any wallet with its recovery phrase or Google Drive backup. Wallets with a saved ownership PIN can also be restored with that PIN.")
                : WalletUX.text("SORA will start fresh on this iPhone. Wallet keys saved on this iPhone are not deleted. You can restore any wallet later with its recovery phrase or Google Drive backup. Wallets with a saved ownership PIN can also be restored from Add account with that PIN."),
            preferredStyle: .alert
        )
        first.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
        first.addAction(UIAlertAction(title: WalletUX.text("Continue"), style: .default) { [weak controller] _ in
            guard let controller else { return }
            let second = UIAlertController(
                title: WalletUX.text("Start fresh?"),
                message: WalletUX.text("Earlier data is kept on this iPhone. Nothing is deleted."),
                preferredStyle: .alert
            )
            second.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
            second.addAction(UIAlertAction(title: WalletUX.text("Set up again"), style: .default) { _ in
                onConfirm()
            })
            controller.present(second, animated: true)
        })
        controller.present(first, animated: true)
    }
}

/// "Restore wallets found on this iPhone": the PIN of the earlier install,
/// then every proven retained wallet that is not in the wallet yet is
/// restored on its own (`RetainedKeychainWalletDiscovery.restore`). Used by
/// Welcome back and, once a wallet exists, by Add account.
enum WalletRetainedWalletRestoreFlow {
    enum Outcome {
        case restored(count: Int, failed: Int)
        case nothingRestored(message: String)
        case setupRequired(count: Int, message: String)
    }

    /// A post-commit callback failure does not undo a verified account row.
    /// Reconcile against the authorized address set before deciding the result.
    static func committedAddresses(current: [AccountItem], authorized: Set<String>,
                                   existingBefore: Set<String>, welcomeBack: Bool) -> Set<String> {
        Set(current.map(\.address)).intersection(authorized)
            .subtracting(welcomeBack ? [] : existingBefore)
    }

    static func run(
        on controller: UIViewController,
        scope: WalletRetainedPinGate.Scope,
        setBusy: @escaping (Bool) -> Void,
        completion: @escaping (Outcome) -> Void
    ) {
        let message = scope == .welcomeBack
            ? WalletUX.text("Enter the PIN that protected these wallets. Only wallets owned by that PIN will be restored, and this app will use that PIN.")
            : WalletUX.text("Enter the PIN that protected the wallets you want to restore.")
        WalletPinPrompt.present(on: controller, message: message) { ownerPIN in
            setBusy(true)
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { () -> WalletOwnerPIN.RetainedAuthorization in
                    let keychain = Keychain()
                    let service = WalletOwnerPIN(keystore: keychain, settings: SettingsManager.shared)
                    let accounts = try service.prepareRetainedAuthentication { try WalletAccountAddresses.accounts() }
                    if scope == .welcomeBack, !accounts.isEmpty {
                        guard try service.requiresInitialSetup(accounts: accounts) else {
                            throw WalletOwnerPIN.Failure.authenticationRequired
                        }
                    }
                    let existing = scope == .welcomeBack ? Set<String>() : Set(accounts.map(\.address))
                    let inventory = try RetainedKeychainWalletDiscovery.inventory(keystore: keychain, excluding: existing)
                    return try service.authorizeRetained(ownerPIN, addresses: Set(inventory.adoptable.map(\.address)))
                }
                DispatchQueue.main.async {
                    setBusy(false)
                    switch result {
                    case let .failure(error): completion(.nothingRestored(message: WalletPinPrompt.message(for: error)))
                    case let .success(grant):
                        if scope == .welcomeBack {
                            restore(grant: grant, appPIN: ownerPIN, scope: scope,
                                    setBusy: setBusy, completion: completion)
                        } else {
                            WalletPinPrompt.present(on: controller, message: WalletUX.text(
                                "Enter this app's PIN. The restored wallets will from now on be protected by this app's PIN."
                            )) { currentPIN in
                                restore(grant: grant, appPIN: currentPIN, scope: scope,
                                        setBusy: setBusy, completion: completion)
                            }
                        }
                    }
                }
            }
        }
    }

    private static func restore(grant: WalletOwnerPIN.RetainedAuthorization, appPIN: String,
                                scope: WalletRetainedPinGate.Scope, setBusy: @escaping (Bool) -> Void,
                                completion: @escaping (Outcome) -> Void) {
        setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            let keychain = Keychain(), settings = SettingsManager.shared
            let service = WalletOwnerPIN(keystore: keychain, settings: settings)
            let outcome: Outcome
            var existing = Set<String>()
            do {
                let accounts = try service.prepareRetainedAuthentication { try WalletAccountAddresses.accounts() }
                if scope == .afterSetup {
                    _ = try service.authenticateCurrent(appPIN, currentAccounts: { try WalletAccountAddresses.accounts() })
                } else if !accounts.isEmpty {
                    guard Set(accounts.map(\.address)).isSubset(of: grant.addresses),
                          try service.requiresInitialSetup(accounts: accounts) else {
                        throw WalletOwnerPIN.Failure.authenticationRequired
                    }
                }
                existing = Set(accounts.map(\.address))
                let inventory = try RetainedKeychainWalletDiscovery.inventory(keystore: keychain, excluding: existing)
                let attempted = inventory.adoptable.filter { grant.addresses.contains($0.address) }
                let result = RetainedKeychainWalletDiscovery.restore(
                    attempted, existing: existing, keystore: keychain,
                    selectedWalletSettings: SelectedWalletSettings.shared,
                    prepareOwnership: { wallet in try service.prepareRebinding(address: wallet.address, to: appPIN,
                                                                             consumeSetupIntent: scope == .afterSetup) },
                    ownershipAuthorization: grant)
                let lease = WalletLifecycleCoordinator.shared.acquire()
                defer { lease.release() }
                let current = try WalletAccountAddresses.accounts()
                try service.settleRebindings(currentAddresses: Set(current.map(\.address)))
                let committed = committedAddresses(current: current, authorized: grant.addresses,
                    existingBefore: existing, welcomeBack: scope == .welcomeBack)
                if !committed.isEmpty {
                    if scope == .welcomeBack { try service.setInitialPIN(appPIN, accounts: current) }
                    let failed = Set(result.failedAddresses).subtracting(committed).count
                    outcome = .restored(count: committed.count, failed: failed)
                } else {
                    outcome = .nothingRestored(message: result.firstError.map(WalletPinPrompt.message) ?? WalletUX.text(
                        "No wallet on this iPhone could be verified. Use your recovery phrase or Google Drive backup."))
                }
            } catch {
                let current = (try? WalletAccountAddresses.accounts()) ?? []
                let committed = committedAddresses(current: current, authorized: grant.addresses,
                    existingBefore: existing, welcomeBack: scope == .welcomeBack)
                if scope == .welcomeBack, !committed.isEmpty {
                    outcome = .setupRequired(count: committed.count, message: WalletUX.text(
                        "Your restored wallets are saved. Complete PIN setup to continue. Your wallet keys are unchanged."))
                } else if !committed.isEmpty {
                    outcome = .nothingRestored(message: WalletUX.text(
                        "Your restored wallets are saved, but the PIN protection update could not finish. Try again before using them."))
                } else { outcome = .nothingRestored(message: WalletPinPrompt.message(for: error)) }
            }
            DispatchQueue.main.async { setBusy(false); completion(outcome) }
        }
    }

    /// The alert for a partial restore. The restored wallets stay.
    static func partialAlert(restored: Int, failed: Int, onOK: @escaping () -> Void) -> UIAlertController {
        let alert = UIAlertController(
            title: WalletUX.text("Some wallets were restored"),
            message: WalletUX.format(
                "Restored: %d. Not restored: %d. The keys of the others were not changed; you can try again from Add account, or restore them with their recovery phrase or Google Drive backup.",
                restored, failed),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default) { _ in onOK() })
        return alert
    }
}

// MARK: - Welcome back (reinstall)

/// Shown when only Keychain items from an earlier install are left (iOS keeps
/// them when the app is deleted). Nothing is deleted or changed by showing it.
final class WalletWelcomeBackViewController: UIViewController {
    private let keystore: KeystoreProtocol
    private let settings: SettingsManagerProtocol
    private let onContinueToOnboarding: () -> Void
    private let onWalletsRestored: () -> Void
    private let onRestore: ((Bool) -> Void)?
    private let earlierDataButton = WalletSafeMode.button(.secondary, title: WalletUX.text("Use the earlier wallet data again"))
    private let restoreFoundButton = WalletSafeMode.button(.safe,
                                                           title: WalletUX.text("Restore wallets found on this iPhone"))
    private let showPhraseButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Show my recovery phrase"))
    private var phraseButton: WalletNeonButton?
    private let statusLabel = UILabel()
    private let progress = UIActivityIndicatorView(style: .medium)
    private var isBusy = false
    private(set) var options = WalletRecoveryState
        .welcomeBack(adoptableWallets: 0, walletsWithPhrase: 0, retainedPinUsable: false).options

    init(keystore: KeystoreProtocol = Keychain(),
         settings: SettingsManagerProtocol = SettingsManager.shared,
         onContinueToOnboarding: @escaping () -> Void,
         onWalletsRestored: @escaping () -> Void,
         onRestore: ((Bool) -> Void)? = nil) {
        self.keystore = keystore
        self.settings = settings
        self.onContinueToOnboarding = onContinueToOnboarding
        self.onWalletsRestored = onWalletsRestored
        self.onRestore = onRestore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        WalletSafeMode.installBackdrop(in: view)
        view.accessibilityIdentifier = "wallet-welcome-back"

        let titleLabel = UILabel()
        WalletSafeMode.title(titleLabel, WalletUX.text("Welcome back"))

        let bodyLabel = UILabel()
        WalletSafeMode.body(bodyLabel)
        bodyLabel.text = WalletUX.text("We found SORA data from an earlier install on this iPhone. Choose how to continue. Nothing will be deleted. Wallets saved by older versions without an ownership PIN need your recovery phrase or Google Drive backup.")

        restoreFoundButton.accessibilityIdentifier = "wallet-welcome-back-restore-found"
        restoreFoundButton.isHidden = true
        restoreFoundButton.addTarget(self, action: #selector(restoreFoundWallets), for: .touchUpInside)

        let phraseButton = makeButton(WalletUX.text("Restore with recovery phrase"),
                                      identifier: "wallet-welcome-back-phrase")
        self.phraseButton = phraseButton
        let driveButton = makeButton(WalletUX.text("Restore from Google Drive"),
                                     identifier: "wallet-welcome-back-drive")
        showPhraseButton.accessibilityIdentifier = "wallet-welcome-back-show-phrase"
        showPhraseButton.isHidden = true
        showPhraseButton.addTarget(self, action: #selector(showPhrase), for: .touchUpInside)
        let setUpButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Set up this iPhone again"))
        setUpButton.accessibilityIdentifier = "wallet-welcome-back-set-up-again"
        setUpButton.addTarget(self, action: #selector(confirmSetUpAgain), for: .touchUpInside)
        let supportButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Contact support"))
        supportButton.addTarget(self, action: #selector(openSupport), for: .touchUpInside)

        WalletSafeMode.detail(statusLabel)
        progress.hidesWhenStopped = true
        progress.color = WalletUX.tokens.cyan

        earlierDataButton.isHidden = true
        earlierDataButton.accessibilityIdentifier = "wallet-welcome-back-earlier-data"
        earlierDataButton.addTarget(self, action: #selector(restoreEarlierData), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [
            WalletSafeMode.centered(WalletSafeMode.shieldEmblem()),
            titleLabel, bodyLabel, restoreFoundButton, phraseButton, driveButton,
            showPhraseButton, earlierDataButton, setUpButton, supportButton, progress, statusLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(20, after: titleLabel)
        stack.setCustomSpacing(24, after: bodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48),
        ])
        refreshOptions()
    }

    private func makeButton(_ title: String, identifier: String) -> WalletNeonButton {
        let button = WalletSafeMode.button(.secondary, title: title)
        button.accessibilityIdentifier = identifier
        // Phrase and Google Drive restore use the onboarding import screens,
        // which adopt matching keys already on this iPhone.
        button.addTarget(self, action: identifier.hasSuffix("drive") ? #selector(restoreDrive) : #selector(restorePhrase), for: .touchUpInside)
        return button
    }

    private func refreshOptions() {
        let keystore = self.keystore
        let settings = self.settings
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let state = WalletRecoveryStateProbe.welcomeBack(keystore: keystore, settings: settings)
            let earlier = (try? WalletLocalStateSetAside.Paths.production()).map {
                !WalletPreservedGeneration.available(paths: $0, settings: settings).isEmpty
            } ?? false
            DispatchQueue.main.async {
                self?.apply(state.options)
                self?.earlierDataButton.isHidden = !earlier
            }
        }
    }

    func apply(_ options: WalletRecoveryOptions) {
        self.options = options
        restoreFoundButton.isHidden = !options.canRestoreExistingKeys
        showPhraseButton.isHidden = !options.canShowPhraseAfterPin
        // One Safe action per screen: the phrase restore leads when no
        // wallet on this iPhone can be restored with the PIN.
        phraseButton?.neonStyle = options.canRestoreExistingKeys ? .secondary : .safe
    }

    private func setBusy(_ busy: Bool, status: String? = nil) {
        isBusy = busy
        busy ? progress.startAnimating() : progress.stopAnimating()
        statusLabel.text = status
        view.isUserInteractionEnabled = !busy
    }

    @objc private func restoreEarlierData() {
        guard !isBusy else { return }
        WalletPreservedDataRestoration.present(on: self, onRestored: onWalletsRestored)
    }
    @objc private func restorePhrase() { leaveForOnboarding(restoreFromDrive: false) }
    @objc private func restoreDrive() { leaveForOnboarding(restoreFromDrive: true) }

    @objc private func continueToOnboarding() {
        guard !isBusy else { return }
        leaveForOnboarding()
    }

    @objc private func confirmSetUpAgain() {
        guard !isBusy else { return }
        WalletSetUpAgainConfirmation.present(on: self, movesWalletData: false) { [weak self] in
            // Nothing is moved here: there is no wallet database. The Keychain
            // items stay.
            self?.leaveForOnboarding()
        }
    }

    /// Setup is marked before import. Ownership bindings stay independent of
    /// the current app PIN; no earlier PIN value is copied or trusted.
    func leaveForOnboarding(restoreFromDrive: Bool? = nil) {
        // The destination belongs to this choice. Cancelling its confirmation
        // must not send a later "Set up this iPhone again" choice to restore.
        let proceed: () -> Void = { [weak self] in
            guard let self else { return }
            self.setBusy(true)
            let keystore = self.keystore
            let settings = self.settings
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result {
                    try WalletPendingPinSetup.leaveWelcomeBack(keystore: keystore, settings: settings)
                }
                DispatchQueue.main.async {
                    self.setBusy(false)
                    switch result {
                    case .success:
                        if let drive = restoreFromDrive, let onRestore = self.onRestore { onRestore(drive) }
                        else { self.onContinueToOnboarding() }
                    case .failure:
                        self.showEarlierPinNotKept(restoreFromDrive: restoreFromDrive)
                    }
                }
            }
        }
        guard options.canRestoreExistingKeys else {
            proceed()
            return
        }
        let alert = UIAlertController(
            title: WalletUX.text("Restore the wallets found on this iPhone first?"),
            message: WalletUX.text("Wallets saved on this iPhone can be restored now with the PIN you used before. If you continue without them, their keys stay on this iPhone, and you can restore them later from Add account with that PIN, or with their recovery phrase or Google Drive backup."),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("Restore them now"), style: .default) { [weak self] _ in
            self?.restoreFoundWallets()
        })
        alert.addAction(UIAlertAction(title: WalletUX.text("Continue without them"), style: .default) { _ in
            proceed()
        })
        alert.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func showEarlierPinNotKept(restoreFromDrive: Bool?) {
        let alert = UIAlertController(
            title: WalletUX.text("Could not prepare wallet setup"),
            message: WalletUX.text("SORA could not prepare the new wallet setup. The earlier wallet keys and their ownership PIN protection are unchanged. Try again, or restore the wallets first."),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("Try again"), style: .default) { [weak self] _ in
            self?.leaveForOnboarding(restoreFromDrive: restoreFromDrive)
        })
        if options.canRestoreExistingKeys {
            alert.addAction(UIAlertAction(title: WalletUX.text("Restore them now"), style: .default) { [weak self] _ in
                self?.restoreFoundWallets()
            })
        }
        alert.addAction(UIAlertAction(title: WalletUX.text("Contact support"), style: .default) { [weak self] _ in
            self?.openSupport()
        })
        alert.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func openSupport() {
        UIApplication.shared.open(ApplicationConfig.shared.supportURL)
    }

    @objc private func restoreFoundWallets() {
        guard !isBusy, options.canRestoreExistingKeys else { return }
        WalletRetainedWalletRestoreFlow.run(on: self, scope: .welcomeBack, setBusy: { [weak self] busy in
            self?.setBusy(busy, status: busy ? WalletUX.text("Checking the keys saved on this iPhone…") : nil)
        }) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case let .restored(_, failed) where failed == 0:
                self.onWalletsRestored()
            case let .restored(count, failed):
                // Some wallets are in; continue to them. The others stay in
                // the Keychain and can be restored from Add account.
                self.present(WalletRetainedWalletRestoreFlow.partialAlert(restored: count, failed: failed) {
                    [weak self] in
                    self?.onWalletsRestored()
                }, animated: true)
            case let .nothingRestored(message):
                self.showError(message)
                self.refreshOptions()
            case let .setupRequired(_, message):
                let alert = UIAlertController(title: WalletUX.text("Complete PIN setup"),
                    message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: WalletUX.text("Continue"), style: .default) { _ in
                    self.onWalletsRestored()
                })
                self.present(alert, animated: true)
            }
        }
    }

    @objc private func showPhrase() {
        guard !isBusy, options.canShowPhraseAfterPin else { return }
        WalletPinPrompt.present(on: self, message: WalletUX.text(
            "Enter the PIN you used for SORA on this iPhone to show your recovery phrase."
        )) { [weak self] pin in
            guard let self else { return }
            self.setBusy(true)
            DispatchQueue.global(qos: .userInitiated).async {
                var pin = pin
                defer { pin.removeAll(keepingCapacity: false) }
                let keychain = self.keystore
                let result = Result { () -> [WalletRecoveryPhraseReveal.Entry] in
                    let wallets = try RetainedKeychainWalletDiscovery.inventory(keystore: keychain).adoptable
                    let accounts = wallets.map {
                        AccountItem(address: $0.address, cryptoType: $0.cryptoType, networkType: $0.networkType,
                                    username: "", publicKeyData: $0.publicKey,
                                    settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
                                    order: 0, isSelected: false)
                    }
                    return try WalletRecoveryPhraseReveal.reveal(
                        pin: pin, accounts: accounts, keystore: keychain, settings: self.settings)
                }
                DispatchQueue.main.async {
                    self.setBusy(false)
                    switch result {
                    case let .success(entries):
                        WalletPinPrompt.presentPhrases(entries, on: self)
                    case let .failure(error):
                        self.showError(WalletPinPrompt.message(for: error))
                    }
                    self.refreshOptions()
                }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: WalletUX.text("Nothing was changed"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
        present(alert, animated: true)
    }
}

/// Shared by Welcome back and onboarding. File return always ends in the
/// normal startup verifier; it never opens a wallet directly.
enum WalletPreservedDataRestoration {
    static func present(on controller: UIViewController, onRestored: @escaping () -> Void) {
        let paths: WalletLocalStateSetAside.Paths
        do { paths = try .production() } catch { return }
        let settings = SettingsManager.shared
        let keys = Keychain()
        controller.view.isUserInteractionEnabled = false
        DispatchQueue.global(qos: .userInitiated).async {
            let folders = WalletPreservedGeneration.available(paths: paths, settings: settings)
            DispatchQueue.main.async {
                controller.view.isUserInteractionEnabled = true
                guard !folders.isEmpty else { return }
                if folders.count == 1 {
                    begin(folder: folders[0], paths: paths, controller: controller, onRestored: onRestored)
                } else {
                    let alert = UIAlertController(title: WalletUX.text("Use the earlier wallet data again"),
                        message: WalletUX.text("Choose the saved wallet data to check. Your current wallet must be empty."),
                        preferredStyle: .actionSheet)
                    for (index, folder) in folders.enumerated() {
                        alert.addAction(UIAlertAction(title: WalletUX.format("Saved wallet data %d", index + 1), style: .default) { _ in
                            begin(folder: folder, paths: paths, controller: controller, onRestored: onRestored)
                        })
                    }
                    alert.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
                    alert.popoverPresentationController?.sourceView = controller.view
                    controller.present(alert, animated: true)
                }
            }
        }
    }

    private static func begin(folder: URL, paths: WalletLocalStateSetAside.Paths,
                              controller: UIViewController, onRestored: @escaping () -> Void) {
        controller.view.isUserInteractionEnabled = false
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { () -> Set<String> in
                let keys = Keychain()
                let rows = try WalletPreservedGeneration.accounts(folder: folder, paths: paths,
                    settings: SettingsManager.shared, keystore: keys)
                var required = Set<String>()
                let legacy = try keys.checkKey(for: KeystoreTag.legacyEntropy.rawValue)
                for row in rows {
                    let tags = [KeystoreTag.secretKeyTagForAddress(row.address),
                                KeystoreTag.entropyTagForAddress(row.address), KeystoreTag.seedTagForAddress(row.address)]
                    if try legacy || tags.contains(where: { try keys.checkKey(for: $0) }) { required.insert(row.address) }
                }
                guard required.isSubset(of: try WalletOwnerPIN.boundAddresses(keystore: keys)) else {
                    throw WalletPreservedGeneration.Failure.ownerPINRequired
                }
                return required
            }
            DispatchQueue.main.async {
                controller.view.isUserInteractionEnabled = true
                switch result {
                case .success(let required):
                    authorize(remaining: required, grants: [], folder: folder, paths: paths,
                              controller: controller, onRestored: onRestored)
                case .failure(let error): show(error, on: controller)
                }
            }
        }
    }

    private static func authorize(remaining: Set<String>, grants: [WalletOwnerPIN.RetainedAuthorization],
                                  folder: URL, paths: WalletLocalStateSetAside.Paths,
                                  controller: UIViewController, onRestored: @escaping () -> Void) {
        guard !remaining.isEmpty else {
            choosePIN(grants: grants, folder: folder, paths: paths, controller: controller, onRestored: onRestored)
            return
        }
        WalletPinPrompt.present(on: controller,
            message: WalletUX.text("Enter the PIN that protected these wallets. If they used different PINs, you will be asked for each one.")) { pin in
            controller.view.isUserInteractionEnabled = false
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try WalletOwnerPIN(keystore: Keychain(), settings: SettingsManager.shared)
                    .authorizeRetained(pin, addresses: remaining) }
                DispatchQueue.main.async {
                    controller.view.isUserInteractionEnabled = true
                    switch result {
                    case .success(let grant):
                        authorize(remaining: remaining.subtracting(grant.addresses), grants: grants + [grant],
                            folder: folder, paths: paths, controller: controller, onRestored: onRestored)
                    case .failure(let error): show(error, on: controller)
                    }
                }
            }
        }
    }

    private static func choosePIN(grants: [WalletOwnerPIN.RetainedAuthorization], folder: URL,
                                  paths: WalletLocalStateSetAside.Paths, controller: UIViewController,
                                  onRestored: @escaping () -> Void) {
        let alert = UIAlertController(title: WalletUX.text("Protect the returned wallets"),
            message: WalletUX.text("Choose the app PIN for the returned wallets. Their files will move back, their keys will stay on this iPhone, and SORA will check them before opening. From now on, these wallets will use this PIN."),
            preferredStyle: .alert)
        for title in [WalletUX.text("App PIN"), WalletUX.text("Confirm app PIN")] {
            alert.addTextField { field in
                field.placeholder = title; field.isSecureTextEntry = true; field.keyboardType = .numberPad
                field.textContentType = .newPassword
            }
        }
        alert.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: WalletUX.text("Use earlier wallet data"), style: .default) { _ in
            guard let pin = alert.textFields?.first?.text,
                  pin == alert.textFields?.last?.text else { show(WalletOwnerPIN.Failure.invalidPIN, on: controller); return }
            alert.textFields?.forEach { $0.text = nil }
            controller.view.isUserInteractionEnabled = false
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try WalletPreservedGeneration.restore(folder: folder, paths: paths,
                    settings: SettingsManager.shared, keystore: Keychain(), grants: grants, newPIN: pin) }
                DispatchQueue.main.async {
                    controller.view.isUserInteractionEnabled = true
                    switch result {
                    case .success: onRestored()
                    case .failure(let error): show(error, on: controller)
                    }
                }
            }
        })
        controller.present(alert, animated: true)
    }

    private static func show(_ error: Error, on controller: UIViewController) {
        let message: String
        if case WalletPreservedGeneration.Failure.ownerPINRequired = error {
            message = WalletUX.text("These wallets were saved by an older version without an ownership PIN. Restore them with their recovery phrase or Google Drive backup. The earlier files and keys remain on this iPhone.")
        } else if error is WalletRetainedPinGate.Failure || error is WalletOwnerPIN.Failure {
            message = WalletPinPrompt.message(for: error)
        } else {
            message = WalletUX.text("The earlier data could not be returned safely. Its files and keys have been kept. Reopen SORA to resume an interrupted return, or restore with your original backup.")
        }
        let alert = UIAlertController(title: WalletUX.text("Earlier wallet data not opened"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
        controller.present(alert, animated: true)
    }
}
