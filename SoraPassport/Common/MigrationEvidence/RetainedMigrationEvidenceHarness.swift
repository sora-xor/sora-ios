import CryptoKit
import Darwin
import Foundation
import Security
import UIKit

/// Production-contained, inert-by-default observation harness for retained
/// wallet migrations. It has no release or qualification authority. The
/// harness activates only for one exact, detached-signature-authorized case.
/// All public projections are aggregate and privacy-safe; wallet identifiers,
/// Keychain values, and hashes of Keychain values never enter a receipt or UI.
enum RetainedMigrationEvidenceCheckpoint: String, Codable {
    case beforeSecretRetention = "before-secret-retention"
    case afterSecretRetention = "after-secret-retention"
    case afterCoreDataCommit = "after-core-data-commit"
    case afterNetworkStaging = "after-network-staging"
    case beforeActivation = "before-activation"
}

enum RetainedMigrationEvidenceApplicationRoute: String {
    case onboarding
    case legacyUpgradeReady = "legacy-upgrade-ready"
    case localAuthentication = "local-authentication"
    case pincodeSetup = "pincode-setup"
    case recovery

    var isSuccessfulWalletRoute: Bool {
        self == .localAuthentication || self == .pincodeSetup
    }
}

enum RetainedMigrationEvidenceControlledFailure: Error {
    case rollbackAfterLiveStoreReplacement
}

final class RetainedMigrationEvidenceHarness {
    enum BootstrapDecision: Equatable {
        case inactive
        case evidenceOnly
        case authorized
    }

    static let shared = RetainedMigrationEvidenceHarness()

    static let enrollmentArgument = "-SORA_MIGRATION_EVIDENCE_ENROLL_V3"
    static let statusAccessibilityIdentifier =
        "sora.migrationEvidence.v3.status"
    static let receiptShaAccessibilityIdentifier =
        "sora.migrationEvidence.v3.receiptSha256"
    static let receiptBase64AccessibilityIdentifier =
        "sora.migrationEvidence.v3.receiptBase64"
    static let continueUpgradeAccessibilityIdentifier =
        "sora.migrationEvidence.v3.continueUpgrade"
    static let recoveryAccessibilityIdentifier =
        "sora.migrationEvidence.v3.recovery"
    static let recoveryExportAccessibilityIdentifier =
        "sora.migrationEvidence.v3.recoveryExport"
    static let recoveryExportConfirmAccessibilityIdentifier =
        "sora.migrationEvidence.v3.recoveryExportConfirm"
    static let recoveryExportSuccessAccessibilityIdentifier =
        "sora.migrationEvidence.v3.recoveryExportSuccess"

    private static let bundleIdentifier = "co.jp.soramitsu.sora"
    private static let evidenceDirectoryName = "SoraWalletMigrationEvidence"
    private static let authorizationFileName = "authorization-request-v3.json"
    private static let signatureFileName = "authorization-request-v3.sig"
    private static let nonceFileName = "enrollment-nonce-v3.bin"
    private static let stateFileName = "harness-state-v3.json"
    private static let baselineFileName = "keychain-baseline-v3.sealed"
    private static let receiptFileName = "case-operation-receipt-v3.json"
    private static let receiptShaFileName =
        "case-operation-receipt-v3.sha256"
    private static let authorityKeyIdInfoKey =
        "SoraMigrationEvidenceAuthorizationKeyId"
    private static let authorityPublicKeyInfoKey =
        "SoraMigrationEvidenceAuthorizationPublicKeyX963Base64"
    private static let sourceRevisionInfoKey =
        "SoraMigrationEvidenceSourceRevision"
    private static let qualificationContractInfoKey =
        "SoraMigrationEvidenceQualificationContractSha256"
    private static let genericPasswordService =
        "co.jp.soramitsu.sora.retained-migration-evidence-v3"
    private static let nonceAccount = "enrollment-nonce"
    private static let maximumAuthorizationBytes = 64 * 1_024
    private static let maximumSignatureBytes = 128
    private static let maximumStateBytes = 512 * 1_024
    private static let maximumReceiptBytes = 256 * 1_024
    private static let maximumKeychainSnapshotBytes = 64 * 1_024 * 1_024
    private static let maximumEvidenceLaunches = 8
    private static let maximumAuthorizationWindow: Int64 = 48 * 60 * 60
    private static let maximumClockSkew: Int64 = 300
    private static let maximumLowStorageAvailableBytes: Int64 =
        512 * 1_024 * 1_024

    private let lock = NSLock()
    private var context: ActiveContext?
    private var currentStatus = "inactive"
    private var currentReceiptSha = ""
    private var currentReceiptBase64 = ""
    private weak var surface: RetainedMigrationEvidenceStatusView?

    private init() {}

    /// Must be called as the first operation in AppDelegate launch, before
    /// Firebase, Splash, Core Data, settings, or wallet Keychain migration.
    func bootstrap(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        bundle: Bundle = .main,
        now: Int64 = Int64(Date().timeIntervalSince1970.rounded(.down))
    ) -> BootstrapDecision {
        lock.lock()
        defer { lock.unlock() }

        guard context == nil else {
            return .authorized
        }

        do {
            let directory = try Self.evidenceDirectoryURL()
            if arguments.contains(Self.enrollmentArgument) {
                try prepareEnrollment(at: directory)
                setStatusLocked("awaiting-signed-authorization")
                return .evidenceOnly
            }

            guard Self.pathExistsNoFollow(directory) else {
                setStatusLocked("inactive")
                return .inactive
            }

            let active = try authorize(
                at: directory,
                bundle: bundle,
                now: now
            )
            context = active
            setStatusLocked("authorized-running")
            return .authorized
        } catch {
            // If a retained-evidence namespace exists but cannot be proven,
            // ordinary migration must not consume or rewrite its prepared
            // wallet state. A normal production install has no such namespace
            // and remains completely inactive.
            context = nil
            setStatusLocked("authorization-rejected")
            return .evidenceOnly
        }
    }

    func installStatusSurface(in window: UIWindow) {
        let view = RetainedMigrationEvidenceStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        window.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            view.topAnchor.constraint(equalTo: window.topAnchor),
        ])

        lock.lock()
        surface = view
        let status = currentStatus
        let receiptSha = currentReceiptSha
        let receiptBase64 = currentReceiptBase64
        lock.unlock()
        view.update(
            status: status,
            receiptSha256: receiptSha,
            receiptBase64: receiptBase64
        )
    }

    func makeEvidenceOnlyViewController() -> UIViewController {
        RetainedMigrationEvidenceViewController()
    }

    func checkpoint(_ checkpoint: RetainedMigrationEvidenceCheckpoint) {
        lock.lock()
        guard var active = context,
              active.request.interruptionCheckpoint == checkpoint,
              !active.state.checkpointSequence.contains(checkpoint.rawValue)
        else {
            lock.unlock()
            return
        }

        do {
            try transition(
                &active,
                phase: "checkpoint-reached",
                kind: "checkpoint",
                checkpoint: checkpoint.rawValue
            )
            active.state.checkpointSequence.append(checkpoint.rawValue)
            try rewriteCurrentState(&active, phase: "checkpoint-reached")
            context = active
            setStatusLocked("checkpoint-reached:\(checkpoint.rawValue)")
            lock.unlock()
        } catch {
            context = nil
            setStatusLocked("harness-failed-closed")
            lock.unlock()
            return
        }

        // The production operation remains suspended at the exact durable
        // boundary. Only the out-of-process controller/UI runner terminates
        // the app; the harness never calls exit(), abort(), or a private API.
        if Thread.isMainThread {
            // Preserve the exact suspended migration call stack while still
            // servicing accessibility and rendering for the out-of-process
            // UI runner that will terminate this launch.
            while true {
                _ = RunLoop.current.run(
                    mode: .default,
                    before: Date(timeIntervalSinceNow: 0.1)
                )
            }
        }
        let neverSignalled = DispatchSemaphore(value: 0)
        while true {
            _ = neverSignalled.wait(timeout: .now() + 60)
        }
    }

    func recordCredentialBehavior(
        signingExpected: Bool,
        signingSucceeded: Bool,
        behaviorPassed: Bool
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard var active = context else { return }
        guard active.request.caseKind == .keychain else { return }
        let behaviorShapeMatches =
            (
                active.request.evidenceCase == .watchOnly &&
                !signingExpected && !signingSucceeded
            ) ||
            (
                active.request.evidenceCase.signingExpected == true &&
                signingExpected && signingSucceeded
            )
        guard
            behaviorShapeMatches,
            active.state.signingExpectedObserved.map({
                $0 == signingExpected
            }) ?? true,
            active.state.signingSucceededObserved.map({
                $0 == signingSucceeded
            }) ?? true
        else {
            context = nil
            setStatusLocked("harness-failed-closed")
            return
        }
        active.state.signingExpectedObserved = signingExpected
        active.state.signingSucceededObserved = signingSucceeded
        active.state.credentialBehaviorProbePassed = behaviorPassed
        do {
            try transition(
                &active,
                phase: active.state.phase,
                kind: "credential-behavior",
                checkpoint: nil
            )
            context = active
        } catch {
            context = nil
            setStatusLocked("harness-failed-closed")
        }
    }

    func observeApplicationRoute(
        _ route: RetainedMigrationEvidenceApplicationRoute
    ) {
        lock.lock()
        guard context != nil else {
            lock.unlock()
            return
        }
        if route == .legacyUpgradeReady {
            if var active = context {
                do {
                    try transition(
                        &active,
                        phase: "awaiting-legacy-upgrade-confirmation",
                        kind: "application-route",
                        checkpoint: route.rawValue
                    )
                    context = active
                    setStatusLocked("awaiting-legacy-upgrade-confirmation")
                } catch {
                    context = nil
                    setStatusLocked("harness-failed-closed")
                }
            }
            lock.unlock()
            return
        }
        if route == .recovery,
           var active = context,
           active.request.evidenceCase == .recoveryArchiveExport,
           !active.state.recoveryArchiveExportVerified {
            do {
                if active.state.phase !=
                    "awaiting-recovery-archive-export" {
                    try transition(
                        &active,
                        phase: "awaiting-recovery-archive-export",
                        kind: "application-route",
                        checkpoint: route.rawValue
                    )
                }
                context = active
                setStatusLocked("awaiting-recovery-archive-export")
            } catch {
                context = nil
                setStatusLocked("harness-failed-closed")
            }
            lock.unlock()
            return
        }
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.finalize(route: route)
        }
    }

    func recordRecoveryArchiveExport(_ packageURL: URL) {
        lock.lock()
        guard var active = context,
              active.request.evidenceCase == .recoveryArchiveExport,
              !active.state.recoveryArchiveExportVerified else {
            lock.unlock()
            return
        }
        do {
            try Self.requireVerifiedRecoveryArchive(packageURL)
            active.state.recoveryArchiveExportVerified = true
            try transition(
                &active,
                phase: "recovery-archive-export-verified",
                kind: "recovery-archive-export",
                checkpoint: nil
            )
            context = active
            setStatusLocked("recovery-archive-export-verified")
            lock.unlock()
        } catch {
            context = nil
            setStatusLocked("harness-failed-closed")
            lock.unlock()
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.finalize(route: .recovery)
        }
    }

    func recordRollbackStoreBeforeReplacement(_ storeURL: URL) {
        lock.lock()
        defer { lock.unlock() }
        guard var active = context,
              active.request.evidenceCase == .rollback,
              active.state.rollbackBeforeStoreTreeSha256 == nil else {
            return
        }
        do {
            active.state.rollbackBeforeStoreTreeSha256 =
                try RollbackStoreTreeRecord.sha256(storeURL: storeURL)
            try transition(
                &active,
                phase: "rollback-source-recorded",
                kind: "rollback-source",
                checkpoint: nil
            )
            context = active
            setStatusLocked("rollback-source-recorded")
        } catch {
            context = nil
            setStatusLocked("harness-failed-closed")
        }
    }

    func injectRollbackAfterLiveStoreReplacement(
        _ storeURL: URL
    ) throws {
        lock.lock()
        guard var active = context,
              active.request.evidenceCase == .rollback else {
            lock.unlock()
            return
        }
        do {
            guard let before =
                active.state.rollbackBeforeStoreTreeSha256 else {
                throw HarnessError.stateFailure
            }
            let replacement = try RollbackStoreTreeRecord.sha256(
                storeURL: storeURL
            )
            guard replacement != before else {
                throw HarnessError.identityMismatch
            }
            active.state.rollbackReplacementStoreTreeSha256 = replacement
            active.state.rollbackInjectionObserved = true
            try transition(
                &active,
                phase: "rollback-injection-observed",
                kind: "rollback-injection",
                checkpoint: nil
            )
            context = active
            setStatusLocked("rollback-injection-observed")
            lock.unlock()
        } catch {
            context = nil
            setStatusLocked("harness-failed-closed")
            lock.unlock()
            throw error
        }
        throw RetainedMigrationEvidenceControlledFailure
            .rollbackAfterLiveStoreReplacement
    }

    func recordRollbackStoreRestoration(_ storeURL: URL) {
        lock.lock()
        defer { lock.unlock() }
        guard var active = context,
              active.request.evidenceCase == .rollback else {
            return
        }
        do {
            guard
                active.state.rollbackInjectionObserved,
                let before = active.state.rollbackBeforeStoreTreeSha256,
                active.state.rollbackReplacementStoreTreeSha256 != nil
            else {
                throw HarnessError.stateFailure
            }
            let restored = try RollbackStoreTreeRecord.sha256(
                storeURL: storeURL
            )
            guard restored == before else {
                throw HarnessError.identityMismatch
            }
            active.state.rollbackRestoredStoreTreeSha256 = restored
            active.state.rollbackRestorationVerified = true
            try transition(
                &active,
                phase: "rollback-restoration-verified",
                kind: "rollback-restoration",
                checkpoint: nil
            )
            context = active
            setStatusLocked("rollback-restoration-verified")
        } catch {
            context = nil
            setStatusLocked("harness-failed-closed")
        }
    }
}

