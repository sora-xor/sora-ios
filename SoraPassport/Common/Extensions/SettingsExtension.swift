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

import Foundation
import SoraKeystore
import IrohaCrypto

enum SettingsKey: String {
    case decentralizedId
    case publicKeyId
    case biometryEnabled
    case disclaimerHidden
    case invitationCode
    case isCheckedInvitation
    case selectedLocalization
    case lastStreamEventId
    case streamToken
    case selectedAccount
    case hasMigrated
    case migratedAccountsV1
    case externalGenesis
    case externalExistentialDeposit
    case externalPrefix
    case assetList
    case inputBlockDate
    case failInputPinCount
    case lastSuccessfulUrl
    case walletMigrationRecoveryRequired
    case walletMigrationRecoveryReason
    case walletMigrationRecoveryGeneration
    case walletMigrationRecoveryReasonGeneration
    case walletMigrationRecoveryRecord
    case walletStartupDiagnostic
    case walletNetworkStoreVersion
    case tairaEnabled
    case tairaPreferenceWasSet
    case tairaExplicitPreference
    case tairaRemoteDefault
    case nexusEnabled
    case nexusSendsEnabled
    case polkamarktEnabled
    case polkamarktMutationsEnabled
}

/// A generation changes even when another integrity check repeats the same
/// Boolean/reason. Recovery can then compare-and-clear only the marker it proved.
struct WalletMigrationRecoveryMarker: Equatable, Codable {
    private static let lock = NSRecursiveLock()
    let required: Bool
    let reason: String?
    let generation: String?
    let reasonGeneration: String?

    static func synchronized<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    static func capture(_ settings: SettingsManagerProtocol) -> Self {
        synchronized {
            let recordKey = SettingsKey.walletMigrationRecoveryRecord.rawValue
            if let stored = settings.anyValue(for: recordKey) {
                guard let encoded = stored as? String,
                      encoded.utf8.count <= 64 * 1_024,
                      let marker = try? JSONDecoder().decode(Self.self, from: Data(encoded.utf8)),
                      let generation = marker.generation,
                      UUID(uuidString: generation)?.uuidString == generation,
                      marker.reasonGeneration == generation
                else {
                    // Never fall back to potentially clear legacy fields when a new record is
                    // present but unreadable. It remains a distinct, non-retryable integrity stop.
                    return Self(required: true, reason: "The persisted wallet recovery marker is invalid.",
                                generation: nil, reasonGeneration: nil)
                }
                return marker
            }
            return Self(
                required: settings.bool(for: SettingsKey.walletMigrationRecoveryRequired.rawValue) ?? false,
                reason: settings.string(for: SettingsKey.walletMigrationRecoveryReason.rawValue),
                generation: settings.string(for: SettingsKey.walletMigrationRecoveryGeneration.rawValue),
                reasonGeneration: settings.string(for: SettingsKey.walletMigrationRecoveryReasonGeneration.rawValue)
            )
        }
    }

    /// SettingsManager synchronizes after every set. Publish the entire new tuple in one value
    /// before updating compatibility mirrors, so termination at any mirror write retains either
    /// the previous authoritative record or the complete new one, never a partial tuple.
    static func publish(_ marker: Self, to settings: SettingsManagerProtocol) {
        synchronized {
            guard let data = try? JSONEncoder().encode(marker), data.count <= 64 * 1_024 else {
                settings.set(value: "{}", for: SettingsKey.walletMigrationRecoveryRecord.rawValue)
                return
            }
            settings.set(value: String(decoding: data, as: UTF8.self),
                         for: SettingsKey.walletMigrationRecoveryRecord.rawValue)
            guard capture(settings) == marker else { return }
            settings.set(value: marker.required, for: SettingsKey.walletMigrationRecoveryRequired.rawValue)
            if let reason = marker.reason {
                settings.set(value: reason, for: SettingsKey.walletMigrationRecoveryReason.rawValue)
            } else {
                settings.removeValue(for: SettingsKey.walletMigrationRecoveryReason.rawValue)
            }
            if let generation = marker.generation {
                settings.set(value: generation, for: SettingsKey.walletMigrationRecoveryGeneration.rawValue)
                settings.set(value: generation, for: SettingsKey.walletMigrationRecoveryReasonGeneration.rawValue)
            }
        }
    }

