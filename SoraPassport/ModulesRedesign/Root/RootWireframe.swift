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
            onWalletsRestored: restart
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
            onSetAside: onRetry
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

/// A fail-closed surface used when wallet integrity or account-bound context
/// cannot be proven.
/// It has no reset or logout action: it never deletes wallet data. Every
/// state offers a way forward (see `WalletRecoveryOptions`); "Set up this
/// iPhone again" moves this install's wallet files aside and never touches
/// the Keychain.
final class WalletRecoveryViewController: UIViewController {
    private let reason: String?
    private let diagnostic: WalletStartupDiagnostic?
    private let onRetry: (() -> Void)?
    private let onSetAside: (() -> Void)?
    private let retryButton = UIButton(type: .system)
    private let restoreKeysButton = UIButton(type: .system)
    private let restoreCloudBackupButton = UIButton(type: .system)
    private let showPhraseButton = UIButton(type: .system)
    private let setUpAgainButton = UIButton(type: .system)
    private let cloudRecoveryStatusLabel = UILabel()
    private var didRetry = false
    private let exportButton = UIButton(type: .system)
    private let exportProgress = UIActivityIndicatorView(style: .medium)
    private let exportStatusLabel = UILabel()
    private var isExporting = false
    private var isRestoringKeys = false
    private(set) var options = WalletRecoveryOptions()