private extension RetainedMigrationEvidenceHarness {
    enum EvidenceCaseKind: String, Codable {
        case keychain
        case device
    }

    enum EvidenceCase: String, CaseIterable {
        case mnemonic12 = "mnemonic-12"
        case mnemonic15Retained = "mnemonic-15-retained"
        case mnemonic18Retained = "mnemonic-18-retained"
        case mnemonic21Retained = "mnemonic-21-retained"
        case irohaV1PairedKeys = "iroha-v1-paired-keys"
        case mnemonic24 = "mnemonic-24"
        case rawSeed = "raw-seed"
        case legacySecret = "legacy-secret"
        case watchOnly = "watch-only"
        case missingSecret = "missing-secret"
        case corruptSecret = "corrupt-secret"
        case reinstallUpgrade = "reinstall-upgrade"
        case rollback
        case lowStorage = "low-storage"
        case recoveryArchiveExport = "recovery-archive-export"
        case processDeathRestart = "process-death-restart"
        case interruptionBeforeSecretRetention =
            "interruption-before-secret-retention"
        case interruptionAfterSecretRetention =
            "interruption-after-secret-retention"
        case interruptionAfterCoreDataCommit =
            "interruption-after-core-data-commit"
        case interruptionAfterNetworkStaging =
            "interruption-after-network-staging"
        case interruptionBeforeActivation =
            "interruption-before-activation"

        var kind: EvidenceCaseKind {
            switch self {
            case .mnemonic12, .mnemonic15Retained, .mnemonic18Retained,
                 .mnemonic21Retained, .irohaV1PairedKeys, .mnemonic24,
                 .rawSeed, .legacySecret, .watchOnly, .missingSecret,
                 .corruptSecret:
                return .keychain
            default:
                return .device
            }
        }

        var interruptionCheckpoint: RetainedMigrationEvidenceCheckpoint? {
            switch self {
            case .interruptionBeforeSecretRetention:
                return .beforeSecretRetention
            case .interruptionAfterSecretRetention:
                return .afterSecretRetention
            case .interruptionAfterCoreDataCommit:
                return .afterCoreDataCommit
            case .processDeathRestart:
                return .afterCoreDataCommit
            case .interruptionAfterNetworkStaging:
                return .afterNetworkStaging
            case .interruptionBeforeActivation:
                return .beforeActivation
            default:
                return nil
            }
        }

        var signingExpected: Bool? {
            switch self {
            case .mnemonic12, .mnemonic15Retained, .mnemonic18Retained,
                 .mnemonic21Retained, .irohaV1PairedKeys, .mnemonic24,
                 .rawSeed, .legacySecret:
                return true
            case .watchOnly, .missingSecret, .corruptSecret:
                return false
            default:
                return nil
            }
        }

        var recoveryExpected: Bool? {
            switch self {
            case .missingSecret, .corruptSecret, .rollback,
                 .lowStorage, .recoveryArchiveExport:
                return true
            case .mnemonic12, .mnemonic15Retained, .mnemonic18Retained,
                 .mnemonic21Retained, .irohaV1PairedKeys, .mnemonic24,
                 .rawSeed, .legacySecret, .watchOnly,
                 .reinstallUpgrade:
                return false
            default:
                return nil
            }
        }
    }

    struct AuthorizationRequest {
        let authorizationId: String
        let authorizationKeyId: String
        let runId: String
        let runChallengeSha256: String
        let sourceRevision: String
        let productionIpaSha256: String
        let installedAppRawTreeSha256: String
        let installedExecutableSha256: String
        let productionCanonicalProjectionSha256: String
        let installedCanonicalProjectionSha256: String
        let canonicalProjectionReceiptSha256: String
        let canonicalProjectorSourceSha256: String
        let preparedWalletInputTreeSha256: String
        let qualificationContractSha256: String
        let enrollmentNonceSha256: String
        let caseKind: EvidenceCaseKind
        let evidenceCase: EvidenceCase
        let issuedAtEpochSeconds: Int64
        let expiresAtEpochSeconds: Int64
        let maximumLaunchCount: Int

        var interruptionCheckpoint: RetainedMigrationEvidenceCheckpoint? {
            evidenceCase.interruptionCheckpoint
        }

        static let exactKeys: Set<String> = [
            "schemaVersion",
            "contractId",
            "platform",
            "purpose",
            "releaseAuthorized",
            "authorizationId",
            "authorizationKeyId",
            "signatureAlgorithm",
            "runId",
            "runChallengeSha256",
            "sourceRevision",
            "productionIpaSha256",
            "installedAppRawTreeSha256",
            "installedExecutableSha256",
            "productionCanonicalProjectionSha256",
            "installedCanonicalProjectionSha256",
            "canonicalProjectionReceiptSha256",
            "canonicalProjectorSourceSha256",
            "preparedWalletInputTreeSha256",
            "qualificationContractSha256",
            "enrollmentNonceSha256",
            "caseKind",
            "caseId",
            "issuedAtEpochSeconds",
            "expiresAtEpochSeconds",
            "maximumLaunchCount",
        ]

        static func parse(
            canonicalData data: Data,
            now: Int64
        ) throws -> AuthorizationRequest {
            let root = try StrictEvidenceJSON.object(
                fromCanonicalData: data,
                maximumBytes: maximumAuthorizationBytes,
                label: "authorization request"
            )
            guard Set(root.keys) == exactKeys else {
                throw HarnessError.invalidAuthorization
            }
            guard
                try StrictEvidenceJSON.integer(root["schemaVersion"]) == 3,
                try StrictEvidenceJSON.string(root["contractId"]) ==
                    "sora-ios-wallet-migration-evidence-authorization-v3",
                try StrictEvidenceJSON.string(root["platform"]) == "ios",
                try StrictEvidenceJSON.string(root["purpose"]) ==
                    "retained-wallet-migration-observation",
                try StrictEvidenceJSON.boolean(root["releaseAuthorized"]) == false,
                try StrictEvidenceJSON.string(root["signatureAlgorithm"]) ==
                    "ecdsa-p256-sha256"
            else {
                throw HarnessError.invalidAuthorization
            }

            let authorizationId = try StrictEvidenceJSON.string(
                root["authorizationId"]
            )
            let authorizationKeyId = try StrictEvidenceJSON.string(
                root["authorizationKeyId"]
            )
            let runId = try StrictEvidenceJSON.string(root["runId"])
            let challenge = try StrictEvidenceJSON.string(
                root["runChallengeSha256"]
            )
            let sourceRevision = try StrictEvidenceJSON.string(
                root["sourceRevision"]
            )
            let ipaSha = try StrictEvidenceJSON.string(
                root["productionIpaSha256"]
            )
            let appTreeSha = try StrictEvidenceJSON.string(
                root["installedAppRawTreeSha256"]
            )
            let executableSha = try StrictEvidenceJSON.string(
                root["installedExecutableSha256"]
            )
            let productionProjectionSha = try StrictEvidenceJSON.string(
                root["productionCanonicalProjectionSha256"]
            )
            let installedProjectionSha = try StrictEvidenceJSON.string(
                root["installedCanonicalProjectionSha256"]
            )
            let projectionReceiptSha = try StrictEvidenceJSON.string(
                root["canonicalProjectionReceiptSha256"]
            )
            let projectorSourceSha = try StrictEvidenceJSON.string(
                root["canonicalProjectorSourceSha256"]
            )
            let preparedTreeSha = try StrictEvidenceJSON.string(
                root["preparedWalletInputTreeSha256"]
            )
            let qualificationContractSha = try StrictEvidenceJSON.string(
                root["qualificationContractSha256"]
            )
            let nonceSha = try StrictEvidenceJSON.string(
                root["enrollmentNonceSha256"]
            )
            let rawKind = try StrictEvidenceJSON.string(root["caseKind"])
            let rawCase = try StrictEvidenceJSON.string(root["caseId"])
            let issued = try StrictEvidenceJSON.integer(
                root["issuedAtEpochSeconds"]
            )
            let expires = try StrictEvidenceJSON.integer(
                root["expiresAtEpochSeconds"]
            )
            let maximumLaunchCount = try StrictEvidenceJSON.integer(
                root["maximumLaunchCount"]
            )

            guard
                isCanonicalUUID(authorizationId),
                isCanonicalUUID(runId),
                isSafeIdentifier(authorizationKeyId),
                isLowerHex(challenge, count: 64),
                isLowerHex(sourceRevision, count: 40),
                isLowerHex(ipaSha, count: 64),
                isLowerHex(appTreeSha, count: 64),
                isLowerHex(executableSha, count: 64),
                isLowerHex(productionProjectionSha, count: 64),
                isLowerHex(installedProjectionSha, count: 64),
                productionProjectionSha == installedProjectionSha,
                isLowerHex(projectionReceiptSha, count: 64),
                isLowerHex(projectorSourceSha, count: 64),
                isLowerHex(preparedTreeSha, count: 64),
                isLowerHex(qualificationContractSha, count: 64),
                isLowerHex(nonceSha, count: 64),
                let kind = EvidenceCaseKind(rawValue: rawKind),
                let evidenceCase = EvidenceCase(rawValue: rawCase),
                evidenceCase.kind == kind,
                issued >= 1_577_836_800,
                issued <= now + maximumClockSkew,
                expires >= now,
                expires >= issued,
                expires - issued <= maximumAuthorizationWindow,
                maximumLaunchCount >= 1,
                maximumLaunchCount <= maximumEvidenceLaunches
            else {
                throw HarnessError.invalidAuthorization
            }

            return AuthorizationRequest(
                authorizationId: authorizationId,
                authorizationKeyId: authorizationKeyId,
                runId: runId,
                runChallengeSha256: challenge,
                sourceRevision: sourceRevision,
                productionIpaSha256: ipaSha,
                installedAppRawTreeSha256: appTreeSha,
                installedExecutableSha256: executableSha,
                productionCanonicalProjectionSha256:
                    productionProjectionSha,
                installedCanonicalProjectionSha256:
                    installedProjectionSha,
                canonicalProjectionReceiptSha256: projectionReceiptSha,
                canonicalProjectorSourceSha256: projectorSourceSha,
                preparedWalletInputTreeSha256: preparedTreeSha,
                qualificationContractSha256: qualificationContractSha,
                enrollmentNonceSha256: nonceSha,
                caseKind: kind,
                evidenceCase: evidenceCase,
                issuedAtEpochSeconds: issued,
                expiresAtEpochSeconds: expires,
                maximumLaunchCount: Int(maximumLaunchCount)
            )
        }
    }

