// Copyright (c) 2026, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

import UIKit
import SoraUIKit

/// Reusable by recovery and read-only account routes. No stored PIN or biometric
/// grant is accepted; the typed PIN reaches the production repair service.
final class WalletCredentialRepairViewController: UIViewController {
    private let account: AccountItem
    private let service: WalletCredentialRepair
    private let currentAccounts: () throws -> [AccountItem]
    private let onSuccess: (AccountItem) -> Void
    private let startWithDrive: Bool
    private let source = WalletRepairSourceControl(items: [WalletUX.text("Recovery phrase"), WalletUX.text("Raw seed"), "JSON", WalletUX.text("Google Drive")])
    private let material = UITextView()
    private let path = UITextField()
    private let password = UITextField()
    private let pin = UITextField()
    private let status = UILabel()
    private let submit = WalletSafeMode.button(.safe, title: WalletUX.text("Review repair"))
    private let retry = WalletSafeMode.button(.secondary, title: WalletUX.text("Retry repair"))
    private let inputs = UIStackView()
    private var busy = false
    private var observers: [NSObjectProtocol] = []
    private var secretShield: WalletSensitiveScreenShield?

    init(account: AccountItem, service: WalletCredentialRepair,
         currentAccounts: @escaping () throws -> [AccountItem], onSuccess: @escaping (AccountItem) -> Void,
         startWithDrive: Bool = false) {
        self.account = account
        self.service = service
        self.currentAccounts = currentAccounts
        self.onSuccess = onSuccess
        self.startWithDrive = startWithDrive
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    /// Explicit duplicate-import continuation; values remain in secure fields
    /// with the same background/capture clearing policy as typed material.
    func setSuppliedMaterial(source format: WalletCredentialRepair.Source, text: String,
                             derivationPath: String, backupPassword: String) {
        loadViewIfNeeded()
        guard !busy else { return }
        source.selectedSegmentIndex = format.rawValue
        sourceChanged()
        material.text = text
        path.text = derivationPath
        password.text = backupPassword
        pin.text = ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WalletUX.page
        view.accessibilityIdentifier = "wallet-credential-repair"
        title = WalletUX.text("Repair wallet credentials")
        let explanation = UILabel()
        WalletSafeMode.body(explanation, alignment: .natural)
        explanation.text = WalletUX.text("Supply a backup for the address below. Failed credentials will be preserved on this iPhone before replacement. This wallet will use the current app PIN.")
        let address = UILabel()
        address.text = account.address
        address.numberOfLines = 0
        address.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        address.textColor = WalletUX.foreground
        address.accessibilityIdentifier = "wallet-repair-address"
        source.selectedSegmentIndex = startWithDrive ? 3 : 0
        source.accessibilityIdentifier = "wallet-repair-source"
        source.addTarget(self, action: #selector(sourceChanged), for: .valueChanged)
        material.font = .preferredFont(forTextStyle: .body)
        material.adjustsFontForContentSizeCategory = true
        material.backgroundColor = WalletUX.surface
        material.textColor = WalletUX.foreground
        material.layer.cornerRadius = 12
        material.isSecureTextEntry = true
        material.autocorrectionType = .no
        material.autocapitalizationType = .none
        material.accessibilityLabel = WalletUX.text("Recovery phrase, raw seed, or JSON backup")
        material.accessibilityIdentifier = "wallet-repair-material"
        material.heightAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        for (field, placeholder, identifier) in [
            (path, "Derivation path (optional)", "wallet-repair-path"),
            (password, "JSON backup password", "wallet-repair-backup-password"),
            (pin, "Current app PIN", "wallet-repair-pin")
        ] {
            field.attributedPlaceholder = NSAttributedString(string: WalletUX.text(placeholder),
                attributes: [.foregroundColor: WalletUX.secondary])
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            field.accessibilityLabel = WalletUX.text(placeholder)
            field.accessibilityIdentifier = identifier
            field.borderStyle = .roundedRect
            field.backgroundColor = WalletUX.surface
            field.textColor = WalletUX.foreground
            field.isSecureTextEntry = true
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        }
        pin.keyboardType = .numberPad
        pin.textContentType = .password
        WalletSafeMode.body(status, alignment: .natural)
        status.accessibilityIdentifier = "wallet-repair-status"
        submit.accessibilityIdentifier = "wallet-repair-review"
        submit.addTarget(self, action: #selector(reviewRepair), for: .touchUpInside)
        retry.accessibilityIdentifier = "wallet-repair-retry"
        retry.addTarget(self, action: #selector(retryRepair), for: .touchUpInside)
        retry.isHidden = (try? service.hasPendingRepair()) != true
        inputs.axis = .vertical
        inputs.spacing = 16
        [source, material, path, password, pin, submit].forEach(inputs.addArrangedSubview)
        let stack = UIStackView(arrangedSubviews: [explanation, address, inputs, status, retry])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        sourceChanged()
        for name in [UIApplication.willResignActiveNotification, UIScreen.capturedDidChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in self?.clearSensitiveInputs()
            })
        }
        secretShield = WalletSensitiveScreenShield(controller: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        secretShield?.refresh()
    }

    @objc private func sourceChanged() {
        password.isHidden = source.selectedSegmentIndex < WalletCredentialRepair.Source.json.rawValue
        path.isHidden = !password.isHidden
        material.isHidden = source.selectedSegmentIndex == 3
        pin.isHidden = source.selectedSegmentIndex == 3
        material.text = ""
        password.text = ""
    }

    private func clearSensitiveInputs() {
        material.text = ""
        password.text = ""
        pin.text = ""
        path.text = ""
        if presentedViewController is UIAlertController { dismiss(animated: false) }
    }

    @objc private func reviewRepair() {
        guard !busy, !(view.window?.windowScene?.screen.isCaptured ?? UIScreen.main.isCaptured) else { return }
        view.endEditing(true)
        let alert = UIAlertController(title: WalletUX.text("Confirm wallet repair"),
            message: WalletUX.text("The supplied backup must restore this exact address. Failed credentials will be preserved before replacement, and this wallet will use the current app PIN.") + "\n\n" + account.address,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: WalletUX.text("Repair wallet"), style: .default) { [weak self] _ in
            self?.confirmRepair()
        })
        present(alert, animated: true)
    }

    // Internal for the controller test: this is the same action as the explicit
    // confirmation button; merely opening the screen or reviewing never writes.
    func confirmRepair() {
        guard !busy, !(view.window?.windowScene?.screen.isCaptured ?? UIScreen.main.isCaptured) else { return }
        let text = material.text ?? "", derivation = path.text ?? ""
        let backupPassword = password.text ?? "", enteredPIN = pin.text ?? ""
        pin.text = ""
        if source.selectedSegmentIndex == 3 {
            // Choosing a source alone never opens Google sign-in or reads Drive.
            // Only this explicitly confirmed action starts the requested read.
            setBusy(true)
            let cloud = WalletCloudBackupRecoveryService(viewController: self)
            Task { @MainActor [self] in
                do {
                    let data = try await cloud.readBackup(for: account.address)
                    // Google sign-in backgrounds the app. Do not retain a typed
                    // PIN across that external UI; require fresh manual entry.
                    pin.text = ""
                    setBusy(false)
                    confirmDriveBackup(data, password: backupPassword)
                } catch {
                    finish(.failure(error))
                }
            }
            return
        }
        guard let format = WalletCredentialRepair.Source(rawValue: source.selectedSegmentIndex) else { return }
        perform {
            let prepared = try self.service.prepare(account: self.account, source: format, text: text,
                derivationPath: derivation, backupPassword: backupPassword)
            defer { prepared.discard() }
            _ = try self.service.repair(prepared: prepared, currentAccounts: self.currentAccounts,
                                       pin: enteredPIN, explicitlyConfirmed: true)
        }
    }

    private func confirmDriveBackup(_ data: Data, password: String) {
        guard !(view.window?.windowScene?.screen.isCaptured ?? UIScreen.main.isCaptured) else { return }
        let alert = UIAlertController(title: WalletUX.text("Confirm wallet repair"),
            message: WalletUX.text("Enter the current app PIN to restore the downloaded backup for this account.") + "\n\n" + account.address,
            preferredStyle: .alert)
        alert.addTextField { field in
            field.isSecureTextEntry = true
            field.keyboardType = .numberPad
            field.placeholder = WalletUX.text("Current app PIN")
            field.accessibilityIdentifier = "wallet-repair-drive-pin"
        }
        alert.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: WalletUX.text("Repair wallet"), style: .default) { [weak self, weak alert] _ in
            guard let self, !(self.view.window?.windowScene?.screen.isCaptured ?? UIScreen.main.isCaptured) else { return }
            let enteredPIN = alert?.textFields?.first?.text ?? ""
            alert?.textFields?.first?.text = ""
            self.perform {
                let prepared = try WalletCloudBackupRecoveryService.prepareForRepair(data: data,
                    password: password, account: self.account, service: self.service)
                defer { prepared.discard() }
                _ = try self.service.repair(prepared: prepared, currentAccounts: self.currentAccounts,
                    pin: enteredPIN, explicitlyConfirmed: true)
            }
        })
        present(alert, animated: true)
    }