    var isDatabaseInterruption: Bool {
        // A legacy marker has neither generation. For new writes, the reason
        // must belong to the same generation as the flag: a reader between
        // the two setters must not reuse the previous failure's reason.
        required && generation == reasonGeneration && [
            UserStorageMigrationError.privacySafeRecoveryDescription(
                for: UserStorageMigrationError.interruptedMigration
            ),
            "An unfinished or unverifiable wallet database migration blocks signing and wallet changes."
        ].contains(reason ?? "")
    }

    /// Prefix and suffix of `UserStorageMigrationError.privacySafeRecoveryDescription`.
    static let startupFailureReasonPrefix = "Wallet storage could not be verified safely ("
    static let startupFailureReasonSuffix = "). Existing wallet data and recovery copies were preserved."

    /// Every fixed startup code except `interrupted_migration`, which has its
    /// own journal resolver. A retry only re-runs read-only verification; only a
    /// complete proof clears the marker, by compare-and-set.
    static let retryableStartupFailureCodes: Set<String> = [
        "unexpected_failure",
        "missing_wallet_secret",
        "empty_wallet_secret",
        "backup_verification_failed",
        "account_inventory_mismatch",
        "selected_account_mismatch",
        "missing_wallet_store",
        "unknown_store_version",
        "unavailable_model",
        "incomplete_migration_path",
        "insufficient_storage",
    ]

    /// Gate latches caused by a journal that could not be read or a terminal
    /// journal write that could not be read back. Both are usually transient
    /// (locked device, I/O). Startup verification re-proves every journal.
    static let retryableJournalReadReasons: Set<String> = [
        "The wallet account commit journal could not be verified. Existing wallet material was preserved.",
        "A terminal wallet account commit could not be verified. Existing wallet material was preserved.",
    ]

    /// The fixed code inside a privacy-safe startup reason, if the reason has
    /// exactly that format.
    var startupFailureCode: String? {
        guard let reason,
              reason.hasPrefix(Self.startupFailureReasonPrefix),
              reason.hasSuffix(Self.startupFailureReasonSuffix),
              reason.count > Self.startupFailureReasonPrefix.count + Self.startupFailureReasonSuffix.count
        else { return nil }
        let code = String(reason.dropFirst(Self.startupFailureReasonPrefix.count)
            .dropLast(Self.startupFailureReasonSuffix.count))
        guard !code.isEmpty, code.allSatisfy({ $0 == "_" || ("a"..."z").contains($0) }) else { return nil }
        return code
    }

    /// Markers that startup may retry. Transient Keychain, disk and journal
    /// failures must never become a permanent lockout.
    var isRetryableStartupFailure: Bool {
        guard required, generation == reasonGeneration, !isDatabaseInterruption,
              !isLegacyAccountCommitInterruption else { return false }
        if let code = startupFailureCode {
            return Self.retryableStartupFailureCodes.contains(code)
        }
        return Self.retryableJournalReadReasons.contains(reason ?? "")
    }

    /// Kept for existing callers: a retryable startup failure. The marker is
    /// only cleared after startup independently proves the installed database,
    /// selected account, signing material and network identities.
    var isStartupVerificationFailure: Bool {
        isRetryableStartupFailure
    }

    func requireUnchangedForStartupVerification(_ settings: SettingsManagerProtocol) throws {
        guard isRetryableStartupFailure, Self.capture(settings) == self else {
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }
    }

    func clearAfterVerifiedStartup(_ settings: SettingsManagerProtocol) throws {
        try Self.synchronized {
            try requireUnchangedForStartupVerification(settings)
            let generation = UUID().uuidString
            let cleared = Self(required: false, reason: nil, generation: generation,
                               reasonGeneration: generation)
            Self.publish(cleared, to: settings)
            guard Self.capture(settings) == cleared else {
                throw WalletNetworkMigrationError.walletRecoveryRequired
            }
        }
    }

    static let accountCommitInterruptionReason =
        "An unfinished wallet account commit blocks signing and wallet changes. Existing wallet material was preserved."

    var isLegacyAccountCommitInterruption: Bool {
        isDatabaseInterruption || (required && generation == reasonGeneration &&
            reason == Self.accountCommitInterruptionReason)
    }

