// Copyright (c) 2026, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import UIKit
import RobinHood
import SoraKeystore

/// Presentation evidence only. Every signing operation still performs its own
/// authentication, lifecycle and production identity checks.
enum WalletAccountCapability {
    enum State: Equatable {
        case checking, signing, watchOnly, missingKeys, invalidKeys, repairPending, unavailable

        var badge: String? {
            switch self {
            case .signing: return nil
            case .checking: return WalletUX.text("Checking keys…")
            case .watchOnly: return WalletUX.text("Watch-only")
            default: return WalletUX.text("Read-only")
            }
        }

        var reason: String? {
            switch self {
            case .checking: return WalletUX.text("Checking this account’s signing keys…")
            case .signing: return nil
            case .watchOnly: return WalletUX.text("This account was added as watch-only. Sending is disabled.")
            case .missingKeys: return WalletUX.text("Signing keys for this account are missing from this iPhone. Restore its backup to send.")
            case .invalidKeys: return WalletUX.text("The stored signing keys do not prove this account. Restore its backup to send. Existing credentials will be preserved.")
            case .repairPending: return WalletUX.text("A wallet credential repair must finish before sending. Open Restore keys to retry the repair.")
            case .unavailable: return WalletUX.text("Wallet keys or safety checks are unavailable. Unlock this iPhone and retry. If this continues, reopen the app for recovery.")
            }
        }

        var canRestore: Bool { self == .missingKeys || self == .invalidKeys || self == .repairPending }
    }

    /// Caller holds the lifecycle lease. A valid direct key never depends on
    /// auxiliary backups; fallback is allowed only when the direct key is absent.
    static func evaluate(account: AccountItem, keystore: KeystoreProtocol,
                         settings: SettingsManagerProtocol, recoveryGate: WalletRecoveryCapabilityGate,
                         activeSnapshot: WalletNetworkSnapshot? = nil) -> State {
        do {
            try recoveryGate.requireCredentialRepairAccess()
            if settings.allKeys().contains("wallet.watchOnly.\(account.address)") ||
                activeSnapshot?.wallets.first(where: { $0.id == account.address })?.secretSource == .watchOnly { return .watchOnly }
            if try keystore.checkKey(for: WalletCredentialRepair.pendingTag) { return .repairPending }
            let availability = try WalletAccountKeyAvailability.status(for: account, keystore: keystore,
                settings: settings, activeSnapshot: activeSnapshot, recoveryGate: recoveryGate)
            try recoveryGate.requireMutableWalletAccess()
            switch availability {
            case .available: return .signing
            case .watchOnly: return .watchOnly
            case .keysMissing: return .missingKeys
            case .keysNotVerified: return .invalidKeys
            }
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
            return .invalidKeys
        } catch { return .unavailable }
    }

    /// Uses actual current rows, never UserDefaults alone. Called off main and
    /// again inside the repair's lifecycle lease before the first mutation.
    static func currentAccounts() throws -> [AccountItem] {
        let rows = try WalletAccountAddresses.accounts()
        guard Set(rows.map(\.address)).count == rows.count else { throw WalletCredentialRepair.Failure.accountChanged }
        return rows
    }

    static func probe(account: AccountItem, completion: @escaping (State) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let lease = WalletLifecycleCoordinator.shared.acquire()
            let state: State
            do {
                try WalletRecoveryCapabilityGate.shared.requireCredentialRepairAccess()
                guard let current = try currentAccounts().first(where: { sameIdentity($0, account) }) else {
                    throw WalletCredentialRepair.Failure.accountChanged
                }
                let snapshot = try WalletNetworkStore().load()
                state = evaluate(account: current, keystore: Keychain(), settings: SettingsManager.shared,
                    recoveryGate: .shared, activeSnapshot: snapshot)
            } catch { state = .unavailable }
            lease.release()
            DispatchQueue.main.async { completion(state) }
        }
    }

    private static func sameIdentity(_ first: AccountItem, _ second: AccountItem) -> Bool {
        WalletCredentialRepair.sameIdentity(first, second)
    }

    /// Captures the selected identity before the background check and refuses a
    /// stale completion after selection changes. This grants no signing authority.
    @MainActor
    static func preflightSend(from controller: UIViewController?, expectedAddress: String? = nil,
                              currentAccount: @escaping () -> AccountItem? = { SelectedWalletSettings.shared.currentAccount },
                              capabilityProbe: @escaping (AccountItem, @escaping (State) -> Void) -> Void = probe,
                              proceed: @escaping @MainActor () -> Void) {
        guard let controller, let account = currentAccount(),
              expectedAddress == nil || expectedAddress == account.address else { return }
        capabilityProbe(account) { [weak controller] state in
            Task { @MainActor in
                guard let controller, let current = currentAccount(),
                      sameIdentity(current, account), controller.viewIfLoaded?.window != nil,
                      controller.presentedViewController == nil else { return }
                if state == .signing { proceed(); return }
                let alert = UIAlertController(title: state.badge, message: state.reason, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel))
                if state.canRestore {
                    alert.addAction(UIAlertAction(title: WalletUX.text("Restore keys for this account"), style: .default) { _ in
                        presentRepair(account: account, from: controller)
                    })
                } else if state == .unavailable {
                    alert.addAction(UIAlertAction(title: WalletUX.text("Retry"), style: .default) { _ in
                        preflightSend(from: controller, expectedAddress: expectedAddress,
                            currentAccount: currentAccount, capabilityProbe: capabilityProbe, proceed: proceed)
                    })
                }
                controller.present(alert, animated: true)
            }
        }
    }

    @MainActor
    static func presentRepair(account: AccountItem, from controller: UIViewController,
                              configure: ((WalletCredentialRepairViewController) -> Void)? = nil,
                              onSuccess: ((AccountItem) -> Void)? = nil) {
        let repair = WalletCredentialRepairViewController(account: account,
            service: WalletCredentialRepair(keystore: Keychain(), settings: SettingsManager.shared),
            currentAccounts: currentAccounts, onSuccess: { [weak controller] repaired in
                refreshAfterRepair(repaired) { result in
                    Task { @MainActor in
                        guard let controller else { return }
                        controller.dismiss(animated: true) {
                            switch result {
                            case .success:
                                onSuccess?(repaired)
                                EventCenter.shared.notify(with: SelectedAccountChanged())
                            case .failure:
                                let alert = UIAlertController(title: WalletUX.text("Keys repaired; wallet checks need attention"),
                                    message: WalletUX.text("Your repaired keys and preserved originals are saved. Reopen the app to complete wallet recovery before sending."), preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
                                controller.present(alert, animated: true)
                            }
                        }
                    }
                }
            })
        configure?(repair)
        controller.present(UINavigationController(rootViewController: repair), animated: true)
    }

    static func refreshAfterRepair(_ account: AccountItem, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result<Void, Error> {
                let lease = WalletLifecycleCoordinator.shared.acquire()
                defer { lease.release() }
                try WalletRecoveryCapabilityGate.shared.requireMutableWalletAccess()
                let rows = try currentAccounts()
                guard rows.contains(where: { sameIdentity($0, account) }) else { throw WalletCredentialRepair.Failure.accountChanged }
                let selected = try SelectedWalletSettings.resolveSelection(accounts: rows,
                    legacySelectedAddress: SelectedWalletSettings.shared.currentAccount?.address)
                try WalletNetworkModelMigrator(keystore: Keychain(), store: WalletNetworkStore(),
                    settings: SettingsManager.shared).migrate(accounts: rows, selectedAddress: selected?.address,
                                                              lifecycleLease: lease)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }
}