    struct StateTransition: Codable {
        let sequence: Int
        let launchCount: Int
        let kind: String
        let checkpoint: String?
        let occurredAtEpochSeconds: Int64
        let previousStateSha256: String?
    }

    struct HarnessState: Codable {
        let schemaVersion: Int
        let contractId: String
        let platform: String
        let status: String
        let releaseAuthorized: Bool
        let authorizationId: String
        let authorizationRequestSha256: String
        let runId: String
        let caseKind: String
        let caseId: String
        var launchCount: Int
        var phase: String
        var previousStateSha256: String?
        var transitions: [StateTransition]
        var checkpointSequence: [String]
        var signingExpectedObserved: Bool?
        var signingSucceededObserved: Bool?
        var credentialBehaviorProbePassed: Bool?
        var lowStorageConditionObserved: Bool?
        var recoveryArchiveExportVerified: Bool
        var rollbackBeforeStoreTreeSha256: String?
        var rollbackReplacementStoreTreeSha256: String?
        var rollbackRestoredStoreTreeSha256: String?
        var rollbackInjectionObserved: Bool
        var rollbackRestorationVerified: Bool
        var stateAuthenticationHmacSha256: String
    }

    struct ActiveContext {
        let request: AuthorizationRequest
        let requestData: Data
        let requestSha256: String
        let directory: URL
        var state: HarnessState
        var stateBytes: Data
        let baselineKeychain: KeychainSnapshot
        let stateAuthenticationKey: SymmetricKey
    }

    enum HarnessError: Error {
        case invalidAuthorization
        case unsafeEvidenceNamespace
        case identityMismatch
        case keychainFailure
        case stateFailure
    }
}

private extension RetainedMigrationEvidenceHarness {
    func prepareEnrollment(at directory: URL) throws {
        let applicationSupport = directory.deletingLastPathComponent()
        if Self.pathExistsNoFollow(applicationSupport) {
            try Self.requireOwnedDirectoryNoFollow(applicationSupport)
        } else {
            try Self.requireOwnedDirectoryNoFollow(
                applicationSupport.deletingLastPathComponent()
            )
            try FileManager.default.createDirectory(
                at: applicationSupport,
                withIntermediateDirectories: false,
                attributes: [
                    .posixPermissions: NSNumber(value: 0o700),
                    .protectionKey: FileProtectionType.complete,
                ]
            )
            try Self.requireOwnedDirectoryNoFollow(applicationSupport)
        }
        if Self.pathExistsNoFollow(directory) {
            try requireSafeEvidenceDirectory(directory)
            let names = try exactDirectoryNames(directory)
            guard names.isSubset(of: [Self.nonceFileName]) else {
                throw HarnessError.unsafeEvidenceNamespace
            }
        } else {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: false,
                attributes: [
                    .posixPermissions: NSNumber(value: 0o700),
                    .protectionKey: FileProtectionType.complete,
                ]
            )
        }

        let nonce: Data
        if let retained = try loadGenericPassword(
            account: Self.nonceAccount
        ) {
            guard retained.count == 32 else {
                throw HarnessError.keychainFailure
            }
            nonce = retained
        } else {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                throw HarnessError.keychainFailure
            }
            nonce = Data(bytes)
            try addGenericPassword(
                nonce,
                account: Self.nonceAccount
            )
        }

        let nonceURL = directory.appendingPathComponent(Self.nonceFileName)
        if Self.pathExistsNoFollow(nonceURL) {
            let existing = try Self.readStableRegularFile(
                nonceURL,
                maximumBytes: 32,
                label: "enrollment nonce"
            )
            guard existing == nonce else {
                throw HarnessError.unsafeEvidenceNamespace
            }
        } else {
            try DurableFileWriter.write(
                nonce,
                to: nonceURL,
                fileManager: .default,
                protection: .complete
            )
        }
        try requireCompleteProtection(nonceURL)
    }

    static func observeLowStorageCondition() throws -> Bool {
        let attributes = try FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        )
        guard
            let available = attributes[.systemFreeSize] as? NSNumber,
            available.int64Value >= 0
        else {
            throw HarnessError.identityMismatch
        }
        return available.int64Value <= maximumLowStorageAvailableBytes
    }

    func authorize(
        at directory: URL,
        bundle: Bundle,
        now: Int64
    ) throws -> ActiveContext {
        try requireSafeEvidenceDirectory(directory)
        let allowedNames: Set<String> = [
            Self.authorizationFileName,
            Self.signatureFileName,
            Self.nonceFileName,
            Self.stateFileName,
            Self.baselineFileName,
            Self.receiptFileName,
            Self.receiptShaFileName,
        ]
        let names = try exactDirectoryNames(directory)
        guard
            names.isSubset(of: allowedNames),
            names.contains(Self.authorizationFileName),
            names.contains(Self.signatureFileName),
            names.contains(Self.nonceFileName),
            !names.contains(Self.receiptFileName),
            !names.contains(Self.receiptShaFileName)
        else {
            throw HarnessError.unsafeEvidenceNamespace
        }

        let requestURL = directory.appendingPathComponent(
            Self.authorizationFileName
        )
        let signatureURL = directory.appendingPathComponent(
            Self.signatureFileName
        )
        let nonceURL = directory.appendingPathComponent(Self.nonceFileName)
        for url in [requestURL, signatureURL, nonceURL] {
            try setAndRequireCompleteProtection(url)
        }

        let requestData = try Self.readStableRegularFile(
            requestURL,
            maximumBytes: Self.maximumAuthorizationBytes,
            label: "authorization request"
        )
        let request = try AuthorizationRequest.parse(
            canonicalData: requestData,
            now: now
        )
        let signatureData = try Self.readStableRegularFile(
            signatureURL,
            maximumBytes: Self.maximumSignatureBytes,
            label: "authorization signature"
        )
        try verifyAuthorizationSignature(
            requestData: requestData,
            signatureData: signatureData,
            request: request,
            bundle: bundle
        )

        let nonce = try Self.readStableRegularFile(
            nonceURL,
            maximumBytes: 32,
            label: "enrollment nonce"
        )
        let retainedNonce = try loadGenericPassword(
            account: Self.nonceAccount
        )
        guard
            nonce.count == 32,
            retainedNonce == nonce,
            Self.sha256Hex(nonce) == request.enrollmentNonceSha256
        else {
            throw HarnessError.identityMismatch
        }

        guard
            bundle.bundleIdentifier == Self.bundleIdentifier,
            let executableURL = bundle.executableURL,
            executableURL.deletingLastPathComponent().standardizedFileURL ==
                bundle.bundleURL.standardizedFileURL
        else {
            throw HarnessError.identityMismatch
        }
        let executableIdentity = try Self.hashStableRegularFile(
            executableURL,
            maximumBytes: 2 * 1_024 * 1_024 * 1_024,
            allowEmpty: false
        )
        guard
            Self.lowerHex(executableIdentity.sha256) ==
                request.installedExecutableSha256,
            try AppBundleTreeRecord.sha256(at: bundle.bundleURL) ==
                request.installedAppRawTreeSha256
        else {
            throw HarnessError.identityMismatch
        }

        let requestSha = Self.sha256Hex(requestData)
        let stateURL = directory.appendingPathComponent(Self.stateFileName)
        let baselineURL = directory.appendingPathComponent(
            Self.baselineFileName
        )
        let baselineAccount = "baseline-key-\(request.authorizationId)"
        let stateAuthenticationAccount =
            "state-auth-key-\(request.authorizationId)"
        var state: HarnessState
        var stateBytes: Data
        let baseline: KeychainSnapshot
        let hasRetainedState = names.contains(Self.stateFileName) ||
            names.contains(Self.baselineFileName)
        guard
            names.contains(Self.stateFileName) ==
                names.contains(Self.baselineFileName)
        else {
            throw HarnessError.stateFailure
        }
        let stateAuthenticationKeyData: Data
        if hasRetainedState {
            guard
                let retained = try loadGenericPassword(
                    account: stateAuthenticationAccount
                ),
                retained.count == 32
            else {
                throw HarnessError.stateFailure
            }
            stateAuthenticationKeyData = retained
        } else {
            guard
                try loadGenericPassword(
                    account: stateAuthenticationAccount
                ) == nil,
                try loadGenericPassword(account: baselineAccount) == nil
            else {
                throw HarnessError.stateFailure
            }
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(
                kSecRandomDefault,
                bytes.count,
                &bytes
            ) == errSecSuccess else {
                throw HarnessError.keychainFailure
            }
            stateAuthenticationKeyData = Data(bytes)
            try addGenericPassword(
                stateAuthenticationKeyData,
                account: stateAuthenticationAccount
            )
        }
        let stateAuthenticationKey = SymmetricKey(
            data: stateAuthenticationKeyData
        )

        if hasRetainedState {
            try setAndRequireCompleteProtection(stateURL)
            try setAndRequireCompleteProtection(baselineURL)
            stateBytes = try Self.readStableRegularFile(
                stateURL,
                maximumBytes: Self.maximumStateBytes,
                label: "harness state"
            )
            state = try loadState(
                stateBytes,
                request: request,
                requestSha: requestSha,
                authenticationKey: stateAuthenticationKey
            )
            baseline = try loadSealedKeychainBaseline(
                at: baselineURL,
                account: baselineAccount
            )
        } else {
            // This is deliberately a first-launch boundary. A successful or
            // interrupted migration mutates these exact wallet-authoritative
            // namespaces, so requiring the prepared hash again would make a
            // legitimate resumed launch deterministically impossible.
            guard try PreparedWalletTreeRecord.sha256(
                for: request.evidenceCase
            ) ==
                request.preparedWalletInputTreeSha256 else {
                throw HarnessError.identityMismatch
            }
            baseline = try KeychainSnapshot.capture()
            try writeSealedKeychainBaseline(
                baseline,
                at: baselineURL,
                account: baselineAccount
            )
            state = HarnessState(
                schemaVersion: 3,
                contractId:
                    "sora-ios-wallet-migration-evidence-harness-state-v3",
                platform: "ios",
                status: "observed",
                releaseAuthorized: false,
                authorizationId: request.authorizationId,
                authorizationRequestSha256: requestSha,
                runId: request.runId,
                caseKind: request.caseKind.rawValue,
                caseId: request.evidenceCase.rawValue,
                launchCount: 0,
                phase: "created",
                previousStateSha256: nil,
                transitions: [],
                checkpointSequence: [],
                signingExpectedObserved: nil,
                signingSucceededObserved: nil,
                credentialBehaviorProbePassed: nil,
                lowStorageConditionObserved:
                    request.evidenceCase == .lowStorage
                    ? try Self.observeLowStorageCondition()
                    : nil,
                recoveryArchiveExportVerified: false,
                rollbackBeforeStoreTreeSha256: nil,
                rollbackReplacementStoreTreeSha256: nil,
                rollbackRestoredStoreTreeSha256: nil,
                rollbackInjectionObserved: false,
                rollbackRestorationVerified: false,
                stateAuthenticationHmacSha256: ""
            )
            stateBytes = Data()
        }

        guard
            state.phase != "terminal-observed",
            state.launchCount < request.maximumLaunchCount
        else {
            throw HarnessError.stateFailure
        }

        var active = ActiveContext(
            request: request,
            requestData: requestData,
            requestSha256: requestSha,
            directory: directory,
            state: state,
            stateBytes: stateBytes,
            baselineKeychain: baseline,
            stateAuthenticationKey: stateAuthenticationKey
        )
        active.state.launchCount += 1
        try transition(
            &active,
            phase: "authorized-running",
            kind: "authorized-launch",
            checkpoint: nil,
            now: now
        )
        return active
    }

    func verifyAuthorizationSignature(
        requestData: Data,
        signatureData: Data,
        request: AuthorizationRequest,
        bundle: Bundle
    ) throws {
        guard
            let keyId = bundle.object(
                forInfoDictionaryKey: Self.authorityKeyIdInfoKey
            ) as? String,
            let publicKeyBase64 = bundle.object(
                forInfoDictionaryKey: Self.authorityPublicKeyInfoKey
            ) as? String,
            let sourceRevision = bundle.object(
                forInfoDictionaryKey: Self.sourceRevisionInfoKey
            ) as? String,
            let qualificationContractSha = bundle.object(
                forInfoDictionaryKey: Self.qualificationContractInfoKey
            ) as? String,
            Self.isSafeIdentifier(keyId),
            keyId == request.authorizationKeyId,
            sourceRevision == request.sourceRevision,
            qualificationContractSha ==
                request.qualificationContractSha256,
            !publicKeyBase64.isEmpty,
            !publicKeyBase64.contains("$("),
            let publicKeyData = Data(
                base64Encoded: publicKeyBase64,
                options: []
            ),
            publicKeyData.count == 65,
            publicKeyData.base64EncodedString() == publicKeyBase64,
            publicKeyData.first == 0x04,
            let publicKey = try? P256.Signing.PublicKey(
                x963Representation: publicKeyData
            ),
            let signature = try? P256.Signing.ECDSASignature(
                derRepresentation: signatureData
            ),
            signature.derRepresentation == signatureData,
            publicKey.isValidSignature(signature, for: requestData)
        else {
            throw HarnessError.invalidAuthorization
        }
    }
}