    func requireUnchangedForLegacyAccountRecovery(_ settings: SettingsManagerProtocol) throws {
        guard (!required || isLegacyAccountCommitInterruption), Self.capture(settings) == self else {
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }
    }

    func clearAfterVerifiedLegacyAccountActivation(_ settings: SettingsManagerProtocol) throws {
        try Self.synchronized {
            try requireUnchangedForLegacyAccountRecovery(settings)
            let generation = UUID().uuidString
            let cleared = Self(required: false, reason: nil, generation: generation, reasonGeneration: generation)
            Self.publish(cleared, to: settings)
            guard Self.capture(settings) == cleared else {
                throw WalletNetworkMigrationError.walletRecoveryRequired
            }
        }
    }

    func requireUnchanged(_ settings: SettingsManagerProtocol) throws {
        guard isDatabaseInterruption, Self.capture(settings) == self else {
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }
    }

    func clearAfterVerifiedActivation(_ settings: SettingsManagerProtocol) throws {
        try Self.synchronized {
            try requireUnchanged(settings)
            let generation = UUID().uuidString
            let cleared = Self(required: false, reason: nil, generation: generation, reasonGeneration: generation)
            Self.publish(cleared, to: settings)
            guard Self.capture(settings) == cleared else {
                throw WalletNetworkMigrationError.walletRecoveryRequired
            }
        }
    }
}

private enum TairaExplicitPreferenceState {
    case absent
    case enabled
    case disabled
    case malformed
}

private enum TairaStoredBooleanState {
    case absent
    case value(Bool)
    case malformed
}

extension SettingsManagerProtocol {
    private var atomicTairaExplicitPreference: TairaExplicitPreferenceState {
        guard let stored = anyValue(
            for: SettingsKey.tairaExplicitPreference.rawValue
        ) else {
            return .absent
        }
        guard let raw = stored as? String else {
            return .malformed
        }
        switch raw {
        case "enabled":
            return .enabled
        case "disabled":
            return .disabled
        default:
            // A present but malformed explicit choice is never permission for a
            // remote default to expose a test network.
            return .malformed
        }
    }

