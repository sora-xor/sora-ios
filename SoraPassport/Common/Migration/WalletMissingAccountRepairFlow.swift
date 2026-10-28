// Copyright (c) 2026, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

import UIKit
import SoraKeystore

/// Import-only consent. Retained bytes alone never open this flow or authorize
/// replacement; the caller owns a freshly verified PreparedAccount.
final class WalletMissingAccountRepairFlow {
    private weak var controller: UIViewController?
    private let keystore: KeystoreProtocol
    private let selection: SelectedWalletSettingsProtocol
    private var request: Request?
    private let loadAccounts: () throws -> [AccountItem]

    static func currentAccountsForRepair() throws -> [AccountItem] {
        let lease = WalletLifecycleCoordinator.shared.acquire()
        defer { lease.release() }
        try WalletRecoveryCapabilityGate.shared.requireCredentialRepairAccess()
        return try WalletAccountCapability.currentAccounts()
    }

    init(controller: UIViewController, keystore: KeystoreProtocol,
         selection: SelectedWalletSettingsProtocol,
         loadAccounts: @escaping () throws -> [AccountItem] = WalletMissingAccountRepairFlow.currentAccountsForRepair) {
        self.controller = controller
        self.keystore = keystore
        self.selection = selection
        self.loadAccounts = loadAccounts
    }

    /// Read-only, called while the ordinary import holds its lifecycle lease.
    func requiresExplicitRepair(_ prepared: PreparedAccount) throws -> Bool {
        do { try prepared.validatePersistence(to: keystore); return false }
        catch AccountCreateError.retainedKeyConflict { return true }
    }

    @MainActor
    func begin(_ prepared: PreparedAccount, completion: @escaping (Result<AccountItem, Error>) -> Void) {
        guard request == nil, let controller, controller.viewIfLoaded?.window != nil,
              controller.presentedViewController == nil else {
            prepared.discard(); completion(.failure(CancellationError())); return
        }
        let request = Request(flow: self, controller: controller, prepared: prepared, completion: completion)
        self.request = request
        request.start()
    }

    private enum CompletionFailure: LocalizedError {
        case walletChecksRequired
        var errorDescription: String? {
            WalletUX.text("Your repaired keys and preserved originals are saved. Reopen the app to complete wallet recovery before sending.")
        }
    }

    @MainActor
    private final class Request {
        private let flow: WalletMissingAccountRepairFlow
        private weak var controller: UIViewController?
        private let prepared: PreparedAccount
        private var completion: ((Result<AccountItem, Error>) -> Void)?
        private var observers: [NSObjectProtocol] = []
        private weak var alert: UIAlertController?
        private var confirmed = false