private extension RetainedMigrationEvidenceHarness {
    func transition(
        _ active: inout ActiveContext,
        phase: String,
        kind: String,
        checkpoint: String?,
        now: Int64 = Int64(Date().timeIntervalSince1970.rounded(.down))
    ) throws {
        guard
            Self.isSafeIdentifier(kind),
            Self.isSafeIdentifier(phase),
            active.state.transitions.count < 128
        else {
            throw HarnessError.stateFailure
        }
        let previousSha = active.stateBytes.isEmpty
            ? nil
            : Self.sha256Hex(active.stateBytes)
        active.state.previousStateSha256 = previousSha
        active.state.phase = phase
        active.state.transitions.append(
            StateTransition(
                sequence: active.state.transitions.count + 1,
                launchCount: active.state.launchCount,
                kind: kind,
                checkpoint: checkpoint,
                occurredAtEpochSeconds: now,
                previousStateSha256: previousSha
            )
        )
        try writeState(&active)
    }

    func rewriteCurrentState(
        _ active: inout ActiveContext,
        phase: String
    ) throws {
        let previousSha = Self.sha256Hex(active.stateBytes)
        active.state.previousStateSha256 = previousSha
        active.state.phase = phase
        try writeState(&active)
    }

    func writeState(_ active: inout ActiveContext) throws {
        active.state.stateAuthenticationHmacSha256 = ""
        let authenticatedPayload = try StrictEvidenceJSON.canonicalData(
            encodable: active.state,
            maximumBytes: Self.maximumStateBytes
        )
        let authenticationCode = HMAC<SHA256>.authenticationCode(
            for: authenticatedPayload,
            using: active.stateAuthenticationKey
        )
        active.state.stateAuthenticationHmacSha256 = Self.lowerHex(
            Data(authenticationCode)
        )
        let bytes = try StrictEvidenceJSON.canonicalData(
            encodable: active.state,
            maximumBytes: Self.maximumStateBytes
        )
        let url = active.directory.appendingPathComponent(Self.stateFileName)
        try DurableFileWriter.write(
            bytes,
            to: url,
            fileManager: .default,
            protection: .complete
        )
        let retained = try Self.readStableRegularFile(
            url,
            maximumBytes: Self.maximumStateBytes,
            label: "harness state"
        )
        guard retained == bytes else {
            throw HarnessError.stateFailure
        }
        try requireCompleteProtection(url)
        active.stateBytes = bytes
    }

    func loadState(
        _ data: Data,
        request: AuthorizationRequest,
        requestSha: String,
        authenticationKey: SymmetricKey
    ) throws -> HarnessState {
        let decoder = JSONDecoder()
        var state = try decoder.decode(HarnessState.self, from: data)
        let authenticationHex = state.stateAuthenticationHmacSha256
        guard
            Self.isLowerHex(authenticationHex, count: 64),
            let authenticationCode = Self.lowerHexData(
                authenticationHex
            )
        else {
            throw HarnessError.stateFailure
        }
        state.stateAuthenticationHmacSha256 = ""
        let authenticatedPayload = try StrictEvidenceJSON.canonicalData(
            encodable: state,
            maximumBytes: Self.maximumStateBytes
        )
        guard HMAC<SHA256>.isValidAuthenticationCode(
            authenticationCode,
            authenticating: authenticatedPayload,
            using: authenticationKey
        ) else {
            throw HarnessError.stateFailure
        }
        state.stateAuthenticationHmacSha256 = authenticationHex
        guard
            try StrictEvidenceJSON.canonicalData(
                encodable: state,
                maximumBytes: Self.maximumStateBytes
            ) == data,
            state.schemaVersion == 3,
            state.contractId ==
                "sora-ios-wallet-migration-evidence-harness-state-v3",
            state.platform == "ios",
            state.status == "observed",
            state.releaseAuthorized == false,
            state.authorizationId == request.authorizationId,
            state.authorizationRequestSha256 == requestSha,
            state.runId == request.runId,
            state.caseKind == request.caseKind.rawValue,
            state.caseId == request.evidenceCase.rawValue,
            (
                request.evidenceCase == .lowStorage &&
                    state.lowStorageConditionObserved != nil
            ) ||
                (
                    request.evidenceCase != .lowStorage &&
                        state.lowStorageConditionObserved == nil
                ),
            !state.recoveryArchiveExportVerified ||
                (
                    request.evidenceCase == .recoveryArchiveExport &&
                    state.transitions.contains(where: {
                        $0.kind == "recovery-archive-export"
                    })
                ),
            [
                state.rollbackBeforeStoreTreeSha256,
                state.rollbackReplacementStoreTreeSha256,
                state.rollbackRestoredStoreTreeSha256,
            ].compactMap({ $0 }).allSatisfy({
                Self.isLowerHex($0, count: 64)
            }),
            request.evidenceCase == .rollback ||
                (
                    state.rollbackBeforeStoreTreeSha256 == nil &&
                    state.rollbackReplacementStoreTreeSha256 == nil &&
                    state.rollbackRestoredStoreTreeSha256 == nil &&
                    !state.rollbackInjectionObserved &&
                    !state.rollbackRestorationVerified
                ),
            !state.rollbackInjectionObserved ||
                (
                    state.rollbackBeforeStoreTreeSha256 != nil &&
                    state.rollbackReplacementStoreTreeSha256 != nil
                ),
            !state.rollbackRestorationVerified ||
                (
                    state.rollbackInjectionObserved &&
                    state.rollbackRestoredStoreTreeSha256 ==
                        state.rollbackBeforeStoreTreeSha256 &&
                    state.transitions.contains(where: {
                        $0.kind == "rollback-restoration"
                    })
                ),
            state.launchCount >= 1,
            state.launchCount <= request.maximumLaunchCount,
            state.transitions.count <= 128,
            (
                state.transitions.count == 1 &&
                state.previousStateSha256 == nil
            ) ||
                (
                    state.transitions.count > 1 &&
                    state.previousStateSha256.map({
                        Self.isLowerHex($0, count: 64)
                    }) == true
                ),
            Set(state.checkpointSequence).count ==
                state.checkpointSequence.count,
            state.checkpointSequence.allSatisfy({
                RetainedMigrationEvidenceCheckpoint(rawValue: $0) != nil
            })
        else {
            throw HarnessError.stateFailure
        }
        for (index, transition) in state.transitions.enumerated() {
            guard
                transition.sequence == index + 1,
                transition.launchCount >= 1,
                transition.launchCount <= state.launchCount,
                Self.isSafeIdentifier(transition.kind),
                transition.checkpoint.map(Self.isSafeIdentifier) ?? true,
                transition.occurredAtEpochSeconds >= 1_577_836_800,
                transition.previousStateSha256.map({
                    Self.isLowerHex($0, count: 64)
                }) ?? true
            else {
                throw HarnessError.stateFailure
            }
            if index > 0 {
                guard
                    transition.previousStateSha256 != nil,
                    transition.launchCount >=
                        state.transitions[index - 1].launchCount
                else {
                    throw HarnessError.stateFailure
                }
            } else if transition.previousStateSha256 != nil {
                throw HarnessError.stateFailure
            }
        }
        let authorizedLaunches = state.transitions.filter {
            $0.kind == "authorized-launch"
        }.map(\.launchCount)
        guard authorizedLaunches == Array(1 ... state.launchCount) else {
            throw HarnessError.stateFailure
        }
        return state
    }

    func finalize(route: RetainedMigrationEvidenceApplicationRoute) {
        lock.lock()
        guard var active = context,
              active.state.phase != "terminal-observed" else {
            lock.unlock()
            return
        }
        do {
            let after = try KeychainSnapshot.capture()
            let comparison = active.baselineKeychain.compare(with: after)
            let caseValue = active.request.evidenceCase
            let recoveryEntered = route == .recovery
            let routeMatches: Bool
            if let recoveryExpected = caseValue.recoveryExpected {
                routeMatches = recoveryExpected == recoveryEntered &&
                    (recoveryExpected || route.isSuccessfulWalletRoute)
            } else if caseValue.interruptionCheckpoint != nil {
                let checkpointObserved =
                    active.state.checkpointSequence.contains(
                        caseValue.interruptionCheckpoint!.rawValue
                    )
                if caseValue == .interruptionBeforeSecretRetention {
                    routeMatches = checkpointObserved &&
                        !recoveryEntered && route.isSuccessfulWalletRoute
                } else {
                    routeMatches = checkpointObserved && recoveryEntered
                }
            } else {
                routeMatches = true
            }
            let processRestartMatches =
                caseValue != .processDeathRestart ||
                (
                    active.state.launchCount >= 2 &&
                    active.state.checkpointSequence.contains(
                        RetainedMigrationEvidenceCheckpoint
                            .afterCoreDataCommit.rawValue
                    )
                )
            let rollbackMatches =
                caseValue != .rollback ||
                (
                    active.state.rollbackInjectionObserved &&
                    active.state.rollbackRestorationVerified &&
                    active.state.rollbackBeforeStoreTreeSha256 != nil &&
                    active.state.rollbackReplacementStoreTreeSha256 != nil &&
                    active.state.rollbackBeforeStoreTreeSha256 !=
                        active.state.rollbackReplacementStoreTreeSha256 &&
                    active.state.rollbackRestoredStoreTreeSha256 ==
                        active.state.rollbackBeforeStoreTreeSha256
                )
            let beforeSecretRetentionMatches =
                caseValue != .interruptionBeforeSecretRetention ||
                (
                    comparison.identifierSetUnchanged &&
                    comparison.valuesByteForByteUnchanged &&
                    comparison.accessibilityUnchanged &&
                    !comparison.credentialRewriteObserved
                )
            let lowStorageMatches =
                caseValue != .lowStorage ||
                active.state.lowStorageConditionObserved == true
            let deviceActionMatches =
                (caseValue != .recoveryArchiveExport ||
                    active.state.recoveryArchiveExportVerified) &&
                processRestartMatches && rollbackMatches &&
                beforeSecretRetentionMatches && lowStorageMatches

            let expectedSigning = caseValue.signingExpected
            let observedExpected = active.state.signingExpectedObserved
            let observedSucceeded = active.state.signingSucceededObserved
            let behaviorPassed: Bool
            if let expectedSigning {
                if expectedSigning {
                    behaviorPassed =
                        active.state.credentialBehaviorProbePassed == true &&
                        observedExpected == true &&
                        observedSucceeded == true
                } else if caseValue == .watchOnly {
                    behaviorPassed =
                        active.state.credentialBehaviorProbePassed == true &&
                        observedExpected == false &&
                        observedSucceeded == false
                } else {
                    // Missing/corrupt material must reach recovery without a
                    // successful signature. The production validator's
                    // rejection plus unchanged Keychain bytes is the bounded
                    // behavior probe for these failure cohorts.
                    behaviorPassed = recoveryEntered &&
                        observedSucceeded != true
                }
            } else {
                behaviorPassed = true
            }

            let keychainPassed = comparison.identifierSetUnchanged &&
                comparison.valuesByteForByteUnchanged &&
                comparison.accessibilityUnchanged &&
                !comparison.credentialRewriteObserved &&
                behaviorPassed
            let outcome: String
            if active.request.caseKind == .keychain {
                outcome = routeMatches && keychainPassed ? "passed" : "failed"
            } else {
                // Device assertions are independently derived by the outer
                // controller from protected app-container and devicectl raw
                // receipts. The app records only the facts it directly saw.
                outcome = routeMatches && deviceActionMatches
                    ? "observed"
                    : "failed"
            }

            try transition(
                &active,
                phase: "terminal-observed",
                kind: "application-route",
                checkpoint: route.rawValue
            )
            let stateSha = Self.sha256Hex(active.stateBytes)
            let receipt = try makeReceipt(
                active: active,
                stateSha256: stateSha,
                route: route,
                outcome: outcome,
                comparison: comparison,
                behaviorPassed: behaviorPassed,
                recoveryEntered: recoveryEntered
            )
            let receiptData = try StrictEvidenceJSON.canonicalData(
                object: receipt,
                maximumBytes: Self.maximumReceiptBytes
            )
            let receiptSha = Self.sha256Hex(receiptData)
            let receiptURL = active.directory.appendingPathComponent(
                Self.receiptFileName
            )
            let receiptShaURL = active.directory.appendingPathComponent(
                Self.receiptShaFileName
            )
            guard
                !Self.pathExistsNoFollow(receiptURL),
                !Self.pathExistsNoFollow(receiptShaURL)
            else {
                throw HarnessError.stateFailure
            }
            try DurableFileWriter.write(
                receiptData,
                to: receiptURL,
                fileManager: .default,
                protection: .complete
            )
            try DurableFileWriter.write(
                Data("\(receiptSha)\n".utf8),
                to: receiptShaURL,
                fileManager: .default,
                protection: .complete
            )
            guard
                try Self.readStableRegularFile(
                    receiptURL,
                    maximumBytes: Self.maximumReceiptBytes,
                    label: "operation receipt"
                ) == receiptData,
                try Self.readStableRegularFile(
                    receiptShaURL,
                    maximumBytes: 65,
                    label: "operation receipt SHA"
                ) == Data("\(receiptSha)\n".utf8)
            else {
                throw HarnessError.stateFailure
            }
            try requireCompleteProtection(receiptURL)
            try requireCompleteProtection(receiptShaURL)
            context = active
            currentReceiptSha = receiptSha
            currentReceiptBase64 = receiptData.base64EncodedString()
            setStatusLocked("terminal-observed:\(outcome)")
            lock.unlock()
        } catch {
            context = nil
            setStatusLocked("harness-failed-closed")
            lock.unlock()
        }
    }