    private func tairaStoredBooleanState(
        for key: SettingsKey
    ) -> TairaStoredBooleanState {
        guard let stored = anyValue(for: key.rawValue) else {
            return .absent
        }
        guard let number = stored as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            return .malformed
        }
        return .value(number.boolValue)
    }

    var hasSelectedAccount: Bool {
        SelectedWalletSettings.shared.hasValue
    }

    var lastSuccessfulUrl: URL? {
        get {
            value(of: URL.self, for: SettingsKey.lastSuccessfulUrl.rawValue)
        }
        set {
            set(value: newValue, for: SettingsKey.lastSuccessfulUrl.rawValue)
        }
    }

    var externalGenesis: String? {
        get {
            if let value = string(for: SettingsKey.externalGenesis.rawValue) {
                return value
            }
            return nil
        }

        set {
            set(value: newValue, for: SettingsKey.externalGenesis.rawValue)
        }
    }

    var externalExistentialDeposit: UInt? {
        get {
            if let value = integer(for: SettingsKey.externalExistentialDeposit.rawValue) {
                return UInt(value)
            }
            return nil
        }

        set {
            set(value: newValue, for: SettingsKey.externalExistentialDeposit.rawValue)
        }
    }

    var externalAddressPrefix: UInt? {
        get {
            if let value = integer(for: SettingsKey.externalPrefix.rawValue), value != 0 {
                return UInt(value)
            }
            return 69
        }

        set {
            set(value: newValue, for: SettingsKey.externalPrefix.rawValue)
        }
    }

    var hasMigrated: Bool {
        get {
            if let value = bool(for: SettingsKey.hasMigrated.rawValue) {
                return value
            }
            return false
        }
        set {
            set(value: newValue, for: SettingsKey.hasMigrated.rawValue)
        }
    }

    var isRegistered: Bool {
        return decentralizedId != nil
    }

    var decentralizedId: String? {
        get {
            return string(for: SettingsKey.decentralizedId.rawValue)
        }

        set {
            if let exisingValue = newValue {
                set(value: exisingValue, for: SettingsKey.decentralizedId.rawValue)
            } else {
                removeValue(for: SettingsKey.decentralizedId.rawValue)
            }
        }
    }

    var publicKeyId: String? {
        get {
            string(for: SettingsKey.publicKeyId.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.publicKeyId.rawValue)
            } else {
                removeValue(for: SettingsKey.publicKeyId.rawValue)
            }
        }
    }

    var biometryEnabled: Bool? {
        get {
            bool(for: SettingsKey.biometryEnabled.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.biometryEnabled.rawValue)
            } else {
                removeValue(for: SettingsKey.biometryEnabled.rawValue)
            }
        }
    }

    var disclaimerHidden: Bool? {
        get {
            bool(for: SettingsKey.disclaimerHidden.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.disclaimerHidden.rawValue)
            } else {
                removeValue(for: SettingsKey.disclaimerHidden.rawValue)
            }
        }
    }

    var invitationCode: String? {
        get {
            string(for: SettingsKey.invitationCode.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.invitationCode.rawValue)
            } else {
                removeValue(for: SettingsKey.invitationCode.rawValue)
            }
        }
    }

    var isCheckedInvitation: Bool? {
        get {
            bool(for: SettingsKey.isCheckedInvitation.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.isCheckedInvitation.rawValue)
            } else {
                removeValue(for: SettingsKey.isCheckedInvitation.rawValue)
            }
        }
    }

    var selectedLocalization: String? {
        get {
            string(for: SettingsKey.selectedLocalization.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.selectedLocalization.rawValue)
            } else {
                removeValue(for: SettingsKey.selectedLocalization.rawValue)
            }
        }
    }

    var lastStreamEventId: String? {
        get {
            string(for: SettingsKey.lastStreamEventId.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.lastStreamEventId.rawValue)
            } else {
                removeValue(for: SettingsKey.lastStreamEventId.rawValue)
            }
        }
    }

    var streamToken: String? {
        get {
            string(for: SettingsKey.streamToken.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.streamToken.rawValue)
            } else {
                removeValue(for: SettingsKey.streamToken.rawValue)
            }
        }
    }

    var userName: String? {
        get {
            SelectedWalletSettings.shared.currentAccount?.username
        }
    }

    var inputBlockTimeInterval: Int? {
        get {
            integer(for: SettingsKey.inputBlockDate.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.inputBlockDate.rawValue)
            } else {
                removeValue(for: SettingsKey.inputBlockDate.rawValue)
            }
        }
    }

    var failInputPinCount: Int? {
        get {
            integer(for: SettingsKey.failInputPinCount.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.failInputPinCount.rawValue)
            } else {
                removeValue(for: SettingsKey.failInputPinCount.rawValue)
            }
        }
    }

    /// Ordinary migration success cannot clear recovery. The narrowly bound
    /// interrupted-database recovery compares the full marker after activation.
    func setWalletMigrationRecovery(reason: String, preservingExistingReason: Bool = false) {
        WalletMigrationRecoveryMarker.synchronized {
            let current = WalletMigrationRecoveryMarker.capture(self)
            let retainedReason = preservingExistingReason && current.required &&
                current.reason?.isEmpty == false ? current.reason! : reason
            let generation = UUID().uuidString
            WalletMigrationRecoveryMarker.publish(.init(required: true, reason: retainedReason,
                generation: generation, reasonGeneration: generation), to: self)
        }
    }

    var walletMigrationRecoveryRequired: Bool {
        get { WalletMigrationRecoveryMarker.capture(self).required }
        set {
            WalletMigrationRecoveryMarker.synchronized {
                let current = WalletMigrationRecoveryMarker.capture(self)
                let generation = UUID().uuidString
                // A Boolean-only latch cannot authorize recovery using an older failure's reason.
                WalletMigrationRecoveryMarker.publish(.init(required: newValue,
                    reason: newValue ? nil : current.reason,
                    generation: generation, reasonGeneration: generation), to: self)
            }
        }
    }

    var walletMigrationRecoveryReason: String? {
        get { WalletMigrationRecoveryMarker.capture(self).reason }
        set {
            WalletMigrationRecoveryMarker.synchronized {
                let current = WalletMigrationRecoveryMarker.capture(self)
                let generation = UUID().uuidString
                WalletMigrationRecoveryMarker.publish(.init(required: current.required,
                    reason: newValue, generation: generation, reasonGeneration: generation), to: self)
            }
        }
    }

    var walletNetworkStoreVersion: Int {
        get { integer(for: SettingsKey.walletNetworkStoreVersion.rawValue) ?? 0 }
        set { set(value: newValue, for: SettingsKey.walletNetworkStoreVersion.rawValue) }
    }

    /// Without a choice or a PI remote default, Taira follows
    /// `ProductSurfacePolicy.optionalSurfacesDefaultOn` (on for the Nexus
    /// line's testers, off on the 3.9.x App Store line). Once the user changes
    /// this value, future remote defaults must not override their choice.
    var isTairaEnabled: Bool {
        get {
            // An App Store build does not ship Taira. Neither a remote
            // default nor a choice made in a tester build turns it on there;
            // the stored choice is kept for a build that does ship it.
            guard ProductSurfacePolicy.showsTairaSettings else {
                return false
            }
            switch atomicTairaExplicitPreference {
            case .enabled:
                return true
            case .disabled, .malformed:
                return false
            case .absent:
                break
            }

            let legacyMarker = tairaStoredBooleanState(for: .tairaPreferenceWasSet)
            let legacyValue = tairaStoredBooleanState(for: .tairaEnabled)
            switch (legacyMarker, legacyValue) {
            case let (.value(true), .value(enabled)):
                return enabled
            case (.absent, .absent):
                switch tairaStoredBooleanState(for: .tairaRemoteDefault) {
                case let .value(remoteDefault):
                    return remoteDefault
                case .absent:
                    return ProductSurfacePolicy.optionalSurfacesDefaultOn
                case .malformed:
                    return false
                }
            default:
                // The retired writer stored value then marker. Any partial pair,
                // explicit false marker, or malformed member is interruption
                // evidence, never permission to apply a remote default.
                return false
            }
        }
        set {
            // One authoritative tri-state key makes the explicit choice durable
            // in a single logical write. Retain the legacy pair for one further
            // dual-read release; it is no longer authoritative once this key exists.
            set(
                value: newValue ? "enabled" : "disabled",
                for: SettingsKey.tairaExplicitPreference.rawValue
            )
            set(value: newValue, for: SettingsKey.tairaEnabled.rawValue)
            set(value: true, for: SettingsKey.tairaPreferenceWasSet.rawValue)
        }
    }

    /// Follows PI's `nexusAvailable` once stored, otherwise
    /// `ProductSurfacePolicy.optionalSurfacesDefaultOn`, and is always off in
    /// a build that does not ship the Nexus portfolio, whatever an earlier
    /// build stored.
    var nexusEnabled: Bool {
        get {
            ProductSurfacePolicy.showsNexusPortfolio &&
                (bool(for: SettingsKey.nexusEnabled.rawValue)
                    ?? ProductSurfacePolicy.optionalSurfacesDefaultOn)
        }
        set { set(value: newValue, for: SettingsKey.nexusEnabled.rawValue) }
    }

    var nexusSendsEnabled: Bool {
        // Mutation capabilities fail closed until the reviewed native signer
        // and live-network qualification gates have passed. A qualified
        // release or emergency configuration may persist an explicit value.
        get {
            ProductionRemoteCapabilitySession.shared.permitsMutation(
                localQualification: ProductionMutationQualification.nexusSends,
                capability: .nexusSends
            )
        }
        set { set(value: newValue, for: SettingsKey.nexusSendsEnabled.rawValue) }
    }

    /// Taira shipping capability is independent of production rollout qualification.
    /// The network-specific coordinator still checks the user's testnet preference,
    /// canonical endpoint, local signing implementation, and confirmation adapter.
    func nexusSendsEnabled(for networkId: NetworkId) -> Bool {
        if networkId == .taira { return nexusEnabled && isTairaEnabled }
        return nexusSendsEnabled
    }

    /// Follows PI's `polkamarktVisible` once stored, otherwise
    /// `ProductSurfacePolicy.optionalSurfacesDefaultOn`, and is always off in
    /// a build that does not ship Polkamarkt, whatever an earlier build
    /// stored.
    var polkamarktEnabled: Bool {
        get {
            ProductSurfacePolicy.showsPolkamarkt &&
                (bool(for: SettingsKey.polkamarktEnabled.rawValue)
                    ?? ProductSurfacePolicy.optionalSurfacesDefaultOn)
        }
        set { set(value: newValue, for: SettingsKey.polkamarktEnabled.rawValue) }
    }

    var polkamarktMutationsEnabled: Bool {
        // Discovery may remain visible while transaction construction is
        // independently gated. Missing configuration is never permission to
        // submit a production mutation.
        get {
            ProductionRemoteCapabilitySession.shared.permitsMutation(
                localQualification:
                    ProductionMutationQualification.polkamarktMutations,
                capability: .polkamarktMutations
            )
        }
        set { set(value: newValue, for: SettingsKey.polkamarktMutationsEnabled.rawValue) }
    }

    /// Stores what PI's `mobileConfig` says about optional features.
    ///
    /// In an App Store build the flags for Taira, Polkamarkt and Nexus are
    /// first masked to off (`ProductSurfacePolicy.admitted`), so nothing PI
    /// sends can store them as on or publish their mutation authority.
    @discardableResult
    func applyPIMobileConfig(
        _ remoteConfig: PIMobileConfig,
        refreshToken: ProductionRemoteCapabilitySession.RefreshToken,
        isAppStoreBuild: Bool = ProductSurfacePolicy.isAppStoreBuild
    ) -> Bool {
        let config = ProductSurfacePolicy.admitted(
            remoteConfig,
            isAppStoreBuild: isAppStoreBuild
        )
        let capabilitySession = ProductionRemoteCapabilitySession.shared
        return capabilitySession.publishFreshConfig(
            refreshToken,
            nexusSends: config.nexusAvailable && config.nexusSendsAvailable,
            polkamarktMutations:
                config.polkamarktVisible && config.polkamarktMutationsAvailable
        ) {
            nexusEnabled = config.nexusAvailable
            nexusSendsEnabled =
                config.nexusAvailable && config.nexusSendsAvailable
            polkamarktEnabled = config.polkamarktVisible
            polkamarktMutationsEnabled =
                config.polkamarktVisible && config.polkamarktMutationsAvailable
            // This is deliberately not `isTairaEnabled = ...`: that setter marks a
            // user choice. Remote configuration changes only the default observed
            // by users who have never made an explicit selection.
            set(
                value: config.tairaDefaultVisible,
                for: SettingsKey.tairaRemoteDefault.rawValue
            )
            // Session publication occurs only after every persisted value is
            // complete; concurrent readers cannot observe a partial config.
        }
    }
}