        init(flow: WalletMissingAccountRepairFlow, controller: UIViewController, prepared: PreparedAccount,
             completion: @escaping (Result<AccountItem, Error>) -> Void) {
            self.flow = flow; self.controller = controller; self.prepared = prepared; self.completion = completion
        }
        func start() {
            for name in [UIApplication.willResignActiveNotification, UIScreen.capturedDidChangeNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.cancelBeforeConfirmation() }
                })
            }
            let loadAccounts = flow.loadAccounts
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let result = Result<[AccountItem], Error> {
                    try loadAccounts()
                }
                Task { @MainActor in
                    guard self.completion != nil else { return }
                    switch result {
                    case .success(let accounts): self.present(accounts: accounts)
                    case .failure(let error): self.finish(.failure(error))
                    }
                }
            }
        }
        private func present(accounts: [AccountItem]) {
            guard let controller, controller.viewIfLoaded?.window != nil,
                  controller.presentedViewController == nil,
                  !(controller.view.window?.windowScene?.screen.isCaptured ?? UIScreen.main.isCaptured) else {
                finish(.failure(CancellationError())); return
            }
            let empty = accounts.isEmpty
            let message = WalletUX.text("This backup proves the imported address, but different credentials remain on this iPhone. The earlier credentials will be preserved before repair.") + "\n\n" +
                WalletUX.text(empty
                    ? "Choose and confirm a new app PIN for this restored wallet. The previous install's PIN will not be used."
                    : "Enter the current app PIN to confirm the repair. This restored wallet will use that PIN.") + "\n\n" + prepared.account.address
            let alert = UIAlertController(title: WalletUX.text("Confirm wallet repair"), message: message, preferredStyle: .alert)
            self.alert = alert
            for (index, key) in (empty ? ["New app PIN", "Confirm app PIN"] : ["Current app PIN"]).enumerated() {
                alert.addTextField { field in
                    field.isSecureTextEntry = true
                    field.keyboardType = .numberPad
                    field.textContentType = empty ? .newPassword : .password
                    field.placeholder = WalletUX.text(key)
                    field.accessibilityIdentifier = "wallet-import-repair-pin-\(index)"
                }
            }
            alert.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel) { [weak self] _ in
                self?.finish(.failure(CancellationError()))
            })
            alert.addAction(UIAlertAction(title: WalletUX.text("Repair wallet"), style: .default) { [weak self, weak alert] _ in
                guard let self, self.completion != nil,
                      !(controller.view.window?.windowScene?.screen.isCaptured ?? UIScreen.main.isCaptured) else { return }
                let pin = alert?.textFields?.first?.text ?? ""
                let confirmation = alert?.textFields?.last?.text ?? ""
                alert?.textFields?.forEach { $0.text = "" }
                self.confirmed = true
                self.removeObservers()
                let authentication: WalletCredentialRepair.ImportAuthentication = empty
                    ? .newPIN(pin, confirmation: confirmation) : .currentPIN(pin)
                self.perform(authentication: authentication, existing: accounts.first { $0.address == self.prepared.account.address })
            })
            controller.present(alert, animated: true)
        }
        private func perform(authentication: WalletCredentialRepair.ImportAuthentication, existing: AccountItem?) {
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let service = WalletCredentialRepair(keystore: flow.keystore, settings: SettingsManager.shared)
                if let existing {
                    do {
                        guard case .currentPIN(let pin) = authentication,
                              WalletCredentialRepair.sameIdentity(existing, prepared.account) else {
                            throw WalletCredentialRepair.Failure.accountChanged
                        }
                        _ = try service.repair(prepared: prepared, currentAccounts: WalletAccountCapability.currentAccounts,
                                               pin: pin, explicitlyConfirmed: true)
                        WalletAccountCapability.refreshAfterRepair(existing) { result in
                            switch result {
                            case .success:
                                self.flow.selection.performSave(value: existing) { result in
                                    Task { @MainActor in
                                        self.finish(result.mapError { _ in CompletionFailure.walletChecksRequired })
                                    }
                                }
                            case .failure: Task { @MainActor in self.finish(.failure(CompletionFailure.walletChecksRequired)) }
                            }
                        }
                    } catch { Task { @MainActor in self.finish(.failure(error)) } }
                } else {
                    service.importMissingAccount(prepared: prepared, currentAccounts: WalletAccountCapability.currentAccounts,
                        authentication: authentication, explicitlyConfirmed: true, selection: flow.selection) { result in
                            Task { @MainActor in self.finish(result) }
                        }
                }
            }
        }
        private func cancelBeforeConfirmation() {
            guard !confirmed, completion != nil else { return }
            alert?.textFields?.forEach { $0.text = "" }
            alert?.dismiss(animated: false)
            finish(.failure(CancellationError()))
        }
        private func removeObservers() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
        }
        private func finish(_ result: Result<AccountItem, Error>) {
            guard let completion else { return }
            self.completion = nil
            removeObservers()
            alert?.textFields?.forEach { $0.text = "" }
            prepared.discard()
            flow.request = nil
            completion(result)
        }
    }
}