    func makeReceipt(
        active: ActiveContext,
        stateSha256: String,
        route: RetainedMigrationEvidenceApplicationRoute,
        outcome: String,
        comparison: KeychainComparison,
        behaviorPassed: Bool,
        recoveryEntered: Bool
    ) throws -> [String: Any] {
        let started = active.state.transitions.first?
            .occurredAtEpochSeconds ??
            Int64(Date().timeIntervalSince1970.rounded(.down))
        let finished = Int64(Date().timeIntervalSince1970.rounded(.down))
        var receipt: [String: Any] = [
            "schemaVersion": 3,
            "contractId":
                "sora-ios-wallet-migration-case-operation-receipt-v3",
            "platform": "ios",
            "status": "observed",
            "releaseAuthorized": false,
            "authorizationId": active.request.authorizationId,
            "authorizationKeyId": active.request.authorizationKeyId,
            "authorizationRequestSha256": active.requestSha256,
            "runId": active.request.runId,
            "runChallengeSha256": active.request.runChallengeSha256,
            "sourceRevision": active.request.sourceRevision,
            "qualificationContractSha256":
                active.request.qualificationContractSha256,
            "productionIpaSha256": active.request.productionIpaSha256,
            "installedAppRawTreeSha256":
                active.request.installedAppRawTreeSha256,
            "installedExecutableSha256":
                active.request.installedExecutableSha256,
            "productionCanonicalProjectionSha256":
                active.request.productionCanonicalProjectionSha256,
            "installedCanonicalProjectionSha256":
                active.request.installedCanonicalProjectionSha256,
            "canonicalProjectionReceiptSha256":
                active.request.canonicalProjectionReceiptSha256,
            "canonicalProjectorSourceSha256":
                active.request.canonicalProjectorSourceSha256,
            "preparedWalletInputTreeSha256":
                active.request.preparedWalletInputTreeSha256,
            "caseKind": active.request.caseKind.rawValue,
            "caseId": active.request.evidenceCase.rawValue,
            "outcome": outcome,
            "startedAtEpochSeconds": started,
            "finishedAtEpochSeconds": finished,
            "launchCount": active.state.launchCount,
            "harnessStateSha256": stateSha256,
            "checkpointSequence": active.state.checkpointSequence,
            "applicationRoute": route.rawValue,
        ]
        if active.request.caseKind == .keychain {
            receipt["keychainObservation"] = [
                "identifierSetUnchanged":
                    comparison.identifierSetUnchanged,
                "valuesByteForByteUnchanged":
                    comparison.valuesByteForByteUnchanged,
                "accessibilityUnchanged":
                    comparison.accessibilityUnchanged,
                "credentialRewriteObserved":
                    comparison.credentialRewriteObserved,
                "credentialBehaviorProbePassed": behaviorPassed,
                "signingExpected":
                    active.request.evidenceCase.signingExpected ?? false,
                "signingSucceeded":
                    active.state.signingSucceededObserved ?? false,
                "recoveryRouteEntered": recoveryEntered,
            ]
        } else {
            var observation: [String: Any] = [
                "recoveryRouteEntered": recoveryEntered,
                "recoveryArchiveExportVerified":
                    active.state.recoveryArchiveExportVerified,
                "processDeathRestartObserved":
                    active.request.evidenceCase == .processDeathRestart &&
                    active.state.launchCount >= 2 &&
                    active.state.checkpointSequence.contains(
                        RetainedMigrationEvidenceCheckpoint
                            .afterCoreDataCommit.rawValue
                    ),
                "controllerValidationRequired": true,
            ]
            if active.request.evidenceCase == .rollback {
                guard
                    let before =
                        active.state.rollbackBeforeStoreTreeSha256,
                    let replacement =
                        active.state.rollbackReplacementStoreTreeSha256,
                    let restored =
                        active.state.rollbackRestoredStoreTreeSha256
                else {
                    throw HarnessError.stateFailure
                }
                observation["rollbackInjectionObserved"] =
                    active.state.rollbackInjectionObserved
                observation["rollbackRestorationVerified"] =
                    active.state.rollbackRestorationVerified
                observation["rollbackBeforeStoreTreeSha256"] = before
                observation["rollbackReplacementStoreTreeSha256"] =
                    replacement
                observation["rollbackRestoredStoreTreeSha256"] = restored
            }
            if active.request.evidenceCase == .lowStorage {
                observation["lowStorageConditionObserved"] =
                    active.state.lowStorageConditionObserved == true
            }
            if active.request.evidenceCase ==
                .interruptionBeforeSecretRetention {
                observation["retainedKeychainIdentifierSetUnchanged"] =
                    comparison.identifierSetUnchanged
                observation["retainedKeychainValuesUnchanged"] =
                    comparison.valuesByteForByteUnchanged
                observation["retainedKeychainAccessibilityUnchanged"] =
                    comparison.accessibilityUnchanged
            }
            receipt["deviceObservation"] = observation
        }
        return receipt
    }
}

private extension RetainedMigrationEvidenceHarness {
    struct KeychainRecord: Codable, Equatable {
        let applicationTag: Data
        let value: Data
        let accessibility: String
        let accessGroup: String
    }

    struct KeychainSnapshot: Codable, Equatable {
        let records: [KeychainRecord]

        static func capture() throws -> KeychainSnapshot {
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecReturnAttributes as String: kCFBooleanTrue as Any,
                kSecReturnData as String: kCFBooleanTrue as Any,
                kSecMatchLimit as String: kSecMatchLimitAll,
            ]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound {
                return KeychainSnapshot(records: [])
            }
            guard status == errSecSuccess else {
                throw HarnessError.keychainFailure
            }
            let dictionaries: [[String: Any]]
            if let values = result as? [[String: Any]] {
                dictionaries = values
            } else if let value = result as? [String: Any] {
                dictionaries = [value]
            } else {
                throw HarnessError.keychainFailure
            }
            guard dictionaries.count <= 4_096 else {
                throw HarnessError.keychainFailure
            }
            var records: [KeychainRecord] = []
            var seen = Set<Data>()
            var totalBytes = 0
            for dictionary in dictionaries {
                let rawTag = dictionary[kSecAttrApplicationTag as String]
                let tag: Data
                if let data = rawTag as? Data {
                    tag = data
                } else if let string = rawTag as? String,
                          let data = string.data(using: .utf8) {
                    tag = data
                } else {
                    throw HarnessError.keychainFailure
                }
                guard
                    !tag.isEmpty,
                    tag.count <= 4_096,
                    seen.insert(tag).inserted,
                    let value = dictionary[kSecValueData as String] as? Data,
                    value.count <= 16 * 1_024 * 1_024,
                    let accessibility = dictionary[
                        kSecAttrAccessible as String
                    ] as? String,
                    !accessibility.isEmpty,
                    accessibility.utf8.count <= 256
                else {
                    throw HarnessError.keychainFailure
                }
                let accessGroup = dictionary[
                    kSecAttrAccessGroup as String
                ] as? String ?? ""
                guard accessGroup.utf8.count <= 512 else {
                    throw HarnessError.keychainFailure
                }
                totalBytes += tag.count + value.count +
                    accessibility.utf8.count + accessGroup.utf8.count
                guard totalBytes <= maximumKeychainSnapshotBytes else {
                    throw HarnessError.keychainFailure
                }
                records.append(
                    KeychainRecord(
                        applicationTag: tag,
                        value: value,
                        accessibility: accessibility,
                        accessGroup: accessGroup
                    )
                )
            }
            records.sort {
                $0.applicationTag.lexicographicallyPrecedes(
                    $1.applicationTag
                )
            }
            return KeychainSnapshot(records: records)
        }

        func compare(with other: KeychainSnapshot) -> KeychainComparison {
            let lhsTags = records.map(\.applicationTag)
            let rhsTags = other.records.map(\.applicationTag)
            let identifiersEqual = lhsTags == rhsTags
            let valuesEqual = identifiersEqual && zip(records, other.records)
                .allSatisfy { $0.value == $1.value }
            let accessibilityEqual = identifiersEqual &&
                zip(records, other.records).allSatisfy {
                    $0.accessibility == $1.accessibility &&
                        $0.accessGroup == $1.accessGroup
                }
            return KeychainComparison(
                identifierSetUnchanged: identifiersEqual,
                valuesByteForByteUnchanged: valuesEqual,
                accessibilityUnchanged: accessibilityEqual,
                credentialRewriteObserved:
                    !identifiersEqual || !valuesEqual ||
                    !accessibilityEqual
            )
        }
    }

    struct KeychainComparison {
        let identifierSetUnchanged: Bool
        let valuesByteForByteUnchanged: Bool
        let accessibilityUnchanged: Bool
        let credentialRewriteObserved: Bool
    }

    func writeSealedKeychainBaseline(
        _ snapshot: KeychainSnapshot,
        at url: URL,
        account: String
    ) throws {
        let keyData: Data
        if let existing = try loadGenericPassword(account: account) {
            guard existing.count == 32 else {
                throw HarnessError.keychainFailure
            }
            keyData = existing
        } else {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                throw HarnessError.keychainFailure
            }
            keyData = Data(bytes)
            try addGenericPassword(keyData, account: account)
        }
        let plain = try StrictEvidenceJSON.canonicalData(
            encodable: snapshot,
            maximumBytes: Self.maximumKeychainSnapshotBytes
        )
        let key = SymmetricKey(data: keyData)
        let sealed = try AES.GCM.seal(plain, using: key)
        guard let combined = sealed.combined else {
            throw HarnessError.keychainFailure
        }
        try DurableFileWriter.write(
            combined,
            to: url,
            fileManager: .default,
            protection: .complete
        )
        guard
            try Self.readStableRegularFile(
                url,
                maximumBytes: Self.maximumKeychainSnapshotBytes,
                label: "sealed Keychain baseline"
            ) == combined
        else {
            throw HarnessError.keychainFailure
        }
        try requireCompleteProtection(url)
    }

    func loadSealedKeychainBaseline(
        at url: URL,
        account: String
    ) throws -> KeychainSnapshot {
        guard let keyData = try loadGenericPassword(account: account),
              keyData.count == 32 else {
            throw HarnessError.keychainFailure
        }
        let combined = try Self.readStableRegularFile(
            url,
            maximumBytes: Self.maximumKeychainSnapshotBytes,
            label: "sealed Keychain baseline"
        )
        let box = try AES.GCM.SealedBox(combined: combined)
        let plain = try AES.GCM.open(
            box,
            using: SymmetricKey(data: keyData)
        )
        let snapshot = try JSONDecoder().decode(
            KeychainSnapshot.self,
            from: plain
        )
        guard
            try StrictEvidenceJSON.canonicalData(
                encodable: snapshot,
                maximumBytes: Self.maximumKeychainSnapshotBytes
            ) == plain
        else {
            throw HarnessError.keychainFailure
        }
        return snapshot
    }

    func loadGenericPassword(account: String) throws -> Data? {
        guard Self.isSafeIdentifier(account) else {
            throw HarnessError.keychainFailure
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.genericPasswordService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw HarnessError.keychainFailure
        }
        return data
    }

    func addGenericPassword(_ data: Data, account: String) throws {
        guard
            !data.isEmpty,
            data.count <= 4_096,
            Self.isSafeIdentifier(account)
        else {
            throw HarnessError.keychainFailure
        }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.genericPasswordService,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
            throw HarnessError.keychainFailure
        }
    }
}