/// Live PI mutation authority is deliberately process-local. Persisted flags
/// support diagnostics and cached read-only visibility, but a prior process's
/// response can never enable a send or trade before this process receives and
/// applies a fresh qualified `mobileConfig` response.
final class ProductionRemoteCapabilitySession: @unchecked Sendable {
    enum MutationCapability {
        case nexusSends
        case polkamarktMutations
    }

    struct RefreshToken: Sendable {
        fileprivate let generation: UInt64
    }

    private struct Snapshot {
        let nexusSends: Bool
        let polkamarktMutations: Bool
    }

    static let shared = ProductionRemoteCapabilitySession()

    private let publicationLock = NSLock()
    private let stateLock = NSLock()
    private var generation: UInt64 = 0
    private var snapshot: Snapshot?

    private init() {}

    func beginLiveRefresh() -> RefreshToken {
        publicationLock.lock()
        stateLock.lock()
        generation &+= 1
        snapshot = nil
        let token = RefreshToken(generation: generation)
        stateLock.unlock()
        publicationLock.unlock()
        return token
    }

    func invalidate() {
        _ = beginLiveRefresh()
    }

    func invalidate(_ token: RefreshToken) {
        publicationLock.lock()
        stateLock.lock()
        if generation == token.generation {
            generation &+= 1
            snapshot = nil
        }
        stateLock.unlock()
        publicationLock.unlock()
    }

