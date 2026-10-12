// Copyright (c) 2026, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import Darwin
import CryptoKit
import IrohaCrypto
import SoraKeystore

/// Ownership survives uninstall, independently of this installation's app PIN.
/// Every write is a device-only Keychain item. Call expensive methods off main.
final class WalletOwnerPIN {
    static let bindingSuffix = "-ownerPin"
    static let throttleSuffix = "-ownerPinThrottle"
    static let appThrottleTag = "wallet-app-pin-throttle-v1"
    static let rotationTag = "wallet-owner-pin-rotation-v1"
    static let rebindPrefix = "wallet-owner-pin-rebind-v1-"
    static let setupPrefix = "wallet-owner-pin-setup-v1-"
    private static let lock = NSRecursiveLock()
    private static let processBootFallback = UUID().uuidString

    enum Failure: LocalizedError, Equatable {
        case invalidRecord, authenticationRequired, persistenceFailed, invalidPIN
        var errorDescription: String? {
            switch self {
            case .authenticationRequired:
                return WalletUX.text("Enter the current app PIN to authorize this change.")
            case .invalidPIN:
                return WalletUX.text("Enter a valid PIN.")
            case .invalidRecord, .persistenceFailed:
                return WalletUX.text("The PIN update could not be completed. Try again. Your wallet keys are unchanged.")
            }
        }
    }

    struct Binding: Codable, Equatable {
        let version: Int
        let salt: Data
        let verifier: Data

        init(pin: String) throws {
            version = 1
            salt = try Data.generateRandomBytes(of: 16)
            verifier = try Self.derive(pin, salt: salt)
        }

        func matches(_ pin: String) throws -> Bool {
            guard version == 1, salt.count == 16, verifier.count == 32 else {
                throw Failure.invalidRecord
            }
            var candidate = try Self.derive(pin, salt: salt)
            defer { candidate.resetBytes(in: 0..<candidate.count) }
            return LegacySoraIdentityValidator.constantTimeEqual(candidate, verifier)
        }

        private static func derive(_ pin: String, salt: Data) throws -> Data {
            var input = Data(pin.utf8)
            defer { input.resetBytes(in: 0..<input.count) }
            return try IRScryptKeyDeriviation().deriveKey(
                from: input, salt: salt, scryptN: 32768, scryptP: 1, scryptR: 8, length: 32)
        }
    }

    struct Throttle: Codable, Equatable {
        var failures: Int
        var wait: TimeInterval
        var uptime: TimeInterval
        var boot: String
    }

    private struct Rotation: Codable {
        let version: Int
        let pin: Data
        let bindings: [String: Binding]
        let finishSetup: Bool
        var setupIntents: [String: UUID]? = nil
    }

    struct SetupIntent: Codable {
        let version: Int
        let operationID: UUID
        let account: AccountItem

        func matches(_ other: AccountItem) -> Bool {
            account.address == other.address && account.publicKeyData == other.publicKeyData &&
                account.cryptoType == other.cryptoType && account.networkType == other.networkType
        }
    }

    /// Only a successful owner-PIN check creates this address-scoped import grant.
    final class RetainedAuthorization {
        let addresses: Set<String>
        fileprivate init(addresses: Set<String>) { self.addresses = addresses }
    }

    private struct Rebinding: Codable {
        let version: Int
        let address: String
        let binding: Binding
        var consumedSetupIntent: UUID? = nil
    }

    /// Only minted after a submitted PIN matches this install's PIN. A stored
    /// PIN or biometric success never mints an authorization.
    final class Authorization {
        fileprivate let pinDigest: Data
        fileprivate let addresses: Set<String>
        fileprivate var consumed = false
        fileprivate init(pin: Data, addresses: Set<String>) {
            pinDigest = Data(SHA256.hash(data: pin))
            self.addresses = addresses
        }
    }

    private let keystore: KeystoreProtocol
    private let settings: SettingsManagerProtocol
    private let recoveryGate: WalletRecoveryCapabilityGate
    private let now: () -> Date
    private let uptime: () -> TimeInterval
    private let boot: () -> String

    init(keystore: KeystoreProtocol, settings: SettingsManagerProtocol,
         recoveryGate: WalletRecoveryCapabilityGate = .shared,
         now: @escaping () -> Date = Date.init,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         boot: @escaping () -> String = WalletOwnerPIN.bootIdentifier) {
        self.keystore = keystore
        self.settings = settings
        self.recoveryGate = recoveryGate
        self.now = now
        self.uptime = uptime
        self.boot = boot
    }