private enum StrictEvidenceJSON {
    static func object(
        fromCanonicalData data: Data,
        maximumBytes: Int,
        label: String
    ) throws -> [String: Any] {
        guard
            !data.isEmpty,
            data.count <= maximumBytes,
            data.last == 0x0A,
            !data.starts(with: [0xEF, 0xBB, 0xBF]),
            let root = try JSONSerialization.jsonObject(
                with: data,
                options: []
            ) as? [String: Any]
        else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .invalidAuthorization
        }
        try validate(root, depth: 0)
        guard try canonicalData(
            object: root,
            maximumBytes: maximumBytes
        ) == data else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .invalidAuthorization
        }
        return root
    }

    static func canonicalData(
        object: [String: Any],
        maximumBytes: Int
    ) throws -> Data {
        try validate(object, depth: 0)
        guard JSONSerialization.isValidJSONObject(object) else {
            throw RetainedMigrationEvidenceHarness.HarnessError.stateFailure
        }
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        data.append(0x0A)
        guard !data.isEmpty, data.count <= maximumBytes else {
            throw RetainedMigrationEvidenceHarness.HarnessError.stateFailure
        }
        return data
    }

    static func canonicalData<T: Encodable>(
        encodable value: T,
        maximumBytes: Int
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(value)
        data.append(0x0A)
        guard !data.isEmpty, data.count <= maximumBytes else {
            throw RetainedMigrationEvidenceHarness.HarnessError.stateFailure
        }
        return data
    }

    static func string(_ value: Any?) throws -> String {
        guard let value = value as? String,
              !value.isEmpty,
              value.utf8.count <= 4_096 else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .invalidAuthorization
        }
        return value
    }

    static func boolean(_ value: Any?) throws -> Bool {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .invalidAuthorization
        }
        return number.boolValue
    }

    static func integer(_ value: Any?) throws -> Int64 {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              CFNumberIsFloatType(number) == false else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .invalidAuthorization
        }
        return number.int64Value
    }

    private static func validate(_ value: Any, depth: Int) throws {
        guard depth <= 24 else {
            throw RetainedMigrationEvidenceHarness.HarnessError.stateFailure
        }
        if let object = value as? [String: Any] {
            guard object.count <= 512 else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .stateFailure
            }
            for (key, child) in object {
                guard
                    !key.isEmpty,
                    key.utf8.count <= 256,
                    key.unicodeScalars.allSatisfy({ $0.value >= 0x20 })
                else {
                    throw RetainedMigrationEvidenceHarness.HarnessError
                        .stateFailure
                }
                try validate(child, depth: depth + 1)
            }
        } else if let array = value as? [Any] {
            guard array.count <= 4_096 else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .stateFailure
            }
            for child in array {
                try validate(child, depth: depth + 1)
            }
        } else if let string = value as? String {
            guard string.utf8.count <= 64 * 1_024 else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .stateFailure
            }
        } else if let number = value as? NSNumber {
            if CFGetTypeID(number) != CFBooleanGetTypeID(),
               CFNumberIsFloatType(number) {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .stateFailure
            }
        } else if !(value is NSNull) {
            throw RetainedMigrationEvidenceHarness.HarnessError.stateFailure
        }
    }
}

private extension RetainedMigrationEvidenceHarness {
    static func isLowerHex(_ value: String, count: Int) -> Bool {
        value.utf8.count == count && value.utf8.allSatisfy {
            (48 ... 57).contains($0) || (97 ... 102).contains($0)
        } && !value.allSatisfy({ $0 == "0" })
    }

    static func isCanonicalUUID(_ value: String) -> Bool {
        guard
            let uuid = UUID(uuidString: value),
            uuid != UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        else { return false }
        return uuid.uuidString.lowercased() == value
    }

    static func isSafeIdentifier(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard !bytes.isEmpty, bytes.count <= 128 else { return false }
        func base(_ byte: UInt8) -> Bool {
            (48 ... 57).contains(byte) || (65 ... 90).contains(byte) ||
                (97 ... 122).contains(byte) || byte == 95
        }
        guard base(bytes[0]) else { return false }
        return bytes.dropFirst().allSatisfy {
            base($0) || $0 == 45 || $0 == 46
        }
    }

    static func sha256Hex(_ data: Data) -> String {
        lowerHex(Data(SHA256.hash(data: data)))
    }

    static func lowerHex(_ data: Data) -> String {
        data.map {
            String(format: "%02x", $0)
        }.joined()
    }