    @objc private func retryRepair() {
        guard !busy else { return }
        perform { try self.service.retryPending(account: self.account, currentAccounts: self.currentAccounts) }
    }

    private func perform(_ action: @escaping () throws -> Void) {
        setBusy(true)
        status.text = WalletUX.text("Verifying and preserving wallet credentials…")
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = Swift.Result { try action() }
            DispatchQueue.main.async {
                self.finish(result)
            }
        }
    }

    private func setBusy(_ value: Bool) {
        busy = value
        inputs.isUserInteractionEnabled = !value
        submit.isEnabled = !value
        retry.isEnabled = !value
    }

    private func finish(_ result: Swift.Result<Void, Error>) {
                setBusy(false)
                switch result {
                case .success:
                    self.clearSensitiveInputs()
                    self.status.text = WalletUX.text("Wallet credentials repaired.")
                    self.retry.isHidden = true
                    self.onSuccess(self.account)
                case let .failure(error):
                    self.retry.isHidden = (try? self.service.hasPendingRepair()) != true
                    if error is WalletOwnerPIN.Failure || error is WalletRetainedPinGate.Failure || error is WalletCredentialRepair.Failure {
                        self.status.text = error.localizedDescription
                    } else {
                        self.status.text = WalletUX.text("The backup could not be verified or the repair could not finish. Check the backup and PIN, then try again. Preserved credentials are unchanged.")
                    }
                }
    }
}

/// Full-width choices keep long translations and accessibility text readable.
private final class WalletRepairSourceControl: UIControl {
    var selectedSegmentIndex = 0 { didSet { updateSelection() } }
    private var buttons: [UIButton] = []
    init(items: [String]) {
        super.init(frame: .zero)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        for (index, title) in items.enumerated() {
            let button = WalletUX.button(title) { [weak self] in
                guard let self else { return }
                self.selectedSegmentIndex = index
                self.sendActions(for: .valueChanged)
            }
            button.configuration?.imagePlacement = .leading
            button.configuration?.imagePadding = 10
            button.accessibilityIdentifier = "wallet-repair-source-\(index)"
            buttons.append(button)
            stack.addArrangedSubview(button)
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        updateSelection()
    }
    required init?(coder: NSCoder) { nil }
    private func updateSelection() {
        for (index, button) in buttons.enumerated() {
            let selected = index == selectedSegmentIndex
            button.configuration?.image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle")
            if selected { button.accessibilityTraits.insert(.selected) }
            else { button.accessibilityTraits.remove(.selected) }
        }
    }
}