    static func bootIdentifier() -> String {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0,
              size > 1, size < 256 else { return processBootFallback }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &bytes, &size, nil, 0) == 0 else {
            return processBootFallback
        }
        return String(cString: bytes)
    }

    static func boundAddresses(keystore: KeystoreProtocol) throws -> Set<String> {
        try synchronized {
            Set(try keystore.allKeyIdentifiers().filter { $0.hasSuffix(bindingSuffix) }
                .map { String($0.dropLast(bindingSuffix.count)) })
        }
    }

    private static func synchronized<T>(_ action: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try action()
    }

    private func save<T: Codable>(_ value: T, tag: String) throws {
        let bytes = try JSONEncoder().encode(value)
        try keystore.saveKey(bytes, with: tag)
        guard try keystore.fetchKey(for: tag) == bytes else { throw Failure.persistenceFailed }
    }

    private func read<T: Decodable>(_ type: T.Type, tag: String) throws -> T? {
        guard let data = try keystore.loadIfKeyExists(tag) else { return nil }
        guard data.count < 1024 * 1024 else { throw Failure.invalidRecord }
        return try JSONDecoder().decode(type, from: data)
    }

    /// Run before any PIN read or biometric authorization. A durable, previously
    /// authorized transaction always completes before another auth can start.
    func recoverRotation() throws {
        try Self.synchronized {
            guard let transaction = try read(Rotation.self, tag: Self.rotationTag) else { return }
            guard transaction.version == 1, transaction.bindings.count <= 4096,
                  let pin = String(data: transaction.pin, encoding: .utf8), Self.validPIN(pin) else {
                throw Failure.invalidRecord
            }
            for (address, operationID) in transaction.setupIntents ?? [:] {
                if let intent = try read(SetupIntent.self, tag: Self.setupPrefix + address) {
                    guard intent.version == 1, intent.operationID == operationID,
                          intent.account.address == address else { throw Failure.invalidRecord }
                }
            }
            for (address, binding) in transaction.bindings.sorted(by: { $0.key < $1.key }) {
                guard try binding.matches(pin) else { throw Failure.invalidRecord }
                try save(binding, tag: address + Self.bindingSuffix)
            }
            try keystore.saveKey(transaction.pin, with: KeystoreTag.pincode.rawValue)
            guard try keystore.fetchKey(for: KeystoreTag.pincode.rawValue) == transaction.pin else {
                throw Failure.persistenceFailed
            }
            if transaction.finishSetup {
                // The durable intent, not a preferences hint, grants initial setup.
                // A retry may find an already consumed intent; it must never consume
                // a newer import operation for the same address.
                for (address, operationID) in transaction.setupIntents ?? [:] {
                    let tag = Self.setupPrefix + address
                    if let intent = try read(SetupIntent.self, tag: tag) {
                        guard intent.version == 1, intent.operationID == operationID,
                              intent.account.address == address else { throw Failure.invalidRecord }
                        try keystore.deleteKey(for: tag)
                        guard try !keystore.checkKey(for: tag) else { throw Failure.persistenceFailed }
                    }
                }
                WalletPendingPinSetup.finish(settings)
            }
            try keystore.deleteKey(for: Self.rotationTag)
        }
    }

    private static func validPIN(_ pin: String) -> Bool {
        [4, 6].contains(pin.utf8.count) && pin.utf8.allSatisfy { (48...57).contains($0) }
    }

    private func proven(_ accounts: [AccountItem]) throws -> [AccountItem] {
        try recoveryGate.requireAuthorizedLifecycleContinuation()
        return try accounts.filter { account in
            guard settings.bool(for: "wallet.watchOnly.\(account.address)") != true else { return false }
            do {
                guard var key = try LegacySoraSecretResolver.resolve(account: account, keystore: keystore,
                                                                    recoveryGate: recoveryGate) else { return false }
                defer { key.resetBytes(in: 0..<key.count) }
                return true
            } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) { return false }
        }
    }

    /// Manual normal PIN entry is the sole reconciliation path after 3.8.6
    /// changes the app PIN. Only rows actually present in this install qualify.
    func authenticateCurrent(_ pin: String, accounts: [AccountItem]) throws -> Authorization {
        try Self.synchronized {
            try recoverRotation()
            try WalletCredentialRepair.requireNoPendingRepair(keystore: keystore)
            guard try pendingSetupIntents(accounts: accounts).isEmpty, Self.validPIN(pin) else {
                throw Failure.authenticationRequired
            }
            try reserveCurrentPINAttempt()
            var entered = Data(pin.utf8)
            var stored = try keystore.fetchKey(for: KeystoreTag.pincode.rawValue)
            defer { entered.resetBytes(in: 0..<entered.count); stored.resetBytes(in: 0..<stored.count) }
            guard LegacySoraIdentityValidator.constantTimeEqual(entered, stored) else {
                throw WalletRetainedPinGate.Failure.incorrectPin(attemptsBeforeWait: 0)
            }
            try keystore.deleteKey(for: Self.appThrottleTag)
            // An unavailable wallet stays unbound, but does not prevent access
            // to the authenticated recovery UI. Reconciliation never guesses.
            let accounts = (try? proven(accounts)) ?? []
            var updates: [String: Binding] = [:]
            for account in accounts {
                if let existing = try read(Binding.self, tag: account.address + Self.bindingSuffix),
                   try existing.matches(pin) { continue }
                updates[account.address] = try Binding(pin: pin)
            }
            if !updates.isEmpty {
                try save(Rotation(version: 1, pin: entered, bindings: updates, finishSetup: false),
                         tag: Self.rotationTag)
                try recoverRotation()
            }
            return Authorization(pin: entered, addresses: Set(accounts.map(\.address)))
        }
    }

    private func reserveCurrentPINAttempt() throws {
        let currentUptime = uptime(), currentBoot = boot()
        var value = try read(Throttle.self, tag: Self.appThrottleTag) ?? Throttle(
            failures: 0, wait: 0, uptime: currentUptime, boot: currentBoot)
        guard value.failures >= 0, value.failures < Int.max, value.wait >= 0, value.wait <= 1800,
              value.uptime.isFinite, value.uptime >= 0 else { throw Failure.invalidRecord }
        if value.wait > 0 {
            if value.boot != currentBoot || currentUptime < value.uptime {
                value.boot = currentBoot; value.uptime = currentUptime
                try save(value, tag: Self.appThrottleTag)
            }
            let remaining = value.wait - (currentUptime - value.uptime)
            if remaining > 0 { throw WalletRetainedPinGate.Failure.locked(until: now().addingTimeInterval(remaining)) }
        }
        value.failures += 1
        value.wait = WalletRetainedPinGate.cooldown(afterFailures: value.failures)
        value.uptime = currentUptime; value.boot = currentBoot
        try save(value, tag: Self.appThrottleTag)
    }

    /// A setup claim is created only by a journaled insert with supplied-material
    /// proof or an owner-PIN grant, before it writes keys or commits a row. The
    /// operation ID binds consumption to that exact insert; unrelated claims left
    /// after uninstall cannot authorize a different account identity.
    func prepareInitialSetup(account: AccountItem, operationID: UUID) throws {
        try Self.synchronized {
            try recoverRotation()
            try save(SetupIntent(version: 1, operationID: operationID, account: account),
                     tag: Self.setupPrefix + account.address)
        }
    }

    private func pendingSetupIntents(accounts: [AccountItem]) throws -> [String: SetupIntent] {
        var result: [String: SetupIntent] = [:]
        for account in accounts {
            if let intent = try read(SetupIntent.self, tag: Self.setupPrefix + account.address) {
                guard intent.version == 1, intent.matches(account) else { throw Failure.invalidRecord }
                result[account.address] = intent
            }
        }
        return result
    }

    func requiresInitialSetup(accounts: [AccountItem]) throws -> Bool {
        try Self.synchronized { try !pendingSetupIntents(accounts: accounts).isEmpty }
    }

    /// Routing-only preflight. A missing app PIN does not prove ownership of
    /// retained signing rows. The writer repeats these checks under its lease.
    func validateInitialSetupEligibility(accounts: [AccountItem]) throws {
        try Self.synchronized {
            guard !accounts.isEmpty else { throw Failure.authenticationRequired }
            let intents = try pendingSetupIntents(accounts: accounts)
            if !intents.isEmpty {
                guard Set(intents.keys) == Set(accounts.map(\.address)),
                      try proven(accounts).count == accounts.count else {
                    throw Failure.authenticationRequired
                }
            } else if try !keystore.checkKey(for: KeystoreTag.pincode.rawValue) {
                guard try proven(accounts).isEmpty else { throw Failure.authenticationRequired }
            }
        }
    }

    /// Reconciliation and the actual row read share one lifecycle lease. A reset
    /// cannot substitute a different generation between proof and authentication.
    func authenticateCurrent(_ pin: String, currentAccounts: () throws -> [AccountItem]) throws -> Authorization {
        let lease = WalletLifecycleCoordinator.shared.acquire()
        defer { lease.release() }
        let accounts = try currentAccounts()
        try prepareAuthenticationWhileLeased(accounts: accounts)
        return try authenticateCurrent(pin, accounts: accounts)
    }

    private func prepareAuthenticationWhileLeased(accounts: [AccountItem]) throws {
        try Self.synchronized {
            try recoverRotation()
            try WalletCredentialRepair(keystore: keystore, settings: settings, recoveryGate: recoveryGate)
                .resumePending(accounts: accounts)
            if try keystore.allKeyIdentifiers().contains(where: { $0.hasPrefix(Self.rebindPrefix) }) {
                try recoveryGate.requireAuthorizedLifecycleContinuation()
                try settleRebindings(currentAddresses: Set(accounts.map(\.address)))
            }
            guard try pendingSetupIntents(accounts: accounts).isEmpty else {
                throw Failure.authenticationRequired
            }
        }
    }

    func prepareRetainedAuthentication(currentAccounts: () throws -> [AccountItem]) throws -> [AccountItem] {
        let lease = WalletLifecycleCoordinator.shared.acquire()
        defer { lease.release() }
        let accounts = try currentAccounts()
        try Self.synchronized {
            try recoverRotation()
            try WalletCredentialRepair(keystore: keystore, settings: settings, recoveryGate: recoveryGate)
                .resumePending(accounts: accounts)
            try settleRebindings(currentAddresses: Set(accounts.map(\.address)))
        }
        return accounts
    }

    func prepareAuthentication(currentAccounts: () throws -> [AccountItem]) throws {
        let lease = WalletLifecycleCoordinator.shared.acquire()
        defer { lease.release() }
        try prepareAuthenticationWhileLeased(accounts: currentAccounts())
    }

    func setInitialPIN(_ pin: String, accounts: [AccountItem]) throws {
        try Self.synchronized {
            try recoverRotation()
            try WalletCredentialRepair.requireNoPendingRepair(keystore: keystore)
            guard !accounts.isEmpty else { throw Failure.authenticationRequired }
            let intents = try pendingSetupIntents(accounts: accounts)
            if intents.isEmpty {
                if try keystore.checkKey(for: KeystoreTag.pincode.rawValue) {
                    // A completed save can be retried, but a stale defaults flag
                    // must never permit replacing the already established PIN.
                    _ = try authenticateCurrent(pin, accounts: accounts)
                    WalletPendingPinSetup.finish(settings)
                    return
                }
                // A new iPhone may restore read-only database rows without any
                // device-only keys. Its app PIN grants no retained-key ownership.
                guard try proven(accounts).isEmpty else { throw Failure.authenticationRequired }
                try writeRotation(pin, accounts: [], finishSetup: true)
                return
            }
            guard Set(intents.keys) == Set(accounts.map(\.address)) else {
                throw Failure.authenticationRequired
            }
            let verified = try proven(accounts)
            guard verified.count == accounts.count else { throw Failure.authenticationRequired }
            try writeRotation(pin, accounts: verified, finishSetup: true,
                              setupIntents: intents.mapValues(\.operationID))
        }
    }

    func rotate(to pin: String, authorization: Authorization, accounts: [AccountItem]) throws {
        try Self.synchronized {
            try recoverRotation()
            try WalletCredentialRepair.requireNoPendingRepair(keystore: keystore)
            var stored = try keystore.fetchKey(for: KeystoreTag.pincode.rawValue)
            defer { stored.resetBytes(in: 0..<stored.count) }
            let accounts = try proven(accounts)
            if authorization.consumed, stored == Data(pin.utf8),
               Set(accounts.map(\.address)).isSubset(of: authorization.addresses) {
                _ = try authenticateCurrent(pin, accounts: accounts)
                return
            }
            guard !authorization.consumed,
                  authorization.pinDigest == Data(SHA256.hash(data: stored)),
                  Set(accounts.map(\.address)).isSubset(of: authorization.addresses) else {
                throw Failure.authenticationRequired
            }
            authorization.consumed = true
            do { try writeRotation(pin, accounts: accounts, finishSetup: false) }
            catch {
                if (try? keystore.checkKey(for: Self.rotationTag)) == false { authorization.consumed = false }
                throw error
            }
        }
    }

    private func writeRotation(_ pin: String, accounts: [AccountItem], finishSetup: Bool,
                               setupIntents: [String: UUID] = [:]) throws {
        guard Self.validPIN(pin) else { throw Failure.invalidPIN }
        var bindings: [String: Binding] = [:]
        for account in accounts { bindings[account.address] = try Binding(pin: pin) }
        try save(Rotation(version: 1, pin: Data(pin.utf8), bindings: bindings, finishSetup: finishSetup, setupIntents: setupIntents),
                 tag: Self.rotationTag)
        try recoverRotation()
    }

    func authorizeRetained(_ pin: String, addresses: Set<String>) throws -> RetainedAuthorization {
        RetainedAuthorization(addresses: try verifyRetained(pin, addresses: addresses))
    }

    /// Returning a preserved database must not let this install's PIN claim
    /// another wallet. All retained material named by its rows needs an owner
    /// grant before those rows can become ordinary authenticated accounts.
    func requirePreservedOwners(accounts: [AccountItem], authorizations: [RetainedAuthorization]) throws {
        let granted = authorizations.reduce(into: Set<String>()) { $0.formUnion($1.addresses) }
        for account in accounts {
            let tags = [KeystoreTag.secretKeyTagForAddress(account.address),
                        KeystoreTag.entropyTagForAddress(account.address),
                        KeystoreTag.seedTagForAddress(account.address)]
            let hasScoped = try tags.contains { try keystore.checkKey(for: $0) }
            let hasLegacy = try keystore.checkKey(for: KeystoreTag.legacyEntropy.rawValue)
            guard !(hasScoped || hasLegacy) || granted.contains(account.address) else {
                throw Failure.authenticationRequired
            }
        }
    }

    /// Explicitly chosen protection for a returned file set. The caller holds
    /// the lifecycle lease and has proved the live wallet is empty. Rotation
    /// remains durable even if the process stops before the first file moves.
    func setPINForPreservedRestore(_ pin: String, accounts: [AccountItem],
                                   authorizations: [RetainedAuthorization]) throws {
        try Self.synchronized {
            try recoverRotation()
            try WalletCredentialRepair.requireNoPendingRepair(keystore: keystore)
            try requirePreservedOwners(accounts: accounts, authorizations: authorizations)
            guard Self.validPIN(pin) else { throw Failure.invalidPIN }
            let verified = try proven(accounts)
            if try keystore.checkKey(for: KeystoreTag.pincode.rawValue),
               try keystore.fetchKey(for: KeystoreTag.pincode.rawValue) == Data(pin.utf8),
               try verified.allSatisfy({ account in
                   try read(Binding.self, tag: account.address + Self.bindingSuffix)?.matches(pin) == true
               }) { return }
            try writeRotation(pin, accounts: verified, finishSetup: true)
        }
    }

    /// Returns only the wallets this PIN owns. A success never resets another
    /// wallet's counter. Reserve each attempt durably before computing its KDF.
    func verifyRetained(_ pin: String, addresses: Set<String>) throws -> Set<String> {
        try Self.synchronized {
            try recoverRotation()
            guard try !keystore.allKeyIdentifiers().contains(where: { $0.hasPrefix(Self.rebindPrefix) }) else {
                throw Failure.authenticationRequired
            }
            let candidates = try addresses.intersection(Self.boundAddresses(keystore: keystore)).sorted()
            guard !candidates.isEmpty else { throw WalletRetainedPinGate.Failure.noRetainedPin }
            var matched = Set<String>()
            var waits: [Date] = []
            var attemptsRemaining = WalletRetainedPinGate.failuresBeforeWait
            for address in candidates {
                let tag = address + Self.throttleSuffix
                guard let binding = try read(Binding.self, tag: address + Self.bindingSuffix) else { continue }
                let currentUptime = uptime()
                let currentBoot = boot()
                var throttle = try read(Throttle.self, tag: tag) ?? Throttle(
                    failures: 0, wait: 0, uptime: currentUptime, boot: currentBoot)
                guard throttle.failures >= 0, throttle.failures < Int.max,
                      throttle.wait >= 0, throttle.wait <= 1800,
                      throttle.uptime.isFinite, throttle.uptime >= 0 else { throw Failure.invalidRecord }
                if throttle.wait > 0 {
                    // A reboot (or unavailable boot ID across process restarts)
                    // restarts the full remaining step; wall time grants no guesses.
                    if throttle.boot != currentBoot || currentUptime < throttle.uptime {
                        throttle.boot = currentBoot
                        throttle.uptime = currentUptime
                        try save(throttle, tag: tag)
                    }
                    let remaining = throttle.wait - (currentUptime - throttle.uptime)
                    if remaining > 0 { waits.append(now().addingTimeInterval(remaining)); continue }
                }
                throttle.failures += 1
                throttle.wait = WalletRetainedPinGate.cooldown(afterFailures: throttle.failures)
                throttle.uptime = currentUptime
                throttle.boot = currentBoot
                try save(throttle, tag: tag)
                if !pin.isEmpty, try binding.matches(pin) {
                    matched.insert(address)
                    try keystore.deleteKey(for: tag)
                } else if throttle.wait > 0 {
                    waits.append(now().addingTimeInterval(throttle.wait))
                } else {
                    attemptsRemaining = min(attemptsRemaining,
                                            WalletRetainedPinGate.failuresBeforeWait - throttle.failures)
                }
            }
            if !matched.isEmpty { return matched }
            if let until = waits.min() { throw WalletRetainedPinGate.Failure.locked(until: until) }
            throw WalletRetainedPinGate.Failure.incorrectPin(attemptsBeforeWait: attemptsRemaining)
        }
    }

    /// Call only after proof of supplied import material, or after the owner PIN
    /// matched this address and the user explicitly accepted the new protection.
    /// The binding is published only if the row commits; an interrupted insert
    /// is settled from the account database before another authentication.
    func prepareRebinding(address: String, to pin: String, consumeSetupIntent: Bool = false) throws {
        try Self.synchronized {
            try recoverRotation()
            guard Self.validPIN(pin) else { throw Failure.invalidPIN }
            let setup = try read(SetupIntent.self, tag: Self.setupPrefix + address)
            if consumeSetupIntent || setup == nil {
                guard try keystore.fetchKey(for: KeystoreTag.pincode.rawValue) == Data(pin.utf8) else {
                    throw Failure.authenticationRequired
                }
            }
            let tag = Self.rebindPrefix + address
            guard try !keystore.checkKey(for: tag) else { throw Failure.persistenceFailed }
            try save(Rebinding(version: 1, address: address, binding: Binding(pin: pin),
                               consumedSetupIntent: consumeSetupIntent ? setup?.operationID : nil), tag: tag)
        }
    }

    func settleRebindings(currentAddresses: Set<String>) throws {
        try Self.synchronized {
            try recoverRotation()
            for tag in try keystore.allKeyIdentifiers().filter({ $0.hasPrefix(Self.rebindPrefix) }).sorted() {
                guard let pending = try read(Rebinding.self, tag: tag), pending.version == 1,
                      tag == Self.rebindPrefix + pending.address,
                      pending.binding.version == 1, pending.binding.salt.count == 16,
                      pending.binding.verifier.count == 32 else { throw Failure.invalidRecord }
                if currentAddresses.contains(pending.address) {
                    let setupTag = Self.setupPrefix + pending.address
                    if let expected = pending.consumedSetupIntent,
                       let setup = try read(SetupIntent.self, tag: setupTag) {
                        guard setup.version == 1, setup.operationID == expected,
                              setup.account.address == pending.address else { throw Failure.invalidRecord }
                    }
                    try save(pending.binding, tag: pending.address + Self.bindingSuffix)
                    if pending.consumedSetupIntent != nil {
                        try keystore.deleteKeyIfExists(for: setupTag)
                        guard try !keystore.checkKey(for: setupTag) else { throw Failure.persistenceFailed }
                    }
                }
                try keystore.deleteKey(for: tag)
            }
        }
    }
}