    static func lowerHexData(_ value: String) -> Data? {
        guard value.utf8.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(value.utf8.count / 2)
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index ..< next], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = next
        }
        return Data(bytes)
    }

    static func pathExistsNoFollow(_ url: URL) -> Bool {
        var metadata = stat()
        return Darwin.lstat(url.path, &metadata) == 0
    }

    static func requireOwnedDirectoryNoFollow(_ url: URL) throws {
        var metadata = stat()
        guard
            Darwin.lstat(url.path, &metadata) == 0,
            (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
            metadata.st_uid == geteuid()
        else {
            throw HarnessError.unsafeEvidenceNamespace
        }
    }

    static func requireVerifiedRecoveryArchive(_ url: URL) throws {
        guard
            let caches = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first?.standardizedFileURL
        else {
            throw HarnessError.identityMismatch
        }
        let exportDirectory = caches.appendingPathComponent(
            "WalletRecoveryExports",
            isDirectory: true
        )
        let standardized = url.standardizedFileURL
        let name = standardized.lastPathComponent
        let prefix = "SORA-Wallet-Recovery-"
        let suffix = ".sorarecovery.zip"
        guard
            standardized.deletingLastPathComponent() == exportDirectory,
            name.hasPrefix(prefix),
            name.hasSuffix(suffix)
        else {
            throw HarnessError.identityMismatch
        }
        let rawID = String(
            name.dropFirst(prefix.count).dropLast(suffix.count)
        )
        guard UUID(uuidString: rawID)?.uuidString == rawID else {
            throw HarnessError.identityMismatch
        }

        let descriptor = Darwin.open(
            standardized.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw HarnessError.identityMismatch
        }
        defer { Darwin.close(descriptor) }
        var opened = stat()
        var named = stat()
        guard
            Darwin.fstat(descriptor, &opened) == 0,
            Darwin.lstat(standardized.path, &named) == 0,
            (opened.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
            opened.st_uid == geteuid(),
            opened.st_nlink == 1,
            opened.st_size > 0,
            opened.st_size <= 2 * 1_024 * 1_024 * 1_024,
            stableIdentity(opened, named),
            let protection = try FileManager.default
                .attributesOfItem(atPath: standardized.path)[.protectionKey]
                as? FileProtectionType,
            protection == .complete
        else {
            throw HarnessError.identityMismatch
        }
    }

    static func evidenceDirectoryURL() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.standardizedFileURL else {
            throw HarnessError.unsafeEvidenceNamespace
        }
        let library = applicationSupport.deletingLastPathComponent()
        try requireOwnedDirectoryNoFollow(library)
        if pathExistsNoFollow(applicationSupport) {
            try requireOwnedDirectoryNoFollow(applicationSupport)
        }
        let directory = applicationSupport.appendingPathComponent(
            evidenceDirectoryName,
            isDirectory: true
        ).standardizedFileURL
        guard directory.deletingLastPathComponent() == applicationSupport else {
            throw HarnessError.unsafeEvidenceNamespace
        }
        return directory
    }

    func requireSafeEvidenceDirectory(_ url: URL) throws {
        try Self.requireOwnedDirectoryNoFollow(
            url.deletingLastPathComponent()
        )
        var metadata = stat()
        guard
            Darwin.lstat(url.path, &metadata) == 0,
            (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
            metadata.st_uid == geteuid(),
            (metadata.st_mode & mode_t(0o077)) == 0
        else {
            throw HarnessError.unsafeEvidenceNamespace
        }
    }

    func exactDirectoryNames(_ url: URL) throws -> Set<String> {
        let children = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: []
        )
        var names = Set<String>()
        for child in children {
            let name = child.lastPathComponent
            guard
                Self.isSafeIdentifier(name),
                child.deletingLastPathComponent().standardizedFileURL ==
                    url.standardizedFileURL,
                names.insert(name).inserted
            else {
                throw HarnessError.unsafeEvidenceNamespace
            }
            var metadata = stat()
            guard
                Darwin.lstat(child.path, &metadata) == 0,
                (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
                metadata.st_uid == geteuid(),
                metadata.st_nlink == 1
            else {
                throw HarnessError.unsafeEvidenceNamespace
            }
        }
        return names
    }

    func setAndRequireCompleteProtection(_ url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        try requireCompleteProtection(url)
    }

    func requireCompleteProtection(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(
            atPath: url.path
        )
        guard
            let protection = attributes[.protectionKey]
                as? FileProtectionType,
            protection == .complete
        else {
            throw HarnessError.unsafeEvidenceNamespace
        }
    }

    static func readStableRegularFile(
        _ url: URL,
        maximumBytes: Int,
        label: String,
        allowEmpty: Bool = false
    ) throws -> Data {
        let descriptor = Darwin.open(
            url.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw HarnessError.unsafeEvidenceNamespace
        }
        defer { Darwin.close(descriptor) }
        var before = stat()
        guard
            Darwin.fstat(descriptor, &before) == 0,
            (before.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
            before.st_uid == geteuid(),
            before.st_nlink == 1,
            before.st_size >= (allowEmpty ? 0 : 1),
            before.st_size <= maximumBytes
        else {
            throw HarnessError.unsafeEvidenceNamespace
        }
        var data = Data()
        data.reserveCapacity(Int(before.st_size))
        var buffer = [UInt8](repeating: 0, count: 256 * 1_024)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count < 0, errno == EINTR { continue }
            guard count >= 0 else {
                throw HarnessError.unsafeEvidenceNamespace
            }
            if count == 0 { break }
            data.append(contentsOf: buffer[0 ..< count])
            guard data.count <= maximumBytes else {
                throw HarnessError.unsafeEvidenceNamespace
            }
        }
        var after = stat()
        var pathAfter = stat()
        guard
            Darwin.fstat(descriptor, &after) == 0,
            Darwin.lstat(url.path, &pathAfter) == 0,
            data.count == before.st_size,
            stableIdentity(before, after),
            stableIdentity(before, pathAfter)
        else {
            throw HarnessError.unsafeEvidenceNamespace
        }
        return data
    }

    static func hashStableRegularFile(
        _ url: URL,
        maximumBytes: Int64,
        allowEmpty: Bool
    ) throws -> (byteCount: Int64, sha256: Data, executable: Bool) {
        let descriptor = Darwin.open(
            url.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw HarnessError.unsafeEvidenceNamespace
        }
        defer { Darwin.close(descriptor) }
        var before = stat()
        guard
            Darwin.fstat(descriptor, &before) == 0,
            (before.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
            before.st_uid == geteuid(),
            before.st_nlink == 1,
            before.st_size >= (allowEmpty ? 0 : 1),
            before.st_size <= maximumBytes
        else {
            throw HarnessError.unsafeEvidenceNamespace
        }
        var hasher = SHA256()
        var total: Int64 = 0
        var buffer = [UInt8](repeating: 0, count: 256 * 1_024)
        while true {
            let count = buffer.withUnsafeMutableBytes { storage in
                Darwin.read(
                    descriptor,
                    storage.baseAddress,
                    storage.count
                )
            }
            if count < 0, errno == EINTR { continue }
            guard count >= 0 else {
                throw HarnessError.unsafeEvidenceNamespace
            }
            if count == 0 { break }
            guard total <= maximumBytes - Int64(count) else {
                throw HarnessError.unsafeEvidenceNamespace
            }
            total += Int64(count)
            hasher.update(data: Data(buffer[0 ..< count]))
        }
        var after = stat()
        var named = stat()
        guard
            total == before.st_size,
            Darwin.fstat(descriptor, &after) == 0,
            Darwin.lstat(url.path, &named) == 0,
            stableIdentity(before, after),
            stableIdentity(before, named)
        else {
            throw HarnessError.unsafeEvidenceNamespace
        }
        return (
            byteCount: total,
            sha256: Data(hasher.finalize()),
            executable: (before.st_mode & mode_t(0o111)) != 0
        )
    }

    static func stableIdentity(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev &&
            lhs.st_ino == rhs.st_ino &&
            lhs.st_mode == rhs.st_mode &&
            lhs.st_nlink == rhs.st_nlink &&
            lhs.st_uid == rhs.st_uid &&
            lhs.st_size == rhs.st_size &&
            lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec &&
            lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec &&
            lhs.st_ctimespec.tv_sec == rhs.st_ctimespec.tv_sec &&
            lhs.st_ctimespec.tv_nsec == rhs.st_ctimespec.tv_nsec
    }

    func setStatusLocked(_ status: String) {
        currentStatus = status
        let receiptSha = currentReceiptSha
        let receiptBase64 = currentReceiptBase64
        let update: () -> Void = { [weak self] in
            self?.surface?.update(
                status: status,
                receiptSha256: receiptSha,
                receiptBase64: receiptBase64
            )
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }
}

private struct EvidenceTreeFile {
    let relativePath: String
    let executable: Bool
    let byteCount: Int64
    let sha256: Data
}

private enum EvidenceTreeScanner {
    private static let maximumFileBytes: Int64 =
        2 * 1_024 * 1_024 * 1_024
    private static let maximumTotalBytes: Int64 =
        8 * 1_024 * 1_024 * 1_024
    private static let maximumFiles = 100_000

    static func scan(
        directory: URL,
        allowEmptyDirectories: Bool,
        strictASCIIComponents: Bool = false,
        validatePath: ((String, Bool) throws -> Void)? = nil
    ) throws -> [EvidenceTreeFile] {
        var rootMetadata = stat()
        guard
            Darwin.lstat(directory.path, &rootMetadata) == 0,
            (rootMetadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
            rootMetadata.st_uid == geteuid()
        else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .unsafeEvidenceNamespace
        }
        var files: [EvidenceTreeFile] = []
        var normalizedNodes = Set<String>()
        var inodeIdentities: Set<String> = [
            "\(rootMetadata.st_dev):\(rootMetadata.st_ino)",
        ]
        var totalBytes: Int64 = 0
        _ = try walk(
            directory: directory,
            relativePrefix: "",
            allowEmptyDirectories: allowEmptyDirectories,
            strictASCIIComponents: strictASCIIComponents,
            validatePath: validatePath,
            files: &files,
            normalizedNodes: &normalizedNodes,
            inodeIdentities: &inodeIdentities,
            totalBytes: &totalBytes
        )
        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private static func walk(
        directory: URL,
        relativePrefix: String,
        allowEmptyDirectories: Bool,
        strictASCIIComponents: Bool,
        validatePath: ((String, Bool) throws -> Void)?,
        files: inout [EvidenceTreeFile],
        normalizedNodes: inout Set<String>,
        inodeIdentities: inout Set<String>,
        totalBytes: inout Int64
    ) throws -> Int {
        var before = stat()
        guard
            Darwin.lstat(directory.path, &before) == 0,
            (before.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
            before.st_uid == geteuid()
        else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .unsafeEvidenceNamespace
        }
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
        var descendantFiles = 0
        for child in children {
            let name = child.lastPathComponent
            guard safeComponent(
                name,
                strictASCII: strictASCIIComponents
            ),
                  child.deletingLastPathComponent().standardizedFileURL ==
                    directory.standardizedFileURL else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .unsafeEvidenceNamespace
            }
            let relative = relativePrefix.isEmpty
                ? name
                : "\(relativePrefix)/\(name)"
            let normalized = relative.precomposedStringWithCanonicalMapping
            let folded = normalized.folding(
                options: [.caseInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            guard
                normalized == relative,
                normalizedNodes.insert("n:\(normalized)").inserted,
                normalizedNodes.insert("f:\(folded)").inserted
            else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .unsafeEvidenceNamespace
            }
            var metadata = stat()
            guard Darwin.lstat(child.path, &metadata) == 0,
                  metadata.st_uid == geteuid() else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .unsafeEvidenceNamespace
            }
            let fileType = metadata.st_mode & mode_t(S_IFMT)
            if fileType == mode_t(S_IFDIR) {
                guard inodeIdentities.insert(
                    "\(metadata.st_dev):\(metadata.st_ino)"
                ).inserted else {
                    throw RetainedMigrationEvidenceHarness.HarnessError
                        .unsafeEvidenceNamespace
                }
                try validatePath?(relative, true)
                let count = try walk(
                    directory: child,
                    relativePrefix: relative,
                    allowEmptyDirectories: allowEmptyDirectories,
                    strictASCIIComponents: strictASCIIComponents,
                    validatePath: validatePath,
                    files: &files,
                    normalizedNodes: &normalizedNodes,
                    inodeIdentities: &inodeIdentities,
                    totalBytes: &totalBytes
                )
                guard allowEmptyDirectories || count > 0 else {
                    throw RetainedMigrationEvidenceHarness.HarnessError
                        .unsafeEvidenceNamespace
                }
                descendantFiles += count
                continue
            }
            guard
                fileType == mode_t(S_IFREG),
                metadata.st_nlink == 1,
                metadata.st_size >= 0,
                metadata.st_size <= maximumFileBytes,
                inodeIdentities.insert(
                    "\(metadata.st_dev):\(metadata.st_ino)"
                ).inserted
            else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .unsafeEvidenceNamespace
            }
            try validatePath?(relative, false)
            let hashed = try RetainedMigrationEvidenceHarness
                .hashStableRegularFile(
                    child,
                    maximumBytes: maximumFileBytes,
                    allowEmpty: true
                )
            guard
                totalBytes <= maximumTotalBytes - hashed.byteCount,
                files.count < maximumFiles
            else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .unsafeEvidenceNamespace
            }
            totalBytes += hashed.byteCount
            files.append(
                EvidenceTreeFile(
                    relativePath: relative,
                    executable: hashed.executable,
                    byteCount: hashed.byteCount,
                    sha256: hashed.sha256
                )
            )
            descendantFiles += 1
        }
        var after = stat()
        guard
            Darwin.lstat(directory.path, &after) == 0,
            RetainedMigrationEvidenceHarness.stableIdentity(before, after)
        else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .unsafeEvidenceNamespace
        }
        return descendantFiles
    }

    private static func safeComponent(
        _ value: String,
        strictASCII: Bool
    ) -> Bool {
        let bytes = Array(value.utf8)
        guard
            !bytes.isEmpty,
            bytes.count <= 256,
            value != ".",
            value != "..",
            !value.contains("/")
        else { return false }
        if !strictASCII {
            return bytes.allSatisfy {
                $0 >= 0x20 && $0 != 0x7f && $0 != 0
            }
        }
        guard isBase(bytes[0]) else { return false }
        return bytes.dropFirst().allSatisfy {
            isBase($0) || $0 == 0x2e || $0 == 0x2b || $0 == 0x40 ||
                $0 == 0x2d
        }
    }

    private static func isBase(_ byte: UInt8) -> Bool {
        (48 ... 57).contains(byte) || (65 ... 90).contains(byte) ||
            (97 ... 122).contains(byte) || byte == 0x5f
    }
}

private enum AppBundleTreeRecord {
    private static let prefix = Data(
        "SORA-IOS-MIGRATION-RAW-APP-TREE-V1\0".utf8
    )

    static func sha256(at appURL: URL) throws -> String {
        let files = try EvidenceTreeScanner.scan(
            directory: appURL,
            allowEmptyDirectories: false,
            strictASCIIComponents: true
        )
        guard files.count <= Int(UInt32.max) else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .identityMismatch
        }
        var record = prefix
        appendBigEndian(UInt32(files.count), to: &record)
        for file in files {
            let path = Data(file.relativePath.utf8)
            guard
                path.count <= Int(UInt32.max),
                file.sha256.count == 32
            else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .identityMismatch
            }
            appendBigEndian(UInt32(path.count), to: &record)
            record.append(path)
            record.append(file.executable ? 0x45 : 0x4e)
            appendBigEndian(UInt64(file.byteCount), to: &record)
            record.append(file.sha256)
        }
        return RetainedMigrationEvidenceHarness.sha256Hex(record)
    }
}

private enum RollbackStoreTreeRecord {
    private static let prefix = Data(
        "SORA-IOS-MIGRATION-ROLLBACK-STORE-BUNDLE-V1\0".utf8
    )

    static func sha256(storeURL: URL) throws -> String {
        let standardized = storeURL.standardizedFileURL
        guard standardized.lastPathComponent == "UserDataModel.sqlite" else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .identityMismatch
        }
        let names = [
            "UserDataModel.sqlite",
            "UserDataModel.sqlite-wal",
            "UserDataModel.sqlite-shm",
            "UserDataModel.sqlite-journal",
        ]
        var files: [EvidenceTreeFile] = []
        for name in names {
            let url = standardized.deletingLastPathComponent()
                .appendingPathComponent(name)
            var metadata = stat()
            if Darwin.lstat(url.path, &metadata) != 0 {
                guard errno == ENOENT, name != names[0] else {
                    throw RetainedMigrationEvidenceHarness.HarnessError
                        .identityMismatch
                }
                continue
            }
            let hashed = try RetainedMigrationEvidenceHarness
                .hashStableRegularFile(
                    url,
                    maximumBytes: 2 * 1_024 * 1_024 * 1_024,
                    allowEmpty: false
                )
            files.append(
                EvidenceTreeFile(
                    relativePath: name,
                    executable: hashed.executable,
                    byteCount: hashed.byteCount,
                    sha256: hashed.sha256
                )
            )
        }
        guard files.first?.relativePath == names[0] else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .identityMismatch
        }
        var record = prefix
        appendBigEndian(UInt32(files.count), to: &record)
        for file in files {
            let name = Data(file.relativePath.utf8)
            appendBigEndian(UInt32(name.count), to: &record)
            record.append(name)
            record.append(file.executable ? 0x45 : 0x4e)
            appendBigEndian(UInt64(file.byteCount), to: &record)
            record.append(file.sha256)
        }
        return RetainedMigrationEvidenceHarness.sha256Hex(record)
    }
}

private enum PreparedWalletTreeRecord {
    private static let prefix = Data(
        "SORA-IOS-MIGRATION-WALLET-INPUT-TREE-V1\0".utf8
    )

    private struct Role {
        let name: String
        let url: URL
        let regularFile: Bool
        let validator: ((String, Bool) throws -> Void)?
    }