    @discardableResult
    func publishFreshConfig(
        _ token: RefreshToken,
        nexusSends: Bool,
        polkamarktMutations: Bool,
        publication: () -> Void
    ) -> Bool {
        publicationLock.lock()
        stateLock.lock()
        guard generation == token.generation else {
            stateLock.unlock()
            publicationLock.unlock()
            return false
        }
        snapshot = nil
        stateLock.unlock()
        publication()
        stateLock.lock()
        snapshot = Snapshot(
            nexusSends: nexusSends,
            polkamarktMutations: polkamarktMutations
        )
        stateLock.unlock()
        publicationLock.unlock()
        return true
    }

    func permitsMutation(
        localQualification: Bool,
        capability: MutationCapability
    ) -> Bool {
        guard localQualification else {
            return false
        }
        stateLock.lock()
        let permitted: Bool
        switch capability {
        case .nexusSends:
            permitted = snapshot?.nexusSends ?? false
        case .polkamarktMutations:
            permitted = snapshot?.polkamarktMutations ?? false
        }
        stateLock.unlock()
        return permitted
    }
}

/// Which optional product surfaces a build may show at all. On the App Store
/// line (3.9.x) Release (`F_RELEASE`) builds hide the Taira testnet switch,
/// Polkamarkt prediction markets and the Nexus network portfolio, and do not
/// accept IrohaConnect links, whatever PI or stored settings say. Other
/// builds keep them for testers; PI and stored settings still decide there.
///
/// It applies at UI entry points and to the feature flags themselves: a build
/// that hides the surfaces masks PI's flags before storing them (`admitted`)
/// and reads the stored ones as off. It must not change runtime, key,
/// migration or network-admission policy (`NexusNetworkAdmissionPolicy`):
/// hiding a surface never touches Nexus or Taira journals or keys.
enum ProductSurfacePolicy {
    /// This is the SORA Nexus (`modernize`) line. Its Release builds go to
    /// Nexus testers through TestFlight and ship Taira, Polkamarkt, the Nexus
    /// portfolio and IrohaConnect in every configuration, as this line did
    /// before the 3.9.x App Store line was merged into it. Set this to false
    /// to get the App Store line's behaviour (and remove the IrohaConnect URL
    /// type from Info.plist, which `register-irohaconnect-url-schemes.sh`
    /// then adds back for non-Release builds only).
    static let shipsOptionalSurfacesInRelease = true