    init(reason: String?, diagnostic: WalletStartupDiagnostic? = nil, onRetry: (() -> Void)? = nil,
         onSetAside: (() -> Void)? = nil) {
        self.reason = reason
        self.diagnostic = diagnostic
        self.onRetry = onRetry
        self.onSetAside = onSetAside
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

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.text = "Wallet recovery"
        titleLabel.numberOfLines = 0

        retryButton.setTitle(WalletUX.text("Try again"), for: .normal)
        retryButton.accessibilityIdentifier = "wallet-recovery-retry"
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        retryButton.isHidden = onRetry == nil
        retryButton.addTarget(self, action: #selector(retryWalletVerification), for: .touchUpInside)

        // Restore actions are shown from facts (accounts whose keys are
        // missing), not from the cause recorded by the latest check.
        restoreKeysButton.setTitle(WalletUX.text("Restore existing wallet keys"), for: .normal)
        restoreKeysButton.accessibilityIdentifier = "wallet-recovery-restore-keys"
        restoreKeysButton.isHidden = true
        restoreKeysButton.addTarget(self, action: #selector(chooseKeyRecoveryAccount), for: .touchUpInside)

        restoreCloudBackupButton.setTitle(WalletUX.text("Restore from Google Drive backup"), for: .normal)
        restoreCloudBackupButton.accessibilityIdentifier = "wallet-recovery-restore-cloud-backup"
        restoreCloudBackupButton.isHidden = true
        restoreCloudBackupButton.addTarget(self, action: #selector(chooseCloudRecoveryAccount), for: .touchUpInside)

        showPhraseButton.setTitle(WalletUX.text("Show my recovery phrase"), for: .normal)
        showPhraseButton.accessibilityIdentifier = "wallet-recovery-show-phrase"
        showPhraseButton.isHidden = true
        showPhraseButton.addTarget(self, action: #selector(showRecoveryPhrase), for: .touchUpInside)

        setUpAgainButton.setTitle(WalletUX.text("Set up this iPhone again"), for: .normal)
        setUpAgainButton.accessibilityIdentifier = "wallet-recovery-set-up-again"
        setUpAgainButton.isHidden = onSetAside == nil
        setUpAgainButton.addTarget(self, action: #selector(confirmSetUpAgain), for: .touchUpInside)
        cloudRecoveryStatusLabel.font = .preferredFont(forTextStyle: .footnote)
        cloudRecoveryStatusLabel.textColor = .secondaryLabel
        cloudRecoveryStatusLabel.numberOfLines = 0
        cloudRecoveryStatusLabel.isHidden = true
        cloudRecoveryStatusLabel.accessibilityIdentifier = "wallet-recovery-cloud-status"

        let bodyLabel = UILabel()
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.text = [
            diagnostic?.userMessage ?? WalletUX.text("SORA could not verify the wallet for this operation, so it stopped before continuing. It did not delete, replace, log out, or recreate any account."),
            WalletUX.text("SORA stopped before changing anything and did not delete or replace any wallet data. Try again, restore with your recovery phrase or Google Drive backup, or contact SORA support with the app version shown below. Never share your recovery phrase.")
        ].compactMap { $0 }.joined(separator: "\n\n")

        let diagnosticLabel = UILabel()
        diagnosticLabel.font = .preferredFont(forTextStyle: .footnote)
        diagnosticLabel.textColor = .secondaryLabel
        diagnosticLabel.numberOfLines = 0
        diagnosticLabel.accessibilityIdentifier = "wallet-recovery-diagnostic"
        diagnosticLabel.text = diagnostic?.summary ?? "No detailed check was recorded by the previous build. Tap Try again to collect the current failure."

        let versionLabel = UILabel()
        versionLabel.font = .preferredFont(forTextStyle: .footnote)
        versionLabel.textColor = .tertiaryLabel
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        versionLabel.text = "SORA \(version) (\(build))"

        let supportButton = UIButton(type: .system)
        supportButton.setTitle("Open SORA support", for: .normal)
        supportButton.addTarget(
            self,
            action: #selector(openSupport),
            for: .touchUpInside
        )

        let detailsButton = UIButton(type: .system)
        detailsButton.setTitle("Copy recovery details", for: .normal)
        detailsButton.accessibilityIdentifier = "wallet-recovery-copy-details"
        detailsButton.addTarget(
            self,
            action: #selector(copyRecoveryDetails),
            for: .touchUpInside
        )

        exportButton.setTitle(
            "Create protected recovery export",
            for: .normal
        )
        exportButton.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .recoveryExportAccessibilityIdentifier
        exportButton.titleLabel?.font = .preferredFont(
            forTextStyle: .headline
        )
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
        backupHelpButton.setTitle("Recovery export help", for: .normal)
        backupHelpButton.addTarget(
            self,
            action: #selector(showBackupHelp),
            for: .touchUpInside
        )

        let stack = UIStackView(
            arrangedSubviews: [
                titleLabel,
                retryButton,
                restoreKeysButton,
                restoreCloudBackupButton,
                cloudRecoveryStatusLabel,
                showPhraseButton,
                setUpAgainButton,
                bodyLabel,
                diagnosticLabel,
                versionLabel,
                supportButton,
                detailsButton,
                exportButton,
                exportProgress,
                exportStatusLabel,
                backupHelpButton
            ]
        )
        stack.axis = .vertical
        stack.spacing = 20
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
        let canAct = onRetry != nil
        restoreKeysButton.isHidden = !(options.canRestoreExistingKeys && canAct)
        restoreCloudBackupButton.isHidden = restoreKeysButton.isHidden
        showPhraseButton.isHidden = !options.canShowPhraseAfterPin
        setUpAgainButton.isHidden = !(options.canSetUpDeviceAgain && onSetAside != nil)
        exportButton.isHidden = !options.canExport
    }

    @objc private func retryWalletVerification() {
        guard let onRetry, !didRetry, !isExporting, !isRestoringKeys else { return }
        didRetry = true
        retryButton.isEnabled = false
        restoreKeysButton.isEnabled = false
        restoreCloudBackupButton.isEnabled = false
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
        guard !didRetry, !isExporting, !isRestoringKeys, options.canRestoreExistingKeys else { return }
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
        guard !didRetry, !isExporting, !isRestoringKeys else { return }
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
            guard let self, let prompt, !self.didRetry, !self.isExporting, !self.isRestoringKeys else { return }
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
        showPhraseButton.isEnabled = !busy
        setUpAgainButton.isEnabled = !busy
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
            WalletUX.text("Recovery never deletes wallet keys from this iPhone's Keychain."),
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
        guard !isExporting, !isRestoringKeys else {
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
        guard !isExporting, !isRestoringKeys else {
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
            return WalletUX.text("No PIN from an earlier install was found. Use your recovery phrase or Google Drive backup.")
        case .earlierPinNotKept?:
            return WalletUX.text("SORA could not save a copy of the PIN you used before. Nothing was changed. Try again.")
        case nil:
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
    private let hiddenLabel = UILabel()
    private var observers: [NSObjectProtocol] = []

    init(entries: [WalletRecoveryPhraseReveal.Entry]) {
        self.entries = entries
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "wallet-recovery-phrase"

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.numberOfLines = 0
        titleLabel.text = WalletUX.text("Your recovery phrase")

        let warningLabel = UILabel()
        warningLabel.font = .preferredFont(forTextStyle: .body)
        warningLabel.textColor = .secondaryLabel
        warningLabel.numberOfLines = 0
        warningLabel.text = [
            WalletUX.text("Write these words down in order and keep them offline. Anyone with them can take your funds."),
            R.string.localizable.screenshotAlertText(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages),
        ].joined(separator: "\n\n")

        wordsLabel.font = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                                                weight: .regular)
        wordsLabel.numberOfLines = 0
        wordsLabel.accessibilityIdentifier = "wallet-recovery-phrase-words"
        hiddenLabel.font = .preferredFont(forTextStyle: .body)
        hiddenLabel.textColor = .secondaryLabel
        hiddenLabel.numberOfLines = 0
        hiddenLabel.text = WalletUX.text("The words are hidden while the screen is being recorded or shared.")
        hiddenLabel.isHidden = true

        let doneButton = UIButton(type: .system)
        doneButton.setTitle(WalletUX.text("Done"), for: .normal)
        doneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        doneButton.accessibilityIdentifier = "wallet-recovery-phrase-done"
        doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, warningLabel, wordsLabel, hiddenLabel, doneButton])
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
                [weak self] _ in self?.setWordsVisible(false)
            },
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) {
                [weak self] _ in self?.updateVisibility()
            },
            center.addObserver(forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main) {
                [weak self] _ in self?.updateVisibility()
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
        setWordsVisible(UIApplication.shared.applicationState == .active && !isCaptured)
    }

    private func setWordsVisible(_ visible: Bool) {
        if visible {
            wordsLabel.text = entries.map { entry in
                let words = entry.words.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                let name = entry.name.isEmpty ? String(entry.address.prefix(8)) + "…" : entry.name
                return "\(name)\n\(words)"
            }.joined(separator: "\n\n")
        } else {
            wordsLabel.text = nil
        }
        wordsLabel.isHidden = !visible
        hiddenLabel.isHidden = visible || UIApplication.shared.applicationState != .active
    }

    private func warnAboutScreenshot() {
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        let alert = UIAlertController(
            title: R.string.localizable.screenshotAlertTitle(preferredLanguages: languages),
            message: R.string.localizable.screenshotAlertText(preferredLanguages: languages),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
        present(alert, animated: true)
    }

    @objc private func done() {
        wordsLabel.text = nil
        entries = []
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
                ? WalletUX.text("SORA will start fresh on this iPhone. Wallet keys saved on this iPhone are not deleted, and the earlier wallet data is moved to a separate folder on this iPhone. On the next screen you can restore the wallets whose keys are on this iPhone with the PIN you used before, or any wallet with its recovery phrase or Google Drive backup.")
                : WalletUX.text("SORA will start fresh on this iPhone. Wallet keys saved on this iPhone are not deleted. You can restore any wallet later with its recovery phrase or Google Drive backup, and the wallets found on this iPhone from Add account with the PIN you used before."),
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
    }

    static func run(
        on controller: UIViewController,
        scope: WalletRetainedPinGate.Scope,
        setBusy: @escaping (Bool) -> Void,
        completion: @escaping (Outcome) -> Void
    ) {
        WalletPinPrompt.present(on: controller, message: WalletUX.text(
            "Enter the PIN you used for SORA on this iPhone. Wallets whose saved keys match their address will be restored."
        )) { pin in
            setBusy(true)
            DispatchQueue.global(qos: .userInitiated).async {
                var pin = pin
                defer { pin.removeAll(keepingCapacity: false) }
                let keychain = Keychain()
                let outcome: Outcome
                do {
                    let matchedCurrentPin = try WalletRetainedPinGate.verify(
                        pin, keystore: keychain, settings: SettingsManager.shared, scope: scope)
                    if scope == .welcomeBack {
                        // Wallets that are not restored now (one fails, or
                        // the user adds others later) stay restorable from
                        // Add account with this same PIN.
                        _ = try? WalletRetainedPinGate.preserveEarlierInstallPin(keystore: keychain)
                    }
                    let existing = try WalletAccountAddresses.current()
                    let inventory = try RetainedKeychainWalletDiscovery.inventory(
                        keystore: keychain, excluding: existing)
                    let result = RetainedKeychainWalletDiscovery.restore(
                        inventory.adoptable,
                        existing: existing,
                        keystore: keychain,
                        selectedWalletSettings: SelectedWalletSettings.shared
                    )
                    if !result.restored.isEmpty {
                        if scope == .welcomeBack {
                            // A PIN that matched only an earlier copy is not
                            // the PIN the app asks for next: set a new one
                            // first (PIN setup keeps the current one).
                            WalletPendingPinSetup.settleAfterWelcomeBackRestore(
                                matchedCurrentPin: matchedCurrentPin, settings: SettingsManager.shared)
                        }
                        outcome = .restored(count: result.restored.count, failed: result.failedAddresses.count)
                    } else if let error = result.firstError {
                        outcome = .nothingRestored(message: WalletPinPrompt.message(for: error))
                    } else {
                        outcome = .nothingRestored(message: WalletUX.text(
                            "No wallet on this iPhone could be verified. Use your recovery phrase or Google Drive backup."))
                    }
                } catch {
                    outcome = .nothingRestored(message: WalletPinPrompt.message(for: error))
                }
                DispatchQueue.main.async {
                    setBusy(false)
                    completion(outcome)
                }
            }
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
    private let restoreFoundButton = UIButton(type: .system)
    private let showPhraseButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let progress = UIActivityIndicatorView(style: .medium)
    private var isBusy = false
    private(set) var options = WalletRecoveryState
        .welcomeBack(adoptableWallets: 0, walletsWithPhrase: 0, retainedPinUsable: false).options

    init(keystore: KeystoreProtocol = Keychain(),
         settings: SettingsManagerProtocol = SettingsManager.shared,
         onContinueToOnboarding: @escaping () -> Void,
         onWalletsRestored: @escaping () -> Void) {
        self.keystore = keystore
        self.settings = settings
        self.onContinueToOnboarding = onContinueToOnboarding
        self.onWalletsRestored = onWalletsRestored
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "wallet-welcome-back"

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.numberOfLines = 0
        titleLabel.text = WalletUX.text("Welcome back")

        let bodyLabel = UILabel()
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.text = WalletUX.text("We found SORA data from an earlier install on this iPhone. Choose how to continue. Nothing will be deleted.")

        restoreFoundButton.setTitle(WalletUX.text("Restore wallets found on this iPhone"), for: .normal)
        restoreFoundButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        restoreFoundButton.accessibilityIdentifier = "wallet-welcome-back-restore-found"
        restoreFoundButton.isHidden = true
        restoreFoundButton.addTarget(self, action: #selector(restoreFoundWallets), for: .touchUpInside)

        let phraseButton = makeButton(WalletUX.text("Restore with recovery phrase"),
                                      identifier: "wallet-welcome-back-phrase")
        let driveButton = makeButton(WalletUX.text("Restore from Google Drive"),
                                     identifier: "wallet-welcome-back-drive")
        showPhraseButton.setTitle(WalletUX.text("Show my recovery phrase"), for: .normal)
        showPhraseButton.accessibilityIdentifier = "wallet-welcome-back-show-phrase"
        showPhraseButton.isHidden = true
        showPhraseButton.addTarget(self, action: #selector(showPhrase), for: .touchUpInside)
        let setUpButton = UIButton(type: .system)
        setUpButton.setTitle(WalletUX.text("Set up this iPhone again"), for: .normal)
        setUpButton.accessibilityIdentifier = "wallet-welcome-back-set-up-again"
        setUpButton.addTarget(self, action: #selector(confirmSetUpAgain), for: .touchUpInside)
        let supportButton = UIButton(type: .system)
        supportButton.setTitle(WalletUX.text("Contact support"), for: .normal)
        supportButton.addTarget(self, action: #selector(openSupport), for: .touchUpInside)

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        progress.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, bodyLabel, restoreFoundButton, phraseButton, driveButton,
            showPhraseButton, setUpButton, supportButton, progress, statusLabel,
        ])
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
        refreshOptions()
    }

    private func makeButton(_ title: String, identifier: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = identifier
        // Phrase and Google Drive restore use the onboarding import screens,
        // which adopt matching keys already on this iPhone.
        button.addTarget(self, action: #selector(continueToOnboarding), for: .touchUpInside)
        return button
    }

    private func refreshOptions() {
        let keystore = self.keystore
        let settings = self.settings
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let state = WalletRecoveryStateProbe.welcomeBack(keystore: keystore, settings: settings)
            DispatchQueue.main.async {
                self?.apply(state.options)
            }
        }
    }

    func apply(_ options: WalletRecoveryOptions) {
        self.options = options
        restoreFoundButton.isHidden = !options.canRestoreExistingKeys
        showPhraseButton.isHidden = !options.canShowPhraseAfterPin
    }

    private func setBusy(_ busy: Bool, status: String? = nil) {
        isBusy = busy
        busy ? progress.startAnimating() : progress.stopAnimating()
        statusLabel.text = status
        view.isUserInteractionEnabled = !busy
    }

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

    /// Onboarding ends by setting a new PIN, which replaces the PIN of the
    /// earlier install. While wallets found on this iPhone are not restored,
    /// offer to restore them first. Leaving requires a stored copy of the
    /// earlier PIN (add-only, read back) so they can still be restored with
    /// it later from Add account; if it cannot be kept, the user stays here
    /// with Try again, Restore them now or Contact support. It also marks
    /// the PIN of this install as not set yet, so a stop before PIN setup
    /// leads back to PIN setup rather than to the earlier PIN.
    func leaveForOnboarding() {
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
                        self.onContinueToOnboarding()
                    case .failure:
                        self.showEarlierPinNotKept()
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

    private func showEarlierPinNotKept() {
        let alert = UIAlertController(
            title: WalletUX.text("Your earlier PIN was not saved"),
            message: WalletUX.text("SORA keeps a copy of the PIN you used before, so the wallets found on this iPhone can still be restored with it after you set a new PIN. The copy could not be saved, so nothing was changed. Try again, or restore the found wallets now."),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("Try again"), style: .default) { [weak self] _ in
            self?.leaveForOnboarding()
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