    static func sha256(
        for evidenceCase: RetainedMigrationEvidenceHarness.EvidenceCase
    ) throws -> String {
        let manager = FileManager.default
        guard
            let documents = manager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first?.standardizedFileURL,
            let applicationSupport = manager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first?.standardizedFileURL
        else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .identityMismatch
        }
        let home = URL(
            fileURLWithPath: NSHomeDirectory(),
            isDirectory: true
        ).standardizedFileURL
        let library = home.appendingPathComponent(
            "Library",
            isDirectory: true
        )
        guard
            documents.deletingLastPathComponent() == home,
            applicationSupport.deletingLastPathComponent() == library
        else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .identityMismatch
        }
        try RetainedMigrationEvidenceHarness.requireOwnedDirectoryNoFollow(
            home
        )
        try RetainedMigrationEvidenceHarness.requireOwnedDirectoryNoFollow(
            documents
        )
        try RetainedMigrationEvidenceHarness.requireOwnedDirectoryNoFollow(
            library
        )
        try RetainedMigrationEvidenceHarness.requireOwnedDirectoryNoFollow(
            applicationSupport
        )
        try RetainedMigrationEvidenceHarness.requireOwnedDirectoryNoFollow(
            library.appendingPathComponent(
                "Preferences",
                isDirectory: true
            )
        )
        let soraSupport = applicationSupport.appendingPathComponent(
            "SORA",
            isDirectory: true
        )
        if RetainedMigrationEvidenceHarness.pathExistsNoFollow(soraSupport) {
            try RetainedMigrationEvidenceHarness
                .requireOwnedDirectoryNoFollow(soraSupport)
        }
        let roles = [
            Role(
                name: "Documents/CoreData",
                url: documents.appendingPathComponent(
                    "CoreData",
                    isDirectory: true
                ),
                regularFile: false,
                validator: validateCoreDataPath
            ),
            Role(
                name:
                    "Library/Preferences/co.jp.soramitsu.sora.plist",
                url: library
                    .appendingPathComponent(
                        "Preferences",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "co.jp.soramitsu.sora.plist"
                    ),
                regularFile: true,
                validator: nil
            ),
            Role(
                name:
                    "Library/Application Support/SORA/WalletNetworks",
                url: applicationSupport
                    .appendingPathComponent("SORA", isDirectory: true)
                    .appendingPathComponent(
                        "WalletNetworks",
                        isDirectory: true
                    ),
                regularFile: false,
                validator: validateWalletNetworkPath
            ),
            Role(
                name:
                    "Library/Application Support/SORA/WalletAccountCommits",
                url: applicationSupport
                    .appendingPathComponent("SORA", isDirectory: true)
                    .appendingPathComponent(
                        "WalletAccountCommits",
                        isDirectory: true
                    ),
                regularFile: false,
                validator: validateWalletCommitPath
            ),
        ]
        var record = prefix
        appendBigEndian(UInt32(roles.count), to: &record)
        var filesByRole: [String: [EvidenceTreeFile]] = [:]
        for role in roles {
            let roleBytes = Data(role.name.utf8)
            guard roleBytes.count <= Int(UInt32.max) else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .identityMismatch
            }
            appendBigEndian(UInt32(roleBytes.count), to: &record)
            record.append(roleBytes)
            var metadata = stat()
            if Darwin.lstat(role.url.path, &metadata) != 0 {
                guard errno == ENOENT else {
                    throw RetainedMigrationEvidenceHarness.HarnessError
                        .identityMismatch
                }
                record.append(0x41)
                filesByRole[role.name] = []
                continue
            }
            record.append(0x50)
            let files: [EvidenceTreeFile]
            if role.regularFile {
                guard
                    (metadata.st_mode & mode_t(S_IFMT)) ==
                        mode_t(S_IFREG),
                    metadata.st_uid == geteuid(),
                    metadata.st_nlink == 1
                else {
                    throw RetainedMigrationEvidenceHarness.HarnessError
                        .identityMismatch
                }
                let hashed = try RetainedMigrationEvidenceHarness
                    .hashStableRegularFile(
                        role.url,
                        maximumBytes: 64 * 1_024 * 1_024,
                        allowEmpty: true
                    )
                files = [
                    EvidenceTreeFile(
                        relativePath: "",
                        executable: hashed.executable,
                        byteCount: hashed.byteCount,
                        sha256: hashed.sha256
                    ),
                ]
            } else {
                files = try EvidenceTreeScanner.scan(
                    directory: role.url,
                    allowEmptyDirectories: false,
                    validatePath: role.validator
                )
            }
            filesByRole[role.name] = files
            guard files.count <= Int(UInt32.max) else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .identityMismatch
            }
            appendBigEndian(UInt32(files.count), to: &record)
            for file in files {
                let path = Data(file.relativePath.utf8)
                guard path.count <= Int(UInt32.max) else {
                    throw RetainedMigrationEvidenceHarness.HarnessError
                        .identityMismatch
                }
                appendBigEndian(UInt32(path.count), to: &record)
                record.append(path)
                record.append(file.executable ? 0x45 : 0x4e)
                appendBigEndian(UInt64(file.byteCount), to: &record)
                record.append(file.sha256)
            }
        }
        try requireExpectedRetainedWalletEvidence(
            filesByRole,
            evidenceCase: evidenceCase
        )
        return RetainedMigrationEvidenceHarness.sha256Hex(record)
    }

    private static func requireExpectedRetainedWalletEvidence(
        _ filesByRole: [String: [EvidenceTreeFile]],
        evidenceCase: RetainedMigrationEvidenceHarness.EvidenceCase
    ) throws {
        let coreData = filesByRole["Documents/CoreData"] ?? []
        let preferences = filesByRole[
            "Library/Preferences/co.jp.soramitsu.sora.plist"
        ] ?? []
        guard
            coreData.contains(where: {
                $0.relativePath == "UserDataModel.sqlite"
            }),
            preferences.count == 1,
            preferences.first?.relativePath == ""
        else {
            throw RetainedMigrationEvidenceHarness.HarnessError
                .identityMismatch
        }
        if evidenceCase == .recoveryArchiveExport {
            var attemptPaths: [String: Set<String>] = [:]
            for file in coreData {
                let components = file.relativePath.split(separator: "/")
                guard components.count >= 3,
                      components[0] == "WalletMigrationSafety" else {
                    continue
                }
                let attempt = String(components[1])
                guard UUID(uuidString: attempt)?.uuidString == attempt else {
                    throw RetainedMigrationEvidenceHarness.HarnessError
                        .identityMismatch
                }
                attemptPaths[attempt, default: []].insert(
                    components.dropFirst(2).joined(separator: "/")
                )
            }
            let required: Set<String> = [
                "account-manifest.json",
                "settings-backup.plist",
                "journal.json",
                "legacy-store/UserDataModel.sqlite",
                "legacy-store/backup-manifest.json",
                "staging/UserDataModel 2.sqlite",
            ]
            guard attemptPaths.values.contains(where: {
                required.isSubset(of: $0)
            }) else {
                throw RetainedMigrationEvidenceHarness.HarnessError
                    .identityMismatch
            }
        }
    }

    private static func validateCoreDataPath(
        _ path: String,
        isDirectory: Bool
    ) throws {
        let components = path.split(separator: "/").map(String.init)
        guard let first = components.first else { throw invalid() }
        let liveFiles: Set<String> = [
            "UserDataModel.sqlite",
            "UserDataModel.sqlite-wal",
            "UserDataModel.sqlite-shm",
            "UserDataModel.sqlite-journal",
        ]
        if components.count == 1 {
            if first == "WalletMigrationSafety" {
                guard isDirectory else { throw invalid() }
                return
            }
            guard !isDirectory, liveFiles.contains(first) else {
                throw invalid()
            }
            return
        }
        guard first == "WalletMigrationSafety" else { throw invalid() }
        try validateSafetyPath(Array(components.dropFirst()), isDirectory)
    }

    private static func validateSafetyPath(
        _ components: [String],
        _ isDirectory: Bool
    ) throws {
        guard let attempt = components.first,
              UUID(uuidString: attempt)?.uuidString == attempt else {
            throw invalid()
        }
        if components.count == 1 {
            guard isDirectory else { throw invalid() }
            return
        }
        let tail = Array(components.dropFirst())
        let rootFiles: Set<String> = [
            "account-manifest.json",
            "settings-backup.plist",
            "journal.json",
        ]
        if tail.count == 1 {
            if ["legacy-store", "staging"].contains(tail[0]) {
                guard isDirectory else { throw invalid() }
            } else {
                guard !isDirectory, rootFiles.contains(tail[0]) else {
                    throw invalid()
                }
            }
            return
        }
        guard tail.count == 2, !isDirectory else {
            throw invalid()
        }
        let allowed: Set<String>
        if tail[0] == "legacy-store" {
            allowed = [
                "UserDataModel.sqlite",
                "UserDataModel.sqlite-wal",
                "UserDataModel.sqlite-shm",
                "backup-manifest.json",
            ]
        } else if tail[0] == "staging" {
            allowed = [
                "UserDataModel 2.sqlite",
                "UserDataModel 2.sqlite-wal",
                "UserDataModel 2.sqlite-shm",
                "UserDataModel 2.sqlite-journal",
            ]
        } else {
            throw invalid()
        }
        guard allowed.contains(tail[1]) else { throw invalid() }
    }

    private static func validateWalletNetworkPath(
        _ path: String,
        isDirectory: Bool
    ) throws {
        guard !isDirectory, !path.contains("/") else { throw invalid() }
        if path == "active.json" { return }
        guard
            path.hasPrefix("wallet-network-"),
            path.hasSuffix(".json")
        else { throw invalid() }
        let uuid = String(
            path.dropFirst("wallet-network-".count).dropLast(5)
        )
        guard UUID(uuidString: uuid)?.uuidString == uuid else {
            throw invalid()
        }
    }

    private static func validateWalletCommitPath(
        _ path: String,
        isDirectory: Bool
    ) throws {
        guard
            !isDirectory,
            !path.contains("/"),
            path.hasPrefix("wallet-account-"),
            path.hasSuffix(".json")
        else { throw invalid() }
        let uuid = String(
            path.dropFirst("wallet-account-".count).dropLast(5)
        )
        guard UUID(uuidString: uuid)?.uuidString == uuid else {
            throw invalid()
        }
    }

    private static func invalid() -> Error {
        RetainedMigrationEvidenceHarness.HarnessError.identityMismatch
    }
}

private func appendBigEndian<T: FixedWidthInteger>(
    _ value: T,
    to data: inout Data
) {
    var encoded = value.bigEndian
    withUnsafeBytes(of: &encoded) { data.append(contentsOf: $0) }
}

/// A deliberately small, privacy-safe accessibility surface. It publishes
/// only bounded harness status and the already public operation receipt bytes;
/// it never exposes wallet identifiers or Keychain material.
final class RetainedMigrationEvidenceStatusView: UIView {
    private let statusLabel = UILabel()
    private let receiptShaLabel = UILabel()
    private let receiptBase64Label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        accessibilityViewIsModal = false

        let labels = [statusLabel, receiptShaLabel, receiptBase64Label]
        labels.forEach {
            $0.font = .monospacedSystemFont(ofSize: 8, weight: .regular)
            $0.numberOfLines = 1
            $0.lineBreakMode = .byTruncatingTail
            $0.isAccessibilityElement = true
        }
        statusLabel.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness.statusAccessibilityIdentifier
        receiptShaLabel.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .receiptShaAccessibilityIdentifier
        receiptBase64Label.accessibilityIdentifier =
            RetainedMigrationEvidenceHarness
                .receiptBase64AccessibilityIdentifier

        let stack = UIStackView(arrangedSubviews: labels)
        stack.axis = .vertical
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(
        status: String,
        receiptSha256: String,
        receiptBase64: String
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        statusLabel.text = status
        statusLabel.accessibilityLabel = status
        receiptShaLabel.text = receiptSha256
        receiptShaLabel.accessibilityLabel = receiptSha256
        receiptBase64Label.text = receiptBase64
        receiptBase64Label.accessibilityLabel = receiptBase64
    }
}

final class RetainedMigrationEvidenceViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Retained migration evidence"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