    #if F_RELEASE
    static let isAppStoreBuild = !shipsOptionalSurfacesInRelease
    #else
    static let isAppStoreBuild = false
    #endif
    static let showsTairaSettings = !isAppStoreBuild
    static let showsPolkamarkt = !isAppStoreBuild
    static let showsNexusPortfolio = !isAppStoreBuild
    static let acceptsIrohaConnect = !isAppStoreBuild

    /// The portfolio view (`portfolioView`): on in every non-production configuration
    /// (Debug, Dev, Test, Staging), off in Release, the TestFlight and App Store builds of
    /// both lines, whatever `shipsOptionalSurfacesInRelease` says. This one constant flips it.
    #if F_RELEASE
    static let showsPortfolioView = false
    #else
    static let showsPortfolioView = true
    #endif

    /// What an install shows before it has a stored choice or a PI value.
    /// The Nexus line keeps its tester default (Taira, Nexus and Polkamarkt
    /// on); the App Store line starts with them off until PI publishes them.
    static let optionalSurfacesDefaultOn = shipsOptionalSurfacesInRelease

    /// PI's `mobileConfig` as this build may act on it. The production PI
    /// can publish `nexusAvailable`, `polkamarktVisible` and
    /// `tairaDefaultVisible` as true; an App Store build ships none of those
    /// surfaces, so there every optional flag is off. Node, explorer and
    /// type-registry fields are not feature flags and pass through.
    static func admitted(
        _ config: PIMobileConfig,
        isAppStoreBuild: Bool = Self.isAppStoreBuild
    ) -> PIMobileConfig {
        guard isAppStoreBuild else {
            return config
        }
        return PIMobileConfig(
            blockExplorerUrl: config.blockExplorerUrl,
            substrateTypesUrl: config.substrateTypesUrl,
            nodes: config.nodes,
            nexusAvailable: false,
            nexusSendsAvailable: false,
            polkamarktVisible: false,
            polkamarktMutationsAvailable: false,
            tairaDefaultVisible: false
        )
    }
}

enum ProductionMutationQualification {
    // Promote only after the retained migration matrix, pinned native signer,
    // runtime parity fixtures and funded network canaries are qualified. A
    // remote flag is a kill switch, never authority to enable an unqualified
    // binary.
    static let nexusSends = false
    static let polkamarktMutations = false
}
