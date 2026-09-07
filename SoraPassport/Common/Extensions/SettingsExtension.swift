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

    /// Taira is on by default for the tester release. Once the user changes
    /// this value, future remote defaults must not override their choice.
    var isTairaEnabled: Bool {
        get {
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
                    return true
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

    var nexusEnabled: Bool {
        get { bool(for: SettingsKey.nexusEnabled.rawValue) ?? true }
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

    var polkamarktEnabled: Bool {
        get { bool(for: SettingsKey.polkamarktEnabled.rawValue) ?? true }
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

    @discardableResult
    func applyPIMobileConfig(
        _ config: PIMobileConfig,
        refreshToken: ProductionRemoteCapabilitySession.RefreshToken
    ) -> Bool {
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

enum ProductionMutationQualification {
    // Promote only after the retained migration matrix, pinned native signer,
    // runtime parity fixtures and funded network canaries are qualified. A
    // remote flag is a kill switch, never authority to enable an unqualified
    // binary.
    static let nexusSends = false
    static let polkamarktMutations = false
}
