// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import CoreData
import CryptoKit
import IrohaCrypto
import RobinHood
import Security
import SoraKeystore
import SSFCrypto
import SSFUtils
import UIKit
import XCTest
@testable import SoraPassport

private struct LiquidityBatchWireFixture {
    let call: JSON
    let registerCallName: String
    let initializeCallName: String
}

private struct SharedWalletDerivationFixture: Decodable {
    struct Sora2Contract: Decodable {
        let curve: String
        let ss58Prefix: Int
        let derivationVersion: Int
        let derivationPath: String
    }

    struct Vector: Decodable {
        struct Sora2: Decodable {
            let directBip39Seed32Hex: String
            let legacySora2MiniSeedHex: String
            let publicKeyHex: String
            let address: String
        }

        let name: String
        let mnemonic: String
        let sora2: Sora2?
    }

    let format: String
    let sora2: Sora2Contract
    let vectors: [Vector]
}

private final class LockedInvocationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false

    func markCalled() {
        lock.lock()
        storage = true
        lock.unlock()
    }

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private func makeLiquidityBatchWireFixture(
    assetA: String,
    assetB: String
) throws -> LiquidityBatchWireFixture {
    let callFactory = SoraPassport.SubstrateCallFactory()
    let registerCall = try callFactory.register(
        dexId: "0",
        baseAssetId: assetA,
        targetAssetId: assetB
    )
    let initializeCall = try callFactory.initializePool(
        dexId: "0",
        baseAssetId: assetA,
        targetAssetId: assetB
    )
    let desiredA: BigUInt = 101
    let desiredB: BigUInt = 202
    let minimumA: BigUInt = 100
    let minimumB: BigUInt = 200
    let depositCallJSON = try callFactory.depositLiquidityScaleCompatibleJSON(
        dexId: "0",
        assetA: assetA,
        assetB: assetB,
        desiredA: desiredA,
        desiredB: desiredB,
        minA: minimumA,
        minB: minimumB
    )
    let calls: [JSON] = [
        try callFactory.scaleCompatibleJSON(for: registerCall),
        try callFactory.scaleCompatibleJSON(for: initializeCall),
        depositCallJSON,
    ]
    let batchCall = RuntimeCall<BatchArgs>(
        moduleName: KnowRuntimeModule.Utitlity.name,
        callName: KnowRuntimeModule.Utitlity.batchAll,
        args: BatchArgs(calls: calls)
    )
    return LiquidityBatchWireFixture(
        call: try callFactory.scaleCompatibleJSON(for: batchCall),
        registerCallName: registerCall.callName,
        initializeCallName: initializeCall.callName
    )
}

final class WalletModernizationTests: XCTestCase {
    private static let nexusXorAssetDefinitionID =
        "6TEAJqbb8oEPmLncoNiMRbLEK6tw"

    private static let tairaUUIDs = (
        first: "809574f5-fee7-5e69-bfcf-52451e42d50f",
        second: "fc56984b-2be7-431d-840e-21514d1883f0"
    )

    private static func tairaAdmissionInfo(
        currentChainId: String = tairaUUIDs.second,
        currentDeploymentEpoch: String = "200",
        retiredDeploymentEpoch: String = "100"
    ) -> [String: Any] {
        let retiredChainId = currentChainId == tairaUUIDs.first
            ? tairaUUIDs.second
            : tairaUUIDs.first
        return [
            "SoraTairaDeploymentAdmissionContractId":
                "sora-ios-taira-deployment-admission-v1",
            "SoraTairaDeploymentManifestSha256":
                String(repeating: "a", count: 64),
            "SoraTairaDeploymentAdmissionSha256":
                String(repeating: "b", count: 64),
            "SoraTairaCurrentChainId": currentChainId,
            "SoraTairaRetiredChainId": retiredChainId,
            "SoraTairaCurrentGenesisHash":
                String(repeating: "c", count: 64),
            "SoraTairaRetiredGenesisHash":
                String(repeating: "d", count: 64),
            "SoraTairaCurrentDeploymentEpoch": currentDeploymentEpoch,
            "SoraTairaRetiredDeploymentEpoch": retiredDeploymentEpoch,
            "SoraTairaCanonicalToriiBaseUrl":
                "https://public-01.taira.example.org",
            "SoraTairaPublicMcpEndpoint":
                "https://public-01.taira.example.org/v1/mcp",
            "SoraTairaPendingRowPolicy":
                "schema-77:preserve-exact-uuid:quarantine-recovery-only:no-reinterpretation",
        ]
    }

    private static func admittedTairaBinding(
        currentChainId: String = tairaUUIDs.second
    ) throws -> TairaDeploymentBinding {
        return try XCTUnwrap(
            TairaDeploymentBinding.admitted(
                infoDictionary: tairaAdmissionInfo(
                    currentChainId: currentChainId
                )
            )
        )
    }

    private static func admittedTairaConfiguration(
        currentChainId: String = tairaUUIDs.second
    ) throws -> NexusNetworkConfiguration {
        NexusNetworkConfiguration.taira(
            deployment: try admittedTairaBinding(
                currentChainId: currentChainId
            )
        )
    }

    func testProductionWalletStorageIdentityRemainsBackwardCompatible() {
        XCTAssertEqual(
            UserStorageVersion.current.rawValue,
            UserStorageVersion.version2.rawValue
        )
        XCTAssertEqual(
            UserStorageParams.modelVersion.rawValue,
            UserStorageVersion.current.rawValue
        )
        XCTAssertEqual(UserStorageParams.databaseName, "UserDataModel.sqlite")
        XCTAssertEqual(
            UserStorageParams.storageURL.lastPathComponent,
            "UserDataModel.sqlite"
        )
        XCTAssertEqual(
            UserStorageParams.storageDirectoryURL.lastPathComponent,
            "CoreData"
        )
        switch UserStorageParams.incompatibleModelStrategy {
        case .ignore:
            break
        case .removeStore:
            XCTFail("The production wallet store must never be removed on incompatibility")
        @unknown default:
            XCTFail("The production wallet store uses an unreviewed incompatibility strategy")
        }

        let retainedAddress = "retained-production-wallet"
        XCTAssertEqual(KeystoreTag.pincode.rawValue, "pincode")
        XCTAssertEqual(KeystoreTag.legacyEntropy.rawValue, "seedEntropy")
        XCTAssertEqual(KeystoreTag.legacyUsername.rawValue, "userName")
        XCTAssertEqual(
            KeystoreTag.secretKeyTagForAddress(retainedAddress),
            "retained-production-wallet-secretKey"
        )
        XCTAssertEqual(
            KeystoreTag.entropyTagForAddress(retainedAddress),
            "retained-production-wallet-entropy"
        )
        XCTAssertEqual(
            KeystoreTag.deriviationTagForAddress(retainedAddress),
            "retained-production-wallet-deriv"
        )
        XCTAssertEqual(
            KeystoreTag.seedTagForAddress(retainedAddress),
            "retained-production-wallet-seed"
        )
    }

    func testProductionKeychainAccessibilityRemainsWhenUnlockedThisDeviceOnly()
        throws
    {
        XCTAssertEqual(
            Keychain.accessibility,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
    }

    func testDurableFileWriterPreservesProtectionAndPermissions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("journal.json")
        try Data("legacy".utf8).write(to: target)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o640)],
            ofItemAtPath: target.path
        )
        try FileProtectionMetadata.setProtectionClass(
            .completeUntilFirstUserAuthentication,
            at: target,
            fileManager: .default
        )
        let protectionBefore = try FileProtectionMetadata.protectionClass(
            at: target,
            fileManager: .default
        )
        #if !targetEnvironment(simulator)
            let attributesBefore = try FileManager.default.attributesOfItem(
                atPath: target.path
            )
            XCTAssertEqual(
                try XCTUnwrap(
                    FileProtectionMetadata.normalized(
                        attributesBefore[.protectionKey]
                    )
                ),
                protectionBefore
            )
        #endif
        XCTAssertEqual(
            protectionBefore,
            FileProtectionType.completeUntilFirstUserAuthentication
        )

        let replacement = Data("durable replacement".utf8)
        try DurableFileWriter.write(
            replacement,
            to: target,
            fileManager: .default,
            protection: .complete
        )

        XCTAssertEqual(try Data(contentsOf: target), replacement)
        let attributesAfter = try FileManager.default.attributesOfItem(
            atPath: target.path
        )
        let permissions = try XCTUnwrap(
            attributesAfter[.posixPermissions] as? NSNumber
        )
        let protectionAfter = try FileProtectionMetadata.protectionClass(
            at: target,
            fileManager: .default
        )
        #if !targetEnvironment(simulator)
            XCTAssertEqual(
                try XCTUnwrap(
                    FileProtectionMetadata.normalized(
                        attributesAfter[.protectionKey]
                    )
                ),
                protectionAfter
            )
        #endif
        XCTAssertEqual(permissions.intValue & 0o7777, 0o640)
        XCTAssertEqual(protectionAfter, protectionBefore)
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                atPath: directory.path
            ).contains(where: { $0.hasPrefix(".durable-") })
        )

        let rollbackDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: rollbackDirectory,
            withIntermediateDirectories: false
        )
        defer {
            try? FileManager.default.removeItem(at: rollbackDirectory)
        }
        let rollbackTarget = rollbackDirectory.appendingPathComponent(
            "existing.json"
        )
        let rollbackLegacyData = Data("rollback legacy".utf8)
        try rollbackLegacyData.write(to: rollbackTarget)
        try FileProtectionMetadata.setProtectionClass(
            .completeUntilFirstUserAuthentication,
            at: rollbackTarget,
            fileManager: .default
        )
        var didWeakenExistingPublicationOnDisk = false
        XCTAssertThrowsError(
            try DurableFileWriter.write(
                Data("failed replacement".utf8),
                to: rollbackTarget,
                fileManager: .default,
                protection: .complete,
                afterAtomicPublication: { publishedURL in
                    try FileProtectionMetadata.setProtectionClass(
                        .none,
                        at: publishedURL,
                        fileManager: .default
                    )
                    guard
                        try FileProtectionMetadata.protectionClass(
                            at: publishedURL,
                            fileManager: .default
                        ) == FileProtectionType.none
                    else {
                        throw FileProtectionMetadata.Failure.unavailable
                    }
                    didWeakenExistingPublicationOnDisk = true
                }
            )
        )
        XCTAssertTrue(didWeakenExistingPublicationOnDisk)
        XCTAssertEqual(
            try Data(contentsOf: rollbackTarget),
            rollbackLegacyData
        )
        XCTAssertEqual(
            try FileProtectionMetadata.protectionClass(
                at: rollbackTarget,
                fileManager: .default
            ),
            FileProtectionType.completeUntilFirstUserAuthentication
        )
        let protectedRollbackResidue = try FileManager.default
            .contentsOfDirectory(
                at: rollbackDirectory,
                includingPropertiesForKeys: nil,
                options: []
            ).filter {
                $0.lastPathComponent.hasPrefix(".durable-")
            }
        XCTAssertEqual(protectedRollbackResidue.count, 1)
        for residue in protectedRollbackResidue {
            XCTAssertEqual(
                try FileProtectionMetadata.protectionClass(
                    at: residue,
                    fileManager: .default
                ),
                FileProtectionType.completeUntilFirstUserAuthentication
            )
        }

        let absentDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: absentDirectory,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: absentDirectory) }
        let absentTarget = absentDirectory.appendingPathComponent("new.json")
        var didWeakenAbsentPublicationOnDisk = false
        XCTAssertThrowsError(
            try DurableFileWriter.write(
                Data("failed new publication".utf8),
                to: absentTarget,
                fileManager: .default,
                protection: .complete,
                afterAtomicPublication: { publishedURL in
                    try FileProtectionMetadata.setProtectionClass(
                        .none,
                        at: publishedURL,
                        fileManager: .default
                    )
                    guard
                        try FileProtectionMetadata.protectionClass(
                            at: publishedURL,
                            fileManager: .default
                        ) == FileProtectionType.none
                    else {
                        throw FileProtectionMetadata.Failure.unavailable
                    }
                    didWeakenAbsentPublicationOnDisk = true
                }
            )
        )
        XCTAssertTrue(didWeakenAbsentPublicationOnDisk)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: absentTarget.path)
        )
        let protectedAbsentResidue = try FileManager.default
            .contentsOfDirectory(
                at: absentDirectory,
                includingPropertiesForKeys: nil,
                options: []
            ).filter {
                $0.lastPathComponent.hasPrefix(".durable-failed-")
            }
        XCTAssertEqual(protectedAbsentResidue.count, 1)
        for residue in protectedAbsentResidue {
            XCTAssertEqual(
                try FileProtectionMetadata.protectionClass(
                    at: residue,
                    fileManager: .default
                ),
                FileProtectionType.complete
            )
        }
    }

    func testDurableFileWriterRejectsSymlinkWithoutTouchingLegacyFile()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacy = directory.appendingPathComponent("legacy.json")
        let retained = Data("retained legacy evidence".utf8)
        try retained.write(to: legacy)
        let target = directory.appendingPathComponent("active.json")
        try FileManager.default.createSymbolicLink(
            at: target,
            withDestinationURL: legacy
        )

        XCTAssertThrowsError(
            try DurableFileWriter.write(
                Data("replacement".utf8),
                to: target,
                fileManager: .default,
                protection: .complete
            )
        ) { error in
            guard
                case DurableFileWriter.Failure.invalidTarget = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: legacy), retained)
        XCTAssertEqual(
            try FileManager.default.destinationOfSymbolicLink(
                atPath: target.path
            ),
            legacy.path
        )
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                atPath: directory.path
            ).contains(where: { $0.hasPrefix(".durable-") })
        )
    }

    func testMigrationOutcomeCodesNeverContainWalletIdentifiers() {
        let walletIdentifier = "cnPrivacySensitiveWalletIdentifier"
        let missingSecret = UserStorageMigrationError.missingWalletSecret(
            walletIdentifier
        )
        let backupFailure = UserStorageMigrationError.backupVerificationFailed(
            walletIdentifier
        )

        XCTAssertEqual(
            missingSecret.privacySafeOutcomeCode,
            "missing_wallet_secret"
        )
        XCTAssertEqual(
            backupFailure.privacySafeOutcomeCode,
            "backup_verification_failed"
        )
        XCTAssertFalse(
            missingSecret.privacySafeOutcomeCode.contains(walletIdentifier)
        )
        XCTAssertFalse(
            backupFailure.privacySafeOutcomeCode.contains(walletIdentifier)
        )
        XCTAssertFalse(
            UserStorageMigrationError
                .privacySafeRecoveryDescription(for: missingSecret)
                .contains(walletIdentifier)
        )
        XCTAssertFalse(
            UserStorageMigrationError
                .privacySafeRecoveryDescription(for: backupFailure)
                .contains(walletIdentifier)
        )
        XCTAssertEqual(
            UserStorageMigrationError.privacySafeOutcomeCode(
                for: NSError(
                    domain: walletIdentifier,
                    code: 1
                )
            ),
            "unexpected_failure"
        )
        XCTAssertEqual(
            UserStorageMigrationError.privacySafeRecoveryDescription(
                for: NSError(
                    domain: walletIdentifier,
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: walletIdentifier
                    ]
                )
            ),
            "Wallet storage could not be verified safely " +
                "(unexpected_failure). Existing wallet data and recovery " +
                "copies were preserved."
        )
    }

    func testWalletLifecycleCoordinatorRequiresOneActiveLease() throws {
        let coordinator = WalletLifecycleCoordinator.shared
        let first = try XCTUnwrap(coordinator.tryAcquire())
        defer { first.release() }

        XCTAssertNil(coordinator.tryAcquire())
        var suppliedLeaseBodyRan = false
        try coordinator.withExclusiveAccess(using: first) {
            suppliedLeaseBodyRan = true
            XCTAssertNil(coordinator.tryAcquire())
        }
        XCTAssertTrue(suppliedLeaseBodyRan)
        XCTAssertNil(coordinator.tryAcquire())

        first.release()
        XCTAssertThrowsError(
            try coordinator.withExclusiveAccess(using: first) {}
        ) { error in
            guard
                case WalletNetworkMigrationError
                    .lifecycleMutationBusy = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let replacement = try XCTUnwrap(coordinator.tryAcquire())
        replacement.release()
    }

    func testWalletLifecycleReleaseWaitsForBorrowedCriticalSection() throws {
        let coordinator = WalletLifecycleCoordinator.shared
        let lease = try XCTUnwrap(coordinator.tryAcquire())
        let entered = expectation(description: "borrow entered")
        let finished = expectation(description: "borrow finished")
        let allowFinish = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            defer { finished.fulfill() }
            do {
                try coordinator.withExclusiveAccess(using: lease) {
                    entered.fulfill()
                    allowFinish.wait()
                }
            } catch {
                XCTFail("Borrowed lifecycle body failed: \(error)")
            }
        }

        wait(for: [entered], timeout: 2)
        lease.release()
        XCTAssertNil(coordinator.tryAcquire())
        allowFinish.signal()
        wait(for: [finished], timeout: 2)

        let replacement = try XCTUnwrap(coordinator.tryAcquire())
        replacement.release()
    }

    func testCancelledLifecycleAcquireOperationDoesNotLeakLease() throws {
        let coordinator = WalletLifecycleCoordinator.shared
        let first = try XCTUnwrap(coordinator.tryAcquire())
        let acquisition = coordinator.makeAcquireOperation()
        let completed = expectation(description: "cancelled acquisition")
        acquisition.completionBlock = {
            completed.fulfill()
        }
        coordinator.enqueueOwnedAcquireOperation(acquisition)
        acquisition.cancel()
        let follower = coordinator.makeAcquireOperation()
        let followerCompleted = expectation(
            description: "follower acquired after cancellation"
        )
        follower.completionBlock = {
            followerCompleted.fulfill()
        }
        coordinator.enqueueOwnedAcquireOperation(follower)
        first.release()
        wait(
            for: [completed, followerCompleted],
            timeout: 2
        )

        XCTAssertThrowsError(
            try acquisition.extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )
        )
        let followerLease = try follower
            .extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )
        followerLease.release()
        let replacement = try XCTUnwrap(coordinator.tryAcquire())
        replacement.release()
    }

    func testLifecycleAcquisitionQueueDoesNotStarveSingleWorker() {
        let coordinator = WalletLifecycleCoordinator.shared
        let worker = OperationQueue()
        worker.maxConcurrentOperationCount = 1
        let completed = expectation(
            description: "all dependent lifecycle mutations"
        )
        completed.expectedFulfillmentCount = 16

        for _ in 0 ..< completed.expectedFulfillmentCount {
            let acquisition = coordinator.makeAcquireOperation()
            let mutation: BaseOperation<Void> = ClosureOperation {
                let lease = try acquisition
                    .extractResultData(
                        throwing: BaseOperationError.parentOperationCancelled
                    )
                defer { lease.release() }
                completed.fulfill()
            }
            mutation.addDependency(acquisition)
            coordinator.enqueueOwnedAcquireOperation(acquisition)
            worker.addOperation(mutation)
        }

        wait(for: [completed], timeout: 5)
    }

    func testPreparedSeedImportValidationDoesNotWriteKeychain() throws {
        let keychain = InMemoryKeychain()
        try keychain.addKey(
            Data([0x01]),
            with: "preexisting-wallet-marker"
        )
        let factory = AccountOperationFactory(keystore: keychain)
        let request = AccountImportSeedRequest(
            seed: String(repeating: "01", count: 32),
            username: "Pure validation",
            networkType: .sora,
            derivationPath: "",
            cryptoType: .sr25519
        )
        let operation = factory.prepareAccountOperation(request: request)
        OperationQueue().addOperations(
            [operation],
            waitUntilFinished: true
        )

        let prepared = try operation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        XCTAssertEqual(
            try keychain.allKeyIdentifiers(),
            ["preexisting-wallet-marker"]
        )
        prepared.discard()
        XCTAssertEqual(
            try keychain.allKeyIdentifiers(),
            ["preexisting-wallet-marker"]
        )
    }

    func testPreparedAccountRejectsMismatchedPrivateAndPublicMaterial()
        throws
    {
        let first = try SR25519KeypairFactory().createKeypairFromSeed(
            Data(repeating: 0x11, count: 32),
            chaincodeList: []
        )
        let second = try SR25519KeypairFactory().createKeypairFromSeed(
            Data(repeating: 0x22, count: 32),
            chaincodeList: []
        )
        let publicKey = first.publicKey().rawData()
        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: Chain.sora.addressType()
        )
        let account = AccountItem(
            address: address,
            cryptoType: .sr25519,
            networkType: Chain.sora.addressType(),
            username: "Mismatched",
            publicKeyData: publicKey,
            settings: AccountSettings(
                visibleAssetIds: [],
                orderedAssetIds: []
            ),
            order: 0,
            isSelected: true
        )

        XCTAssertThrowsError(
            try PreparedAccount(
                account: account,
                secretKey: second.privateKey().rawData(),
                entropy: nil,
                seed: nil,
                derivationPath: nil
            )
        ) { error in
            guard
                case WalletNetworkMigrationError.legacyIdentityMismatch =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    private let mnemonic12 =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private let mnemonic24 =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"

    func testSharedTwelveAndTwentyFourWordVectorsPreserveSora2Identity() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Fixtures/Modernization/wallet-derivation-v1.json"
            )
        let fixture = try JSONDecoder().decode(
            SharedWalletDerivationFixture.self,
            from: Data(contentsOf: fixtureURL)
        )
        XCTAssertEqual(fixture.format, "sora-mobile-wallet-derivation-v1")
        XCTAssertEqual(fixture.sora2.curve, "sr25519")
        XCTAssertEqual(fixture.sora2.ss58Prefix, 69)
        XCTAssertEqual(fixture.sora2.derivationVersion, 1)
        XCTAssertEqual(fixture.sora2.derivationPath, "")

        let vectors = fixture.vectors.compactMap { vector in
            vector.sora2.map { (vector, $0) }
        }
        XCTAssertEqual(
            Set(vectors.map { $0.0.name }),
            Set(["bip39-12-abandon", "fearless-default-24"])
        )

        for (vector, expected) in vectors {
            let mnemonic = try IRMnemonicCreator(language: .english)
                .mnemonic(fromList: vector.mnemonic)
            var directBip39Seed = try IRBIP39SeedCreator().deriveSeed(
                from: mnemonic.toString(),
                passphrase: ""
            )
            defer {
                directBip39Seed.resetBytes(
                    in: directBip39Seed.startIndex ..< directBip39Seed.endIndex
                )
            }
            XCTAssertEqual(
                Data(directBip39Seed.prefix(32)).hex,
                expected.directBip39Seed32Hex
            )
            var legacyMiniSeed = try SeedFactory()
                .deriveSeed(from: mnemonic.toString(), password: "")
                .seed
                .miniSeed
            defer {
                legacyMiniSeed.resetBytes(
                    in: legacyMiniSeed.startIndex ..< legacyMiniSeed.endIndex
                )
            }
            XCTAssertEqual(
                legacyMiniSeed.hex,
                expected.legacySora2MiniSeedHex
            )
            XCTAssertNotEqual(
                legacyMiniSeed.hex,
                expected.directBip39Seed32Hex,
                "The direct BIP39 seed must never replace the legacy SORA2 mini-seed"
            )
            let keypair = try SR25519KeypairFactory().createKeypairFromSeed(
                legacyMiniSeed,
                chaincodeList: []
            )
            XCTAssertEqual(
                keypair.publicKey().rawData().hex,
                expected.publicKeyHex
            )
            XCTAssertEqual(
                try SS58AddressFactory().address(
                    fromAccountId: keypair.publicKey().rawData(),
                    type: Chain.sora.addressType()
                ),
                expected.address
            )
        }

        let localizationRoot = fixtureURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SoraPassport/SoraLocalizable")
        let localizedFiles = try FileManager.default
            .contentsOfDirectory(
                at: localizationRoot,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "lproj" }
            .map { $0.appendingPathComponent("Localizable.strings") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        XCTAssertGreaterThan(localizedFiles.count, 20)

        func localizedValue(_ key: String, source: String) -> String? {
            let prefix = "\"\(key)\" = \""
            guard let start = source.range(of: prefix) else { return nil }
            let suffix = source[start.upperBound...]
            guard let end = suffix.range(of: "\";") else { return nil }
            return String(suffix[..<end.lowerBound])
        }

        for file in localizedFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            guard
                let commonValue = localizedValue(
                    "common.passphrase.body",
                    source: source
                ),
                let wordCountValue = localizedValue(
                    "access.restore.words.error.message",
                    source: source
                ),
                let phraseValue = localizedValue(
                    "access.restore.phrase.error.message",
                    source: source
                ),
                let exportValue = localizedValue(
                    "export.protection.passphrase.description",
                    source: source
                )
            else {
                XCTFail("Missing required wallet copy in \(file.path)")
                continue
            }
            XCTAssertTrue(commonValue.contains("24"), file.path)
            XCTAssertFalse(commonValue.contains("15"), file.path)
            XCTAssertTrue(wordCountValue.contains("12"), file.path)
            XCTAssertTrue(wordCountValue.contains("24"), file.path)
            XCTAssertFalse(wordCountValue.contains("15"), file.path)
            XCTAssertTrue(phraseValue.contains("12"), file.path)
            XCTAssertTrue(phraseValue.contains("24"), file.path)
            XCTAssertFalse(phraseValue.contains("15"), file.path)
            XCTAssertTrue(exportValue.contains("24"), file.path)
            XCTAssertFalse(exportValue.contains("12"), file.path)
        }
    }

    func testNexusDerivationRejectsInvalidMnemonicChecksum() {
        let invalid = Array(
            repeating: "abandon",
            count: 12
        ).joined(separator: " ")
        XCTAssertThrowsError(
            try NexusKeyDerivation.derive(
                mnemonic: invalid,
                configuration: .minamoto
            )
        ) { error in
            guard
                case WalletNetworkMigrationError.invalidMnemonic =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testTwelveWordNexusDerivationGoldenVectors() throws {
        let minamoto = try NexusKeyDerivation.derive(
            mnemonic: mnemonic12,
            configuration: .minamoto
        )
        XCTAssertEqual(
            minamoto.privateKey.hex,
            "37b9341a9c5b929033232530e8ecfa3aab48c288995b07c6c323e4b8d0ace9de"
        )
        XCTAssertEqual(
            minamoto.publicKey.hex,
            "8dea60946dd00558e61254c7aadeccabd1e39d5b9a12a45b678e22209f19426f"
        )
        XCTAssertEqual(
            minamoto.address,
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        )

        let taira = try NexusKeyDerivation.derive(
            mnemonic: mnemonic12,
            configuration: Self.admittedTairaConfiguration()
        )
        XCTAssertEqual(
            taira.privateKey.hex,
            "1c8892e7107b47862ec584fe774c3849d28c34c27b95c8a77465abbc6b1e56a7"
        )
        XCTAssertEqual(
            taira.publicKey.hex,
            "ebe2fe329305f8e4c19cc4b159bc6ddd413cf5831422bdb9b3b93ee5053bd4d3"
        )
        XCTAssertEqual(
            taira.address,
            "testuﾛ1Q1ﾘﾚxgﾁﾃﾀdRZﾀWｿfXLGﾜﾘPﾐﾉﾉkﾃ7ﾖｶBｹssﾙﾈjｷｹUNYWHP"
        )
    }

    func testTwentyFourWordNexusDerivationGoldenVectors() throws {
        let minamoto = try NexusKeyDerivation.derive(
            mnemonic: mnemonic24,
            configuration: .minamoto
        )
        XCTAssertEqual(
            minamoto.publicKey.hex,
            "2651a79b3da908fbdb63e0756e9be9561c6c4638120c3af0d444670cd088a138"
        )
        XCTAssertEqual(
            minamoto.address,
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        )

        let taira = try NexusKeyDerivation.derive(
            mnemonic: mnemonic24,
            configuration: Self.admittedTairaConfiguration()
        )
        XCTAssertEqual(
            taira.publicKey.hex,
            "6f14b7c26f99962837dfc13244188d9c4699f987b319b41949a898e6988d98a4"
        )
        XCTAssertEqual(
            taira.address,
            "testuﾛ1PDｵｾNｸkﾁoｹﾐyTW2Xiﾙo1yﾔｵhｷ7CﾃgｷｵｶkｶﾋWｴﾎn73BW7C"
        )
    }

    func testI105RejectsCrossNetworkAddress() throws {
        let address =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        XCTAssertNoThrow(
            try NexusNetworkConfiguration.minamoto.validate(address: address)
        )
        XCTAssertThrowsError(
            try Self.admittedTairaConfiguration().validate(address: address)
        )
    }

    func testTairaDeploymentAdmissionAcceptsEitherKnownCurrentMapping()
        throws
    {
        let first = try Self.admittedTairaBinding(
            currentChainId: Self.tairaUUIDs.first
        )
        let second = try Self.admittedTairaBinding(
            currentChainId: Self.tairaUUIDs.second
        )
        XCTAssertEqual(
            first.currentChainId.uuidString.lowercased(),
            Self.tairaUUIDs.first
        )
        XCTAssertEqual(
            first.retiredChainId.uuidString.lowercased(),
            Self.tairaUUIDs.second
        )
        XCTAssertEqual(
            second.currentChainId.uuidString.lowercased(),
            Self.tairaUUIDs.second
        )
        XCTAssertEqual(
            second.retiredChainId.uuidString.lowercased(),
            Self.tairaUUIDs.first
        )
        XCTAssertTrue(first.authorizesTransport(
            to: try XCTUnwrap(
                URL(string: "https://public-01.taira.example.org/v1/mcp")
            )
        ))
        XCTAssertFalse(first.authorizesTransport(
            to: try XCTUnwrap(
                URL(string: "https://taira.sora.org/v1/mcp")
            )
        ))
        XCTAssertEqual(
            NexusNetworkConfiguration.tairaRecovery(
                chainId: first.retiredChainId
            )?.chainId,
            first.retiredChainId
        )
        XCTAssertNotEqual(
            NexusNetworkConfiguration.taira(
                deployment: first
            ).chainId,
            first.retiredChainId
        )
        XCTAssertNil(TairaDeploymentBinding.admitted(
            infoDictionary: Self.tairaAdmissionInfo(
                currentDeploymentEpoch: "100",
                retiredDeploymentEpoch: "100"
            )
        ))
        XCTAssertNil(TairaDeploymentBinding.admitted(
            infoDictionary: Self.tairaAdmissionInfo(
                currentDeploymentEpoch: "99",
                retiredDeploymentEpoch: "100"
            )
        ))
        XCTAssertNil(TairaDeploymentBinding.admitted(
            infoDictionary: Self.tairaAdmissionInfo(
                currentDeploymentEpoch: "9007199254740992"
            )
        ))
    }

    func testSameUUIDLegacyTairaPendingRowRemainsRecoveryOnlyAcrossBothMappings()
        throws
    {
        let tairaAddress =
            "testuﾛ1Q1ﾘﾚxgﾁﾃﾀdRZﾀWｿfXLGﾜﾘPﾐﾉﾉkﾃ7ﾖｶBｹssﾙﾈjｷｹUNYWHP"
        for currentChainId in [
            Self.tairaUUIDs.first,
            Self.tairaUUIDs.second,
        ] {
            let binding = try Self.admittedTairaBinding(
                currentChainId: currentChainId
            )
            let configuration = NexusNetworkConfiguration.taira(
                deployment: binding
            )
            var retainedSchema77Row = NexusPendingTransaction(
                id: UUID(),
                idempotencyKey: UUID(),
                walletId: "retained-wallet",
                networkId: .taira,
                chainId: configuration.chainId,
                sender: tairaAddress,
                receiver: tairaAddress,
                assetDefinitionID: Self.nexusXorAssetDefinitionID,
                amount: try PIQuantity("1"),
                fee: try PIQuantity("0.1"),
                createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 2),
                hash: nil,
                state: .signing,
                terminalBlockHeight: nil,
                errorClass: nil,
                historyReconciledAt: nil
            )
            var legacyObject = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(retainedSchema77Row)
                ) as? [String: Any]
            )
            legacyObject.removeValue(forKey: "tairaDeployment")
            retainedSchema77Row = try JSONDecoder().decode(
                NexusPendingTransaction.self,
                from: JSONSerialization.data(withJSONObject: legacyObject)
            )
            XCTAssertNil(retainedSchema77Row.tairaDeployment)
            XCTAssertFalse(retainedSchema77Row.hasCurrentDeploymentIdentity(
                for: configuration,
                tairaBinding: binding
            ))
            XCTAssertNil(
                NexusPendingTairaDeploymentIdentity.admitted(
                    for: configuration,
                    deployment: nil
                )
            )
            retainedSchema77Row.tairaDeployment =
                NexusPendingTairaDeploymentIdentity.admitted(
                    for: configuration,
                    deployment: binding
                )
            XCTAssertTrue(retainedSchema77Row.hasCurrentDeploymentIdentity(
                for: configuration,
                tairaBinding: binding
            ))
            retainedSchema77Row.tairaDeployment =
                NexusPendingTairaDeploymentIdentity(
                    manifestSha256: binding.manifestSha256,
                    deploymentEpoch: binding.currentDeploymentEpoch,
                    genesisHash: String(repeating: "e", count: 64)
                )
            XCTAssertFalse(retainedSchema77Row.hasCurrentDeploymentIdentity(
                for: configuration,
                tairaBinding: binding
            ))
            retainedSchema77Row.tairaDeployment =
                NexusPendingTairaDeploymentIdentity(
                    manifestSha256: String(repeating: "f", count: 64),
                    deploymentEpoch: binding.currentDeploymentEpoch,
                    genesisHash: binding.currentGenesisHash
                )
            XCTAssertFalse(retainedSchema77Row.hasCurrentDeploymentIdentity(
                for: configuration,
                tairaBinding: binding
            ))
            retainedSchema77Row.tairaDeployment =
                NexusPendingTairaDeploymentIdentity(
                    manifestSha256: binding.manifestSha256,
                    deploymentEpoch: binding.currentDeploymentEpoch + 1,
                    genesisHash: binding.currentGenesisHash
                )
            XCTAssertFalse(retainedSchema77Row.hasCurrentDeploymentIdentity(
                for: configuration,
                tairaBinding: binding
            ))
        }
    }

    func testI105RejectsUnboundedInputBeforeBaseConversion() {
        let oversized = "sora" + String(repeating: "1", count: 509)
        XCTAssertThrowsError(
            try IrohaAddressCodec.parse(
                oversized,
                expectedDiscriminant:
                    NexusNetworkConfiguration.minamoto.i105Discriminant
            )
        )
    }

    func testNexusCommittedHistoryPreservesExactAmountAndNetworkScope() throws {
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let amount = "340282366920938463463374607431768211455"
        let hash = String(repeating: "a", count: 64)
        let result = try JSONDecoder().decode(
            NexusJSONValue.self,
            from: Data(
                """
                {
                  "body": {
                    "items": [{
                      "transaction_hash": "\(hash)",
                      "created_at": "2026-08-02T00:00:00Z",
                      "transaction_status": "Committed",
                      "box": {
                        "json": {
                          "payload": {
                            "variant": "Asset",
                            "value": {
                              "source": "\(Self.nexusXorAssetDefinitionID)#\(sender)",
                              "destination": "\(receiver)",
                              "object": "\(amount)"
                            }
                          }
                        }
                      }
                    }]
                  }
                }
                """.utf8
            )
        )

        let page = try NexusTransferHistoryParser.page(
            result: result,
            configuration: .minamoto,
            account: sender,
            assetDefinitionID: Self.nexusXorAssetDefinitionID
        )

        XCTAssertEqual(page.sourceItemCount, 1)
        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.amount.rawValue, amount)
        XCTAssertEqual(page.items.first?.transactionHash, hash)
        XCTAssertEqual(page.items.first?.sender, sender)
        XCTAssertEqual(page.items.first?.receiver, receiver)
        let exactAmount = try XCTUnwrap(NexusExactDecimal(amount))
        XCTAssertTrue(
            NexusCommittedHistoryReconciliation.matchesExactlyOne(
                history: page.items,
                transactionHash: hash,
                sender: sender,
                receiver: receiver,
                amount: exactAmount
            )
        )
        XCTAssertFalse(
            NexusCommittedHistoryReconciliation.matchesExactlyOne(
                history: page.items + page.items,
                transactionHash: hash,
                sender: sender,
                receiver: receiver,
                amount: exactAmount
            )
        )
        let conflictingTransfer = NexusTransferHistoryItem(
            transactionHash: hash,
            timestampMilliseconds: 1,
            amount: try PIQuantity("1"),
            sender: sender,
            receiver: receiver
        )
        XCTAssertFalse(
            NexusCommittedHistoryReconciliation.matchesExactlyOne(
                history: page.items + [conflictingTransfer],
                transactionHash: hash,
                sender: sender,
                receiver: receiver,
                amount: exactAmount
            ),
            "A conflicting XOR instruction under the signed hash was ignored"
        )
        let unrelatedTransfer = NexusTransferHistoryItem(
            transactionHash: String(repeating: "b", count: 64),
            timestampMilliseconds: 1,
            amount: try PIQuantity(amount),
            sender: sender,
            receiver: receiver
        )
        XCTAssertTrue(
            NexusCommittedHistoryReconciliation.matchesExactlyOne(
                history: page.items + [unrelatedTransfer],
                transactionHash: hash,
                sender: sender,
                receiver: receiver,
                amount: exactAmount
            )
        )
    }

    func testNexusCommittedHistoryRejectsExponentAndCrossNetworkAddress() throws {
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let tairaReceiver =
            "testuﾛ1Q1ﾘﾚxgﾁﾃﾀdRZﾀWｿfXLGﾜﾘPﾐﾉﾉkﾃ7ﾖｶBｹssﾙﾈjｷｹUNYWHP"
        let hash = String(repeating: "b", count: 64)
        func result(amount: String, receiver: String) throws -> NexusJSONValue {
            try JSONDecoder().decode(
                NexusJSONValue.self,
                from: Data(
                    """
                    {
                      "body": {
                        "items": [{
                          "transaction_hash": "\(hash)",
                          "created_at": "2026-08-02T00:00:00Z",
                          "transaction_status": "Committed",
                          "box": {
                            "json": {
                              "payload": {
                                "variant": "Asset",
                                "value": {
                                  "source": "\(Self.nexusXorAssetDefinitionID)#\(sender)",
                                  "destination": "\(receiver)",
                                  "object": "\(amount)"
                                }
                              }
                            }
                          }
                        }]
                      }
                    }
                    """.utf8
                )
            )
        }

        XCTAssertThrowsError(
            try NexusTransferHistoryParser.page(
                result: result(amount: "1e18", receiver: sender),
                configuration: .minamoto,
                account: sender,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )
        XCTAssertThrowsError(
            try NexusTransferHistoryParser.page(
                result: result(amount: "1", receiver: tairaReceiver),
                configuration: .minamoto,
                account: sender,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )
    }

    func testNexusCommittedHistoryRejectsMalformedOrConflictingSourceIdentity()
        throws {
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let hash = String(repeating: "c", count: 64)
        func result(
            source: String,
            explicitSource: String?
        ) throws -> NexusJSONValue {
            var transfer: [String: Any] = [
                "source": source,
                "destination": receiver,
                "object": "1",
            ]
            if let explicitSource {
                transfer["source_account"] = explicitSource
            }
            let envelope: [String: Any] = [
                "body": [
                    "items": [[
                        "transaction_hash": hash,
                        "created_at": "2026-08-02T00:00:00Z",
                        "transaction_status": "Committed",
                        "box": [
                            "json": [
                                "payload": [
                                    "variant": "Asset",
                                    "value": transfer,
                                ],
                            ],
                        ],
                    ]],
                ],
            ]
            return try JSONDecoder().decode(
                NexusJSONValue.self,
                from: JSONSerialization.data(withJSONObject: envelope)
            )
        }

        XCTAssertThrowsError(
            try NexusTransferHistoryParser.page(
                result: result(
                    source: "\(Self.nexusXorAssetDefinitionID)#junk#\(sender)",
                    explicitSource: nil
                ),
                configuration: .minamoto,
                account: sender,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )
        XCTAssertThrowsError(
            try NexusTransferHistoryParser.page(
                result: result(
                    source: "\(Self.nexusXorAssetDefinitionID)#\(sender)",
                    explicitSource: receiver
                ),
                configuration: .minamoto,
                account: sender,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )
    }

    func testNexusBatchHistoryRequiresExactXorDefinitionPerLeg() throws {
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let hash = String(repeating: "d", count: 64)
        func result(entries: [[String: Any]]) throws -> NexusJSONValue {
            let envelope: [String: Any] = [
                "body": [
                    "items": [[
                        "transaction_hash": hash,
                        "created_at": "2026-08-02T00:00:00Z",
                        "transaction_status": "Committed",
                        "box": [
                            "json": [
                                "payload": [
                                    "variant": "AssetBatch",
                                    "value": ["entries": entries],
                                ],
                            ],
                        ],
                    ]],
                ],
            ]
            return try JSONDecoder().decode(
                NexusJSONValue.self,
                from: JSONSerialization.data(withJSONObject: envelope)
            )
        }
        let xorLeg: [String: Any] = [
            "from": sender,
            "to": receiver,
            "asset_definition": Self.nexusXorAssetDefinitionID,
            "amount": "1",
        ]
        let otherLeg: [String: Any] = [
            "from": sender,
            "to": receiver,
            "asset_definition": "other#universal",
            "amount": "1",
        ]

        let mixed = try NexusTransferHistoryParser.page(
            result: result(entries: [xorLeg, otherLeg]),
            configuration: .minamoto,
            account: sender,
            assetDefinitionID: Self.nexusXorAssetDefinitionID
        )
        XCTAssertEqual(mixed.sourceItemCount, 1)
        XCTAssertEqual(mixed.items.count, 1)
        XCTAssertEqual(mixed.items.first?.amount.rawValue, "1")

        var missingDefinition = xorLeg
        missingDefinition.removeValue(forKey: "asset_definition")
        XCTAssertThrowsError(
            try NexusTransferHistoryParser.page(
                result: result(entries: [missingDefinition]),
                configuration: .minamoto,
                account: sender,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )
    }

    func testNexusPipelineStatusRequiresGlobalAuthoritativeResolution() throws {
        let hash = String(repeating: "ab", count: 32)
        func decode(
            kind: String = "committed",
            blockHeight: Int? = 1,
            scope: String,
            resolvedFrom: String
        ) throws -> NexusPipelineStatus {
            var status: [String: Any] = ["kind": kind]
            if let blockHeight {
                status["block_height"] = blockHeight
            }
            return try JSONDecoder().decode(
                NexusPipelineStatus.self,
                from: JSONSerialization.data(
                    withJSONObject: [
                        "hash": hash,
                        "status": status,
                        "scope": scope,
                        "resolved_from": resolvedFrom,
                    ]
                )
            )
        }

        XCTAssertTrue(
            try decode(
                scope: "global",
                resolvedFrom: "state"
            ).hasAuthoritativeGlobalResolution
        )
        XCTAssertFalse(
            try decode(
                scope: "auto",
                resolvedFrom: "state"
            ).hasAuthoritativeGlobalResolution
        )
        XCTAssertTrue(
            try decode(
                scope: "global",
                resolvedFrom: "queue"
            ).hasAuthoritativeGlobalResolution
        )
        for blockHeight in [nil, 0] as [Int?] {
            XCTAssertFalse(
                try decode(
                    blockHeight: blockHeight,
                    scope: "global",
                    resolvedFrom: "state"
                ).hasAuthoritativeGlobalResolution
            )
        }
        XCTAssertTrue(
            try decode(
                kind: "approved",
                blockHeight: nil,
                scope: "global",
                resolvedFrom: "cache"
            ).hasAuthoritativeGlobalResolution
        )
        XCTAssertFalse(
            try decode(
                scope: "global",
                resolvedFrom: " "
            ).hasAuthoritativeGlobalResolution
        )
        XCTAssertFalse(
            try decode(
                scope: "global",
                resolvedFrom: String(repeating: "a", count: 65)
            ).hasAuthoritativeGlobalResolution
        )
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                NexusPipelineStatus.self,
                from: Data(
                    """
                    {
                      "hash": "\(hash)",
                      "status": {"kind": "committed", "block_height": 1}
                    }
                    """.utf8
                )
            )
        )
    }

    func testNexusAppliedStatusRequiresStateAndPositiveBlock() throws {
        let hash = String(repeating: "ab", count: 32)
        func decode(
            blockHeight: Int?,
            resolvedFrom: String
        ) throws -> NexusPipelineStatus {
            var status: [String: Any] = ["kind": "Applied"]
            if let blockHeight {
                status["block_height"] = blockHeight
            }
            return try JSONDecoder().decode(
                NexusPipelineStatus.self,
                from: JSONSerialization.data(
                    withJSONObject: [
                        "hash": hash,
                        "status": status,
                        "scope": "global",
                        "resolved_from": resolvedFrom,
                    ]
                )
            )
        }

        XCTAssertTrue(
            try decode(
                blockHeight: 1,
                resolvedFrom: "state"
            ).hasAuthoritativeGlobalResolution
        )
        for resolvedFrom in ["queue", "cache"] {
            XCTAssertFalse(
                try decode(
                    blockHeight: 1,
                    resolvedFrom: resolvedFrom
                ).hasAuthoritativeGlobalResolution
            )
        }
        for blockHeight in [nil, 0] as [Int?] {
            XCTAssertFalse(
                try decode(
                    blockHeight: blockHeight,
                    resolvedFrom: "state"
                ).hasAuthoritativeGlobalResolution
            )
        }
    }

    func testNexusTerminalFailureRequiresStateResolution() throws {
        let hash = String(repeating: "ab", count: 32)
        func decode(
            kind: String,
            resolvedFrom: String
        ) throws -> NexusPipelineStatus {
            try JSONDecoder().decode(
                NexusPipelineStatus.self,
                from: JSONSerialization.data(
                    withJSONObject: [
                        "hash": hash,
                        "status": ["kind": kind],
                        "scope": "global",
                        "resolved_from": resolvedFrom,
                    ]
                )
            )
        }

        for kind in ["Rejected", "Expired"] {
            XCTAssertTrue(
                try decode(
                    kind: kind,
                    resolvedFrom: "state"
                ).hasAuthoritativeGlobalResolution
            )
            for resolvedFrom in ["queue", "cache"] {
                XCTAssertFalse(
                    try decode(
                        kind: kind,
                        resolvedFrom: resolvedFrom
                    ).hasAuthoritativeGlobalResolution
                )
            }
        }
    }

    func testGenericWireJSONRejectsLossyNumericTokens() throws {
        let unbounded = Data(
            "{\"amount\":340282366920938463463374607431768211455}".utf8
        )
        let fractional = Data("{\"amount\":0.1}".utf8)
        XCTAssertThrowsError(
            try JSONDecoder().decode(PIJSONValue.self, from: unbounded)
        )
        XCTAssertThrowsError(
            try JSONDecoder().decode(PIJSONValue.self, from: fractional)
        )
        XCTAssertThrowsError(
            try JSONDecoder().decode(NexusJSONValue.self, from: unbounded)
        )
        XCTAssertThrowsError(
            try JSONDecoder().decode(NexusJSONValue.self, from: fractional)
        )

        let exactString = Data(
            "{\"amount\":\"340282366920938463463374607431768211455\"}".utf8
        )
        XCTAssertNoThrow(
            try JSONDecoder().decode(PIJSONValue.self, from: exactString)
        )
        XCTAssertNoThrow(
            try JSONDecoder().decode(NexusJSONValue.self, from: exactString)
        )

        let exactIntegerMetadata = Data(
            "{\"marketId\":7,\"era\":9223372036854775807}".utf8
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                PIJSONValue.self,
                from: exactIntegerMetadata
            ),
            .object([
                "marketId": .number("7"),
                "era": .number("9223372036854775807"),
            ])
        )
    }

    func testPIHistorySchemaFixturePreservesExactIntegerMetadata() throws {
        let transactionHash = "0x" + String(repeating: "ab", count: 32)
        let blockHash = "0x" + String(repeating: "cd", count: 32)
        let fixture = Data(
            """
            {
              "id": "\(transactionHash)",
              "type": "CALL",
              "timestamp": 1720000000,
              "blockHash": "\(blockHash)",
              "blockHeight": 123,
              "module": "polkamarkt",
              "method": "claim",
              "address": "cnAccount",
              "execution": {"success": true, "era": 987},
              "data": {"marketId": 42, "claimedMarkets": [1, 2, 3]},
              "calls": {
                "nodes": [
                  {"module": "polkamarkt", "method": "claim", "data": {"requestedMarkets": [42]}}
                ]
              }
            }
            """.utf8
        )

        let element = try JSONDecoder().decode(
            PIHistoryElement.self,
            from: fixture
        )
        XCTAssertEqual(
            element.data,
            .object([
                "marketId": .number("42"),
                "claimedMarkets": .array([
                    .number("1"), .number("2"), .number("3"),
                ]),
            ])
        )
        XCTAssertEqual(
            element.calls?.nodes.first?.data,
            .object([
                "requestedMarkets": .array([.number("42")]),
            ])
        )
    }

    func testPIHistoryAmountMappingRejectsMalformedOrNegativeValues() {
        XCTAssertNoThrow(
            try HistoryTransactionMapper.validatedAmount(
                "999999999999999999999999999999"
            )
        )
        XCTAssertNoThrow(
            try HistoryTransactionMapper.validatedAmount("0.000000000000000001")
        )
        XCTAssertNoThrow(
            try HistoryTransactionMapper.validatedAmount(
                "340282366920938463463374607431768211455"
            )
        )
        for invalid in [
            "",
            "01",
            "-1",
            "1e3",
            "NaN",
            "1.",
            "340282366920938463463374607431768211456",
        ] {
            XCTAssertThrowsError(
                try HistoryTransactionMapper.validatedAmount(invalid),
                "Accepted invalid history amount: \(invalid)"
            )
        }
        XCTAssertNoThrow(try HistoryTransactionMapper.validatedFee("1"))
        for invalidFee in ["", "01", "-1", "0.1", "1e3"] {
            XCTAssertThrowsError(
                try HistoryTransactionMapper.validatedFee(invalidFee),
                "Accepted invalid history fee: \(invalidFee)"
            )
        }
    }

    func testNexusTransactionHashRequiresExactOptionalPrefixAnd32Bytes() {
        let lower = String(repeating: "ab", count: 32)
        let upper = lower.uppercased()
        XCTAssertEqual(NexusTransactionHash.normalized(lower), lower)
        XCTAssertEqual(NexusTransactionHash.normalized("0x\(upper)"), lower)
        XCTAssertEqual(NexusTransactionHash.normalized("0X\(upper)"), lower)
        XCTAssertNil(
            NexusTransactionHash.normalized(
                "0x\(String(repeating: "0", count: 20))0x\(String(repeating: "0", count: 42))"
            )
        )
        XCTAssertNil(
            NexusTransactionHash.normalized(String(repeating: "a", count: 62))
        )
        XCTAssertNil(
            NexusTransactionHash.normalized(String(repeating: "g", count: 64))
        )
        XCTAssertNil(
            NexusTransactionHash.normalized(String(repeating: "0", count: 64))
        )
        XCTAssertNil(NexusTransactionHash.normalized(" \(lower)"))
    }

    func testNexusSubmissionReceiptBindsEveryHashAndPosition() throws {
        let hash = String(repeating: "ab", count: 32)
        let receipt = NexusTransactionReceipt(
            payload: .init(
                txHash: "0x\(hash.uppercased())",
                entrypointHash: hash,
                signedTransactionHash: hash,
                submittedAtMs: 1,
                submittedAtHeight: 2
            )
        )
        XCTAssertNoThrow(try receipt.validate(expectedHash: hash))

        let mismatchedSignedHash = NexusTransactionReceipt(
            payload: .init(
                txHash: hash,
                entrypointHash: hash,
                signedTransactionHash: String(repeating: "cd", count: 32),
                submittedAtMs: 1,
                submittedAtHeight: 2
            )
        )
        XCTAssertThrowsError(
            try mismatchedSignedHash.validate(expectedHash: hash)
        ) { error in
            guard case NexusToriiError.transactionHashMismatch = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let mismatchedEntrypointHash = NexusTransactionReceipt(
            payload: .init(
                txHash: hash,
                entrypointHash: String(repeating: "cd", count: 32),
                signedTransactionHash: hash,
                submittedAtMs: 1,
                submittedAtHeight: 2
            )
        )
        XCTAssertThrowsError(
            try mismatchedEntrypointHash.validate(expectedHash: hash)
        ) { error in
            guard case NexusToriiError.transactionHashMismatch = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let invalidPosition = NexusTransactionReceipt(
            payload: .init(
                txHash: hash,
                entrypointHash: hash,
                signedTransactionHash: nil,
                submittedAtMs: 0,
                submittedAtHeight: 2
            )
        )
        XCTAssertThrowsError(
            try invalidPosition.validate(expectedHash: hash)
        ) { error in
            guard case NexusToriiError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testNexusPreparedTransferCanBeSubmittedOnlyOnce() throws {
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let amount = try PIQuantity("1")
        let fee = try PIQuantity("0.01")
        let request = NexusTransferRequest(
            walletId: "wallet",
            networkId: .minamoto,
            sender: sender,
            receiver: receiver,
            amount: amount
        )
        let prepared = NexusPreparedTransfer(
            request: request,
            canonicalReceiver: receiver,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            availableBalance: try PIQuantity("2"),
            quote: NexusTransferFeeQuote(
                networkId: .minamoto,
                authority: sender,
                receiver: receiver,
                assetDefinitionId: Self.nexusXorAssetDefinitionID,
                amount: amount,
                fee: fee,
                quoteIdentity: "reviewed-quote",
                validUntilBlock: 100
            )
        )

        XCTAssertTrue(prepared.reserveSubmission())
        XCTAssertFalse(prepared.reserveSubmission())
    }

    func testNexusRecoveryNeverInterruptsALiveSubmission() throws {
        XCTAssertTrue(
            NexusPendingRecoveryPolicy
                .shouldFailAsInterruptedPreSubmission(
                    state: .signing,
                    hash: nil,
                    ownedByLiveSubmission: false
                )
        )
        XCTAssertFalse(
            NexusPendingRecoveryPolicy
                .shouldFailAsInterruptedPreSubmission(
                    state: .signing,
                    hash: nil,
                    ownedByLiveSubmission: true
                )
        )
        XCTAssertFalse(
            NexusPendingRecoveryPolicy
                .shouldFailAsInterruptedPreSubmission(
                    state: .signing,
                    hash: String(repeating: "a", count: 64),
                    ownedByLiveSubmission: false
                )
        )
        let recoveryClient: NexusToriiReading = NexusToriiReadClient()
        let submissionClient: NexusToriiSubmitting =
            NexusToriiSubmissionClient()
        let unavailableFinality: NexusFinalityReading =
            UnavailableNexusFinalityReader()
        XCTAssertFalse(recoveryClient is NexusToriiSubmitting)
        XCTAssertFalse(submissionClient is NexusToriiReading)
        XCTAssertFalse(
            unavailableFinality.isQualified(for: .minamoto)
        )

        let minamotoCheckpoint = NexusFinalityCheckpoint(
            networkId: .minamoto,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            finalizedBlockHeight: 42,
            finalizedBlockHash: String(repeating: "ab", count: 32)
        )
        XCTAssertEqual(
            try minamotoCheckpoint.requireHeight(for: .minamoto),
            42
        )
        XCTAssertThrowsError(
            try minamotoCheckpoint.requireHeight(
                for: Self.admittedTairaConfiguration()
            )
        )
        XCTAssertThrowsError(
            try NexusFinalityCheckpoint(
                networkId: .minamoto,
                chainId: NexusNetworkConfiguration.minamoto.chainId,
                finalizedBlockHeight: 0,
                finalizedBlockHash: String(repeating: "ab", count: 32)
            ).requireHeight(for: .minamoto)
        )
        XCTAssertThrowsError(
            try NexusFinalityCheckpoint(
                networkId: .minamoto,
                chainId: NexusNetworkConfiguration.minamoto.chainId,
                finalizedBlockHeight: 42,
                finalizedBlockHash: "0x" +
                    String(repeating: "ab", count: 32)
            ).requireHeight(for: .minamoto)
        )
        XCTAssertThrowsError(
            try NexusFinalityCheckpoint(
                networkId: .minamoto,
                chainId: NexusNetworkConfiguration.minamoto.chainId,
                finalizedBlockHeight: 42,
                finalizedBlockHash: String(repeating: "AB", count: 32)
            ).requireHeight(for: .minamoto)
        )
        XCTAssertThrowsError(
            try NexusFinalityCheckpoint(
                networkId: .minamoto,
                chainId: NexusNetworkConfiguration.minamoto.chainId,
                finalizedBlockHeight: 42,
                finalizedBlockHash: String(repeating: "0", count: 64)
            ).requireHeight(for: .minamoto)
        )
        XCTAssertThrowsError(
            try NexusFinalityCheckpoint(
                networkId: .minamoto,
                chainId: NexusNetworkConfiguration.minamoto.chainId,
                finalizedBlockHeight: 42,
                finalizedBlockHash: "hash:" +
                    String(repeating: "AB", count: 32) + "#0000"
            ).requireHeight(for: .minamoto)
        )
        XCTAssertThrowsError(
            try NexusFinalityCheckpoint(
                networkId: .taira,
                chainId: UUID(
                    uuidString:
                        "809574f5-fee7-5e69-bfcf-52451e42d50f"
                )!,
                finalizedBlockHeight: 42,
                finalizedBlockHash: String(repeating: "ab", count: 32)
            ).requireHeight(for: Self.admittedTairaConfiguration())
        )

        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let nexusSource = try String(
            contentsOf: sourceRoot.appendingPathComponent(
                "SoraPassport/Common/Model/NexusWalletService.swift"
            ),
            encoding: .utf8
        )
        let recoveryStart = try XCTUnwrap(
            nexusSource.range(
                of: "    func resumePending() async throws"
            )
        )
        let recoveryEnd = try XCTUnwrap(
            nexusSource.range(
                of: "@MainActor\nfinal class NexusTransactionRuntime",
                range: recoveryStart.upperBound ..< nexusSource.endIndex
            )
        )
        let recoverySource = nexusSource[
            recoveryStart.lowerBound ..< recoveryEnd.lowerBound
        ]
        XCTAssertTrue(recoverySource.contains("readClient.status("))
        XCTAssertTrue(
            recoverySource.contains("finalizedCheckpoint(for: configuration)")
        )
        XCTAssertTrue(
            recoverySource.contains(".requireHeight(for: configuration)")
        )
        XCTAssertFalse(recoverySource.contains("submissionClient"))
        XCTAssertFalse(recoverySource.contains("NexusToriiSubmitting"))
        XCTAssertFalse(recoverySource.contains(".submit("))
        XCTAssertFalse(recoverySource.contains("signer."))
        XCTAssertTrue(
            nexusSource.contains(
                "quote.validUntilBlock.map({ $0 > 0 }) ?? true"
            )
        )
        XCTAssertTrue(nexusSource.contains("fee.unscaled > 0"))
    }

    func testNexusAmountScaleMatchesNoritoUnsignedByteContract() throws {
        let maximum = try PIQuantity(
            "0." + String(repeating: "1", count: 255)
        )
        let oversized = try PIQuantity(
            "0." + String(repeating: "1", count: 256)
        )
        let zero = try PIQuantity("0")

        XCTAssertTrue(NexusAmountPolicy.accepts(maximum))
        XCTAssertFalse(NexusAmountPolicy.accepts(oversized))
        XCTAssertFalse(NexusAmountPolicy.accepts(zero))
        XCTAssertTrue(
            NexusAmountPolicy.accepts(zero, allowingZero: true)
        )
    }

    func testNexusBalanceBindsExactAccountAndUniqueGlobalAsset()
        throws
    {
        let account =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        func response(
            accountID: String,
            itemCount: Int = 1,
            assetDefinitionID: String? = nil
        ) throws -> NexusAccountAssetList {
            let assetDefinitionID = assetDefinitionID ??
                Self.nexusXorAssetDefinitionID
            let item: [String: Any] = [
                "account_id": accountID,
                "asset": assetDefinitionID,
                "asset_id": assetDefinitionID,
                "asset_name": "xor",
                "asset_alias": "xor#universal",
                "quantity": "2.000000000000000001",
                "scope": "global",
            ]
            let envelope: [String: Any] = [
                "items": Array(repeating: item, count: itemCount),
                "has_more": false,
                "count_mode": "exact",
                "total": itemCount,
            ]
            return try JSONDecoder().decode(
                NexusAccountAssetList.self,
                from: JSONSerialization.data(
                    withJSONObject: envelope
                )
            )
        }

        XCTAssertEqual(
            try NexusBalanceValidator.xorBalance(
                in: response(accountID: account),
                account: account,
                configuration: .minamoto,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            ).rawValue,
            "2.000000000000000001"
        )
        XCTAssertThrowsError(
            try NexusBalanceValidator.xorBalance(
                in: response(
                    accountID:
                        "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
                ),
                account: account,
                configuration: .minamoto,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )
        let reboundMetadataEnvelope: [String: Any] = [
            "items": [[
                "account_id": account,
                "asset": Self.nexusXorAssetDefinitionID,
                "asset_id": Self.nexusXorAssetDefinitionID,
                "asset_name": "renamed-after-submission",
                "quantity": "2.000000000000000001",
                "scope": "global",
            ]],
            "has_more": false,
            "count_mode": "exact",
            "total": 1,
        ]
        let reboundMetadata = try JSONDecoder().decode(
            NexusAccountAssetList.self,
            from: JSONSerialization.data(
                withJSONObject: reboundMetadataEnvelope
            )
        )
        XCTAssertThrowsError(
            try NexusBalanceValidator.xorBalance(
                in: reboundMetadata,
                account: account,
                configuration: .minamoto,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )
        XCTAssertEqual(
            try NexusBalanceValidator.exactAssetBalance(
                in: reboundMetadata,
                account: account,
                configuration: .minamoto,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            ).rawValue,
            "2.000000000000000001"
        )
        XCTAssertThrowsError(
            try NexusBalanceValidator.xorBalance(
                in: response(accountID: account, itemCount: 2),
                account: account,
                configuration: .minamoto,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )
        XCTAssertThrowsError(
            try NexusBalanceValidator.xorBalance(
                in: response(
                    accountID: account,
                    assetDefinitionID: "61CtjvNd9T3THAR65GsMVHr82Bjc"
                ),
                account: account,
                configuration: .minamoto,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )
        let missingAccountEnvelope: [String: Any] = [
            "items": [[
                "asset": Self.nexusXorAssetDefinitionID,
                "asset_id": Self.nexusXorAssetDefinitionID,
                "asset_name": "xor",
                "asset_alias": "xor#universal",
                "quantity": "1",
                "scope": "global",
            ]],
            "has_more": false,
            "count_mode": "exact",
            "total": 1,
        ]
        let missingAccount = try JSONDecoder().decode(
            NexusAccountAssetList.self,
            from: JSONSerialization.data(
                withJSONObject: missingAccountEnvelope
            )
        )
        XCTAssertThrowsError(
            try NexusBalanceValidator.xorBalance(
                in: missingAccount,
                account: account,
                configuration: .minamoto,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )
        let missingAuthoritativeAssetEnvelope: [String: Any] = [
            "items": [[
                "account_id": account,
                "asset_id": Self.nexusXorAssetDefinitionID,
                "asset_name": "xor",
                "asset_alias": "xor#universal",
                "quantity": "1",
                "scope": "global",
            ]],
            "has_more": false,
            "count_mode": "exact",
            "total": 1,
        ]
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                NexusAccountAssetList.self,
                from: JSONSerialization.data(
                    withJSONObject: missingAuthoritativeAssetEnvelope
                )
            )
        )
        var missingExactMetadataEnvelope = reboundMetadataEnvelope
        missingExactMetadataEnvelope.removeValue(forKey: "count_mode")
        missingExactMetadataEnvelope.removeValue(forKey: "total")
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                NexusAccountAssetList.self,
                from: JSONSerialization.data(
                    withJSONObject: missingExactMetadataEnvelope
                )
            )
        )
        var mixedCaseExactMetadataEnvelope = reboundMetadataEnvelope
        mixedCaseExactMetadataEnvelope["count_mode"] = "Exact"
        let mixedCaseExactMetadata = try JSONDecoder().decode(
            NexusAccountAssetList.self,
            from: JSONSerialization.data(
                withJSONObject: mixedCaseExactMetadataEnvelope
            )
        )
        XCTAssertThrowsError(
            try NexusBalanceValidator.exactAssetBalance(
                in: mixedCaseExactMetadata,
                account: account,
                configuration: .minamoto,
                assetDefinitionID: Self.nexusXorAssetDefinitionID
            )
        )

        XCTAssertTrue(
            NexusAssetDefinitionIdentity.hasCanonicalWireShape(
                Self.nexusXorAssetDefinitionID
            )
        )
        XCTAssertFalse(
            NexusAssetDefinitionIdentity.hasCanonicalWireShape(
                "xor#universal"
            )
        )
        XCTAssertNoThrow(
            try NexusAssetDefinitionIdentity.validateXor(
                NexusAssetDefinition(
                    id: Self.nexusXorAssetDefinitionID,
                    name: "xor",
                    alias: "xor#universal",
                    aliasBinding: NexusAssetDefinition.AliasBinding(
                        alias: "xor#universal",
                        status: "permanent",
                        leaseExpiryMilliseconds: nil,
                        graceUntilMilliseconds: nil,
                        boundAtMilliseconds: 0
                    )
                )
            )
        )
        XCTAssertThrowsError(
            try NexusAssetDefinitionIdentity.validateXor(
                NexusAssetDefinition(
                    id: Self.nexusXorAssetDefinitionID,
                    name: "xor",
                    alias: "xor#sora",
                    aliasBinding: NexusAssetDefinition.AliasBinding(
                        alias: "xor#sora",
                        status: "permanent",
                        leaseExpiryMilliseconds: nil,
                        graceUntilMilliseconds: nil,
                        boundAtMilliseconds: 0
                    )
                )
            )
        )
        XCTAssertThrowsError(
            try NexusAssetDefinitionIdentity.validateXor(
                NexusAssetDefinition(
                    id: Self.nexusXorAssetDefinitionID,
                    name: "xor",
                    alias: "xor#universal",
                    aliasBinding: NexusAssetDefinition.AliasBinding(
                        alias: "xor#universal",
                        status: "leased_grace",
                        leaseExpiryMilliseconds: 1,
                        graceUntilMilliseconds: 2,
                        boundAtMilliseconds: 0
                    )
                )
            )
        )
    }

    func testNexusPendingJournalUsesCrashDurableProtectedPublication()
        async throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let store = try NexusPendingTransactionStore(baseURL: directory)
        let pending = NexusPendingTransaction(
            id: UUID(),
            idempotencyKey: UUID(),
            walletId: "legacy-sora-wallet",
            networkId: .minamoto,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            sender: sender,
            receiver: receiver,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            amount: try PIQuantity("1"),
            fee: try PIQuantity("0.01"),
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            hash: String(repeating: "ab", count: 32),
            state: .submitting,
            terminalBlockHeight: nil,
            errorClass: nil,
            historyReconciledAt: nil
        )

        _ = try await store.put(pending)
        try await store.requireCurrentChainMutationAdmission()

        let journalDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
        let journal = journalDirectory.appendingPathComponent(
            "nexus-v1.json"
        )
        let values = try journal.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        XCTAssertEqual(values.isRegularFile, true)
        XCTAssertNotEqual(values.isSymbolicLink, true)
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                atPath: journalDirectory.path
            ).contains(where: { $0.hasPrefix(".durable-") })
        )
        let reloaded = try await store.all()
        XCTAssertEqual(reloaded, [pending])
        XCTAssertEqual(
            reloaded.first?.assetDefinitionID,
            Self.nexusXorAssetDefinitionID
        )
        let rebound = NexusPendingTransaction(
            id: pending.id,
            idempotencyKey: pending.idempotencyKey,
            walletId: pending.walletId,
            networkId: pending.networkId,
            chainId: pending.chainId,
            sender: pending.sender,
            receiver: pending.receiver,
            assetDefinitionID: "61CtjvNd9T3THAR65GsMVHr82Bjc",
            amount: pending.amount,
            fee: pending.fee,
            createdAt: pending.createdAt,
            updatedAt: Date(timeIntervalSince1970: 2),
            hash: pending.hash,
            state: pending.state,
            terminalBlockHeight: pending.terminalBlockHeight,
            errorClass: pending.errorClass,
            historyReconciledAt: pending.historyReconciledAt
        )
        do {
            _ = try await store.put(rebound)
            XCTFail("A pending send changed its canonical asset identity")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }

        // Journals from the preceding format do not contain a chain UUID or
        // assetDefinitionID. They remain decodable and byte-retained, but
        // recovery performs no network I/O under today's chain or alias.
        var legacyRows = try XCTUnwrap(
            try JSONSerialization.jsonObject(
                with: Data(contentsOf: journal)
            ) as? [[String: Any]]
        )
        legacyRows[0].removeValue(forKey: "assetDefinitionID")
        legacyRows[0].removeValue(forKey: "chainId")
        let legacyDecoder = JSONDecoder()
        legacyDecoder.dateDecodingStrategy = .iso8601
        let legacy = try legacyDecoder.decode(
            [NexusPendingTransaction].self,
            from: JSONSerialization.data(withJSONObject: legacyRows)
        )
        XCTAssertNil(legacy.first?.assetDefinitionID)
        XCTAssertNil(legacy.first?.chainId)
        XCTAssertEqual(legacy.first?.id, pending.id)

        let legacyData = try JSONSerialization.data(
            withJSONObject: legacyRows
        )
        try legacyData.write(to: journal, options: .atomic)
        let legacyCoordinator = NexusTransactionCoordinator(
            pendingStore: store
        )
        let unresolvedLegacy = try await legacyCoordinator.resumePending()
        XCTAssertEqual(unresolvedLegacy, legacy)
        XCTAssertNil(unresolvedLegacy.first?.assetDefinitionID)
        XCTAssertNil(unresolvedLegacy.first?.chainId)
        XCTAssertEqual(unresolvedLegacy.first?.state, .submitting)
        do {
            try await store.requireCurrentChainMutationAdmission()
            XCTFail("Legacy-unbound evidence admitted a new Nexus mutation")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }

        legacyRows[0]["assetDefinitionID"] = NSNull()
        let explicitNull = try legacyDecoder.decode(
            [NexusPendingTransaction].self,
            from: JSONSerialization.data(withJSONObject: legacyRows)
        )
        XCTAssertNil(explicitNull.first?.assetDefinitionID)

        legacyRows[0]["assetDefinitionID"] =
            Self.nexusXorAssetDefinitionID
        legacyRows[0]["chainId"] =
            "809574f5-fee7-5e69-bfcf-52451e42d50f"
        try JSONSerialization.data(withJSONObject: legacyRows).write(
            to: journal,
            options: .atomic
        )
        let retiredChainEvidence = try await store.all()
        XCTAssertEqual(
            retiredChainEvidence.first?.chainId,
            UUID(uuidString: "809574f5-fee7-5e69-bfcf-52451e42d50f")
        )
        let unresolvedRetiredChain = try await legacyCoordinator
            .resumePending()
        XCTAssertEqual(unresolvedRetiredChain, retiredChainEvidence)
        do {
            try await store.requireCurrentChainMutationAdmission()
            XCTFail("Retired-chain evidence admitted a new Nexus mutation")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }
        let currentChainInsertion = NexusPendingTransaction(
            id: UUID(),
            idempotencyKey: UUID(),
            walletId: pending.walletId,
            networkId: pending.networkId,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            sender: pending.sender,
            receiver: pending.receiver,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            amount: pending.amount,
            fee: pending.fee,
            createdAt: Date(timeIntervalSince1970: 3),
            updatedAt: Date(timeIntervalSince1970: 3),
            hash: nil,
            state: .signing,
            terminalBlockHeight: nil,
            errorClass: nil,
            historyReconciledAt: nil
        )
        do {
            _ = try await store.put(currentChainInsertion)
            XCTFail("A new current-chain send bypassed retired-chain evidence")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }
        do {
            _ = try await store.put(try XCTUnwrap(retiredChainEvidence.first))
            XCTFail("Retired-chain evidence was accepted for mutation")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }

        var currentChainRow = legacyRows[0]
        currentChainRow["id"] =
            "00000000-0000-0000-0000-000000000071"
        currentChainRow["idempotencyKey"] =
            "00000000-0000-0000-0000-000000000072"
        currentChainRow["chainId"] =
            NexusNetworkConfiguration.minamoto.chainId.uuidString
        try JSONSerialization.data(
            withJSONObject: [legacyRows[0], currentChainRow]
        ).write(to: journal, options: .atomic)
        let crossChainEvidence = try await store.all()
        XCTAssertEqual(crossChainEvidence.count, 2)
        do {
            try await store.requireCurrentChainMutationAdmission()
            XCTFail("Mixed current/retired evidence admitted a mutation")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }

        var unboundRow = legacyRows[0]
        unboundRow.removeValue(forKey: "chainId")
        try JSONSerialization.data(
            withJSONObject: [unboundRow, currentChainRow]
        ).write(to: journal, options: .atomic)
        do {
            _ = try await store.all()
            XCTFail("Unbound and current-chain duplicate hashes were accepted")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }

        legacyRows[0].removeValue(forKey: "chainId")
        legacyRows[0]["assetDefinitionID"] = "xor#universal"
        try JSONSerialization.data(withJSONObject: legacyRows).write(
            to: journal,
            options: .atomic
        )
        do {
            _ = try await store.all()
            XCTFail("A noncanonical pending asset identity was accepted")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }
    }

    func testPendingTransactionStoresRejectInterruptedDurablePublicationEvidence()
        async throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let nexusStore = try NexusPendingTransactionStore(
            baseURL: directory
        )
        let polkamarktStore = try PolkamarktPendingStore(
            baseURL: directory
        )
        let journalDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(
                "PendingTransactions",
                isDirectory: true
            )
        let interruptedPublication = journalDirectory
            .appendingPathComponent(
                ".durable-00000000-0000-0000-0000-000000000000.tmp"
            )
        try Data("unresolved publication evidence".utf8).write(
            to: interruptedPublication
        )

        do {
            _ = try await nexusStore.all()
            XCTFail(
                "Nexus deletion preflight accepted an interrupted journal publication"
            )
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }
        do {
            _ = try await polkamarktStore.all()
            XCTFail(
                "Polkamarkt deletion preflight accepted an interrupted journal publication"
            )
        } catch {
            guard case PolkamarktRuntimeError.unavailable = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testAllPendingTransactionJournalsShareTheProtectedNamespace()
        async throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let nexusStore = try NexusPendingTransactionStore(
            baseURL: directory
        )
        let polkamarktStore = try PolkamarktPendingStore(
            baseURL: directory
        )
        let sora2Store = try Sora2PendingSubmissionStore(
            baseURL: directory
        )
        _ = try sora2Store.stage(
            account: "sora-account",
            hash: String(repeating: "ab", count: 32)
        )

        let nexusTransactions = try await nexusStore.all()
        let polkamarktTransactions = try await polkamarktStore.all()
        XCTAssertTrue(nexusTransactions.isEmpty)
        XCTAssertTrue(polkamarktTransactions.isEmpty)
        XCTAssertEqual(try sora2Store.all().count, 1)
    }

    func testWalletDeletionPreflightBlocksEveryUnresolvedMutation()
        throws
    {
        let walletId = "legacy-sora-wallet"
        let soraAddress = "cnVwcml2YXRl"
        let createdAt = Date(timeIntervalSince1970: 1)
        func nexus(
            state: NexusPendingState,
            walletId candidateWalletId: String? = nil,
            historyReconciledAt: Date? = nil
        ) throws -> NexusPendingTransaction {
            NexusPendingTransaction(
                id: UUID(),
                idempotencyKey: UUID(),
                walletId: candidateWalletId ?? walletId,
                networkId: .minamoto,
                chainId: NexusNetworkConfiguration.minamoto.chainId,
                sender: "sender",
                receiver: "receiver",
                assetDefinitionID: Self.nexusXorAssetDefinitionID,
                amount: try PIQuantity("1"),
                fee: try PIQuantity("0.01"),
                createdAt: createdAt,
                updatedAt: createdAt,
                hash: state == .signing
                    ? nil
                    : String(repeating: "ab", count: 32),
                state: state,
                terminalBlockHeight: state == .committed ? 1 : nil,
                errorClass: nil,
                historyReconciledAt: historyReconciledAt
            )
        }
        func polkamarkt(
            state: PolkamarktPendingState,
            account candidateAccount: String? = nil
        ) -> PolkamarktPendingMutation {
            PolkamarktPendingMutation(
                id: UUID(),
                account: candidateAccount ?? soraAddress,
                action: "buy_yes",
                marketIds: [1],
                createdAt: createdAt,
                updatedAt: createdAt,
                extrinsicHash: state == .preparing
                    ? nil
                    : String(repeating: "cd", count: 32),
                state: state,
                finalizedBlock: state == .finalized ? 1 : nil,
                errorClass: nil
            )
        }

        let unresolvedNexusStates: [NexusPendingState] = [
            .signing,
            .submitting,
            .submissionUnknown,
            .submitted,
            .approved,
            .committedPendingReconciliation
        ]
        for state in unresolvedNexusStates {
            XCTAssertThrowsError(
                try WalletPendingDeletionPolicy.validate(
                    nexusTransactions: [try nexus(state: state)],
                    polkamarktTransactions: [],
                    walletId: walletId,
                    soraAddress: soraAddress
                ),
                "Nexus state \(state.rawValue) did not block deletion"
            ) { error in
                XCTAssertEqual(
                    error as? WalletPendingDeletionPreflightError,
                    .unresolvedNexusTransaction
                )
            }
        }

        // A record written before historyReconciledAt was introduced decodes
        // this field as nil. It remains unresolved even though committed is a
        // terminal transport state.
        XCTAssertThrowsError(
            try WalletPendingDeletionPolicy.validate(
                nexusTransactions: [try nexus(state: .committed)],
                polkamarktTransactions: [],
                walletId: walletId,
                soraAddress: soraAddress
            )
        ) { error in
            XCTAssertEqual(
                error as? WalletPendingDeletionPreflightError,
                .unresolvedNexusTransaction
            )
        }
        let unresolvedPolkamarktStates: [PolkamarktPendingState] = [
            .preparing,
            .signedBeforeTransport,
            .submitting,
            .submissionUnknown,
            .submitted
        ]
        for state in unresolvedPolkamarktStates {
            XCTAssertThrowsError(
                try WalletPendingDeletionPolicy.validate(
                    nexusTransactions: [],
                    polkamarktTransactions: [polkamarkt(state: state)],
                    walletId: walletId,
                    soraAddress: soraAddress
                ),
                "Polkamarkt state \(state.rawValue) did not block deletion"
            ) { error in
                XCTAssertEqual(
                    error as? WalletPendingDeletionPreflightError,
                    .unresolvedPolkamarktTransaction
                )
            }
        }

        let resolvedNexusStates: [NexusPendingState] = [
            .failedBeforeSubmission,
            .rejected,
            .expired
        ]
        for state in resolvedNexusStates {
            XCTAssertNoThrow(
                try WalletPendingDeletionPolicy.validate(
                    nexusTransactions: [try nexus(state: state)],
                    polkamarktTransactions: [],
                    walletId: walletId,
                    soraAddress: soraAddress
                )
            )
        }
        XCTAssertNoThrow(
            try WalletPendingDeletionPolicy.validate(
                nexusTransactions: [
                    try nexus(
                        state: .committed,
                        historyReconciledAt: createdAt
                    )
                ],
                polkamarktTransactions: [],
                walletId: walletId,
                soraAddress: soraAddress
            )
        )

        var unresolvedSora2 = Sora2PendingSubmission(
            id: UUID(),
            account: soraAddress,
            extrinsicHash: String(repeating: "ef", count: 32),
            createdAt: createdAt,
            updatedAt: createdAt,
            state: .stagedBeforeTransport
        )
        for state in [
            Sora2PendingSubmissionState.stagedBeforeTransport,
            .submitting,
            .submittedRetained,
            .submissionUnknown,
        ] {
            unresolvedSora2.state = state
            XCTAssertThrowsError(
                try WalletPendingDeletionPolicy.validate(
                    nexusTransactions: [],
                    polkamarktTransactions: [],
                    sora2Submissions: [unresolvedSora2],
                    walletId: walletId,
                    soraAddress: soraAddress
                ),
                "SORA2 state \(state.rawValue) did not block deletion"
            ) { error in
                XCTAssertEqual(
                    error as? WalletPendingDeletionPreflightError,
                    .unresolvedSora2Submission
                )
            }
        }
        var acceptedSora2 = unresolvedSora2
        acceptedSora2.state = .submitted
        XCTAssertNoThrow(
            try WalletPendingDeletionPolicy.validate(
                nexusTransactions: [],
                polkamarktTransactions: [],
                sora2Submissions: [acceptedSora2],
                walletId: walletId,
                soraAddress: soraAddress
            )
        )

        let resolvedPolkamarktStates: [PolkamarktPendingState] = [
            .failedBeforeSubmission,
            .finalized,
            .rejected
        ]
        for state in resolvedPolkamarktStates {
            XCTAssertNoThrow(
                try WalletPendingDeletionPolicy.validate(
                    nexusTransactions: [],
                    polkamarktTransactions: [polkamarkt(state: state)],
                    walletId: walletId,
                    soraAddress: soraAddress
                )
            )
        }

        // Pending work belonging to another wallet/account cannot block this
        // explicit deletion.
        XCTAssertNoThrow(
            try WalletPendingDeletionPolicy.validate(
                nexusTransactions: [
                    try nexus(
                        state: .submitting,
                        walletId: "another-wallet"
                    )
                ],
                polkamarktTransactions: [
                    polkamarkt(
                        state: .submitted,
                        account: "another-account"
                    )
                ],
                walletId: walletId,
                soraAddress: soraAddress
            )
        )
    }

    func testNexusPendingJournalRejectsSymbolicLink() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try NexusPendingTransactionStore(baseURL: directory)
        let decoy = directory.appendingPathComponent("decoy.json")
        try Data("[]".utf8).write(to: decoy)
        let journal = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
            .appendingPathComponent("nexus-v1.json")
        try FileManager.default.createSymbolicLink(
            at: journal,
            withDestinationURL: decoy
        )

        do {
            _ = try await store.all()
            XCTFail("A symbolic-link Nexus journal was accepted")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }
        XCTAssertEqual(try Data(contentsOf: decoy), Data("[]".utf8))
    }

    func testNexusPendingJournalRejectsInvalidSubmittedHash() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        _ = try NexusPendingTransactionStore(baseURL: directory)
        let pending = NexusPendingTransaction(
            id: UUID(),
            idempotencyKey: UUID(),
            walletId: "legacy-sora-wallet",
            networkId: .minamoto,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            sender: sender,
            receiver: receiver,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            amount: try PIQuantity("1"),
            fee: try PIQuantity("0.01"),
            createdAt: Date(),
            updatedAt: Date(),
            hash: "0x\(String(repeating: "0", count: 20))0x\(String(repeating: "0", count: 42))",
            state: .submitted,
            terminalBlockHeight: nil,
            errorClass: nil,
            historyReconciledAt: nil
        )
        let fileURL = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
            .appendingPathComponent("nexus-v1.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([pending]).write(to: fileURL, options: .atomic)
        let store = try NexusPendingTransactionStore(baseURL: directory)

        do {
            _ = try await store.all()
            XCTFail("Invalid persisted transaction hash was accepted")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }
    }

    func testNexusPendingJournalRejectsDuplicateTransactionHash() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let store = try NexusPendingTransactionStore(baseURL: directory)
        let hash = String(repeating: "ab", count: 32)
        func pending() throws -> NexusPendingTransaction {
            NexusPendingTransaction(
                id: UUID(),
                idempotencyKey: UUID(),
                walletId: "legacy-sora-wallet",
                networkId: .minamoto,
                chainId: NexusNetworkConfiguration.minamoto.chainId,
                sender: sender,
                receiver: receiver,
                assetDefinitionID: Self.nexusXorAssetDefinitionID,
                amount: try PIQuantity("1"),
                fee: try PIQuantity("0.01"),
                createdAt: Date(),
                updatedAt: Date(),
                hash: hash,
                state: .submitted,
                terminalBlockHeight: nil,
                errorClass: nil,
                historyReconciledAt: nil
            )
        }

        try await store.put(try pending())
        do {
            try await store.put(try pending())
            XCTFail("Duplicate Nexus transaction hash was accepted")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }
    }

    func testNexusPendingJournalRejectsStateAndTimestampContradictions()
        async throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let store = try NexusPendingTransactionStore(baseURL: directory)
        let createdAt = Date(timeIntervalSince1970: 20)
        let updatedAt = Date(timeIntervalSince1970: 30)

        let impossibleSigningHeight = NexusPendingTransaction(
            id: UUID(),
            idempotencyKey: UUID(),
            walletId: "legacy-sora-wallet",
            networkId: .minamoto,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            sender: sender,
            receiver: receiver,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            amount: try PIQuantity("1"),
            fee: try PIQuantity("0.01"),
            createdAt: createdAt,
            updatedAt: updatedAt,
            hash: nil,
            state: .signing,
            terminalBlockHeight: 1,
            errorClass: nil,
            historyReconciledAt: nil
        )
        do {
            _ = try await store.put(impossibleSigningHeight)
            XCTFail("A pre-submission transaction retained a block height")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }

        let impossibleReconciliationTime = NexusPendingTransaction(
            id: UUID(),
            idempotencyKey: UUID(),
            walletId: "legacy-sora-wallet",
            networkId: .minamoto,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            sender: sender,
            receiver: receiver,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            amount: try PIQuantity("1"),
            fee: try PIQuantity("0.01"),
            createdAt: createdAt,
            updatedAt: updatedAt,
            hash: String(repeating: "ab", count: 32),
            state: .committed,
            terminalBlockHeight: 1,
            errorClass: nil,
            historyReconciledAt: Date(timeIntervalSince1970: 10)
        )
        do {
            _ = try await store.put(impossibleReconciliationTime)
            XCTFail("A reconciliation timestamp predating the send was accepted")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }

        var nonPositivePendingCommit = impossibleReconciliationTime
        nonPositivePendingCommit.state = .committedPendingReconciliation
        nonPositivePendingCommit.terminalBlockHeight = 0
        nonPositivePendingCommit.historyReconciledAt = nil
        do {
            _ = try await store.put(nonPositivePendingCommit)
            XCTFail("A new pending commit accepted a zero block height")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }

        var nonPositiveReconciledCommit = impossibleReconciliationTime
        nonPositiveReconciledCommit.terminalBlockHeight = 0
        nonPositiveReconciledCommit.historyReconciledAt = updatedAt
        do {
            _ = try await store.put(nonPositiveReconciledCommit)
            XCTFail("A reconciled commit accepted a zero block height")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }

        let missingAssetReconciliation = NexusPendingTransaction(
            id: UUID(),
            idempotencyKey: UUID(),
            walletId: "legacy-sora-wallet",
            networkId: .minamoto,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            sender: sender,
            receiver: receiver,
            assetDefinitionID: nil,
            amount: try PIQuantity("1"),
            fee: try PIQuantity("0.01"),
            createdAt: createdAt,
            updatedAt: updatedAt,
            hash: String(repeating: "cd", count: 32),
            state: .committed,
            terminalBlockHeight: 1,
            errorClass: nil,
            historyReconciledAt: updatedAt
        )
        do {
            _ = try await store.put(missingAssetReconciliation)
            XCTFail("A reconciled commit omitted its exact asset identity")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }
    }

    func testNexusStagedSendCanFailDefinitivelyBeforeTransport() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let store = try NexusPendingTransactionStore(baseURL: directory)
        let createdAt = Date(timeIntervalSince1970: 10)
        var transaction = NexusPendingTransaction(
            id: UUID(),
            idempotencyKey: UUID(),
            walletId: "legacy-sora-wallet",
            networkId: .minamoto,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            sender: sender,
            receiver: receiver,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            amount: try PIQuantity("1"),
            fee: try PIQuantity("0.01"),
            createdAt: createdAt,
            updatedAt: createdAt,
            hash: nil,
            state: .signing,
            terminalBlockHeight: nil,
            errorClass: nil,
            historyReconciledAt: nil
        )
        do {
            transaction = try await store.put(transaction)
        } catch {
            XCTFail("Signing journal write failed: \(error)")
            throw error
        }

        transaction.hash = String(repeating: "ab", count: 32)
        transaction.state = .submitting
        transaction.updatedAt = Date(timeIntervalSince1970: 11)
        do {
            transaction = try await store.put(transaction)
        } catch {
            XCTFail("Submitting journal write failed: \(error)")
            throw error
        }

        transaction.state = .failedBeforeSubmission
        transaction.updatedAt = Date(timeIntervalSince1970: 12)
        transaction.errorClass = "wallet_identity_changed"
        let failed: NexusPendingTransaction
        do {
            failed = try await store.put(transaction)
        } catch {
            XCTFail("Pre-transport terminal journal write failed: \(error)")
            throw error
        }

        XCTAssertEqual(failed.state, .failedBeforeSubmission)
        XCTAssertEqual(failed.hash, String(repeating: "ab", count: 32))
        let reloaded = try await store.all()
        XCTAssertEqual(reloaded, [failed])
    }

    func testNexusPendingJournalPreservesTerminalReconciliation()
        async throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let store = try NexusPendingTransactionStore(
            baseURL: directory
        )
        let id = UUID()
        let idempotencyKey = UUID()
        let createdAt = Date(timeIntervalSince1970: 10)
        let reconciledAt = Date(timeIntervalSince1970: 20)
        let committed = NexusPendingTransaction(
            id: id,
            idempotencyKey: idempotencyKey,
            walletId: "wallet",
            networkId: .minamoto,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            sender: sender,
            receiver: receiver,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            amount: try PIQuantity("1"),
            fee: try PIQuantity("0.01"),
            createdAt: createdAt,
            updatedAt: reconciledAt,
            hash: String(repeating: "ab", count: 32),
            state: .committed,
            terminalBlockHeight: 42,
            errorClass: nil,
            historyReconciledAt: reconciledAt
        )
        XCTAssertFalse(committed.requiresCommittedHistoryReconciliation)
        var legacyUnreconciled = committed
        legacyUnreconciled.historyReconciledAt = nil
        XCTAssertTrue(
            legacyUnreconciled.requiresCommittedHistoryReconciliation
        )
        _ = try await store.put(committed)

        var stale = committed
        stale.updatedAt = Date(timeIntervalSince1970: 30)
        stale.historyReconciledAt = nil
        let retained = try await store.put(stale)

        XCTAssertEqual(retained.historyReconciledAt, reconciledAt)
        XCTAssertEqual(retained.terminalBlockHeight, 42)
        let reloaded = try await store.all()
        XCTAssertEqual(
            reloaded.first?.historyReconciledAt,
            reconciledAt
        )

        let legacyZeroHeight = NexusPendingTransaction(
            id: UUID(),
            idempotencyKey: UUID(),
            walletId: "wallet",
            networkId: .minamoto,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            sender: sender,
            receiver: receiver,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            amount: try PIQuantity("1"),
            fee: try PIQuantity("0.1"),
            createdAt: createdAt,
            updatedAt: createdAt,
            hash: String(repeating: "cd", count: 32),
            state: .committed,
            terminalBlockHeight: 0,
            errorClass: nil,
            historyReconciledAt: nil
        )
        _ = try await store.put(legacyZeroHeight)
        var promoted = legacyZeroHeight
        promoted.updatedAt = Date(timeIntervalSince1970: 30)
        promoted.terminalBlockHeight = 43
        promoted.historyReconciledAt = Date(timeIntervalSince1970: 30)
        let promotedResult = try await store.put(promoted)
        XCTAssertEqual(promotedResult.terminalBlockHeight, 43)
        XCTAssertEqual(
            promotedResult.historyReconciledAt,
            Date(timeIntervalSince1970: 30)
        )
    }

    func testNexusPendingJournalNeverEvictsUnreconciledCommit() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let sender =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let receiver =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let now = Date()
        let retained = try (0 ..< 500).map { index in
            NexusPendingTransaction(
                id: UUID(),
                idempotencyKey: UUID(),
                walletId: "legacy-sora-wallet",
                networkId: .minamoto,
                chainId: NexusNetworkConfiguration.minamoto.chainId,
                sender: sender,
                receiver: receiver,
                assetDefinitionID: Self.nexusXorAssetDefinitionID,
                amount: try PIQuantity("1"),
                fee: try PIQuantity("0.01"),
                createdAt: now,
                updatedAt: now,
                hash: String(format: "%064x", index + 1),
                state: .committed,
                terminalBlockHeight: 1,
                errorClass: nil,
                historyReconciledAt: nil
            )
        }
        _ = try NexusPendingTransactionStore(baseURL: directory)
        let fileURL = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
            .appendingPathComponent("nexus-v1.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(retained).write(to: fileURL, options: .atomic)
        let store = try NexusPendingTransactionStore(baseURL: directory)
        let incoming = NexusPendingTransaction(
            id: UUID(),
            idempotencyKey: UUID(),
            walletId: "legacy-sora-wallet",
            networkId: .minamoto,
            chainId: NexusNetworkConfiguration.minamoto.chainId,
            sender: sender,
            receiver: receiver,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            amount: try PIQuantity("1"),
            fee: try PIQuantity("0.01"),
            createdAt: now,
            updatedAt: now,
            hash: nil,
            state: .signing,
            terminalBlockHeight: nil,
            errorClass: nil,
            historyReconciledAt: nil
        )

        do {
            try await store.put(incoming)
            XCTFail("An unreconciled committed send was evicted")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }
        let preserved = try await store.all()
        XCTAssertEqual(preserved.count, retained.count)

        let retiredChain = UUID(
            uuidString: "809574f5-fee7-5e69-bfcf-52451e42d50f"
        )!
        let historicalTerminal = retained.map { transaction in
            NexusPendingTransaction(
                id: transaction.id,
                idempotencyKey: transaction.idempotencyKey,
                walletId: transaction.walletId,
                networkId: transaction.networkId,
                chainId: retiredChain,
                sender: transaction.sender,
                receiver: transaction.receiver,
                assetDefinitionID: transaction.assetDefinitionID,
                amount: transaction.amount,
                fee: transaction.fee,
                createdAt: transaction.createdAt,
                updatedAt: transaction.updatedAt,
                hash: transaction.hash,
                state: .rejected,
                terminalBlockHeight: nil,
                errorClass: "retired_chain_evidence",
                historyReconciledAt: nil
            )
        }
        try encoder.encode(historicalTerminal).write(
            to: fileURL,
            options: .atomic
        )
        do {
            try await store.put(incoming)
            XCTFail("Retired-chain evidence was silently evicted")
        } catch {
            XCTAssertTrue(error is NexusToriiError)
        }
        let preservedHistoricalTerminal = try await store.all()
        XCTAssertEqual(
            preservedHistoricalTerminal.count,
            historicalTerminal.count
        )
    }

    func testWalletNetworkStoreIsCopyOnWriteAndExplicitDeletionOnly() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let account = NetworkAccount(
            walletId: "legacy-sora-address",
            networkId: .sora2,
            derivationVersion: 0,
            publicKey: Data(repeating: 7, count: 32),
            address: "legacy-sora-address"
        )
        let snapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: account.walletId,
            wallets: [
                WalletIdentity(
                    id: account.walletId,
                    displayName: "Existing",
                    existingSoraAddress: account.address,
                    secretSource: .rawSeed
                )
            ],
            accounts: [account],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        try store.stageAndActivate(snapshot)
        XCTAssertEqual(try store.load(), snapshot)

        try store.recordExplicitRemoval(
            walletId: account.walletId,
            expectedWalletIds: [account.walletId],
            selectedWalletId: account.walletId
        )
        let afterRemoval = try XCTUnwrap(store.load())
        XCTAssertTrue(afterRemoval.wallets.isEmpty)
        XCTAssertTrue(afterRemoval.accounts.isEmpty)
        XCTAssertNil(afterRemoval.selectedWalletId)
    }

    func testWalletNetworkStoreGenericActivationCannotRemoveOrRewriteIdentity()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let wallet = WalletIdentity(
            id: "retained-wallet",
            displayName: "Retained",
            existingSoraAddress: "retained-wallet",
            secretSource: .rawSeed
        )
        let account = NetworkAccount(
            walletId: wallet.id,
            networkId: .sora2,
            derivationVersion: 0,
            publicKey: Data(repeating: 7, count: 32),
            address: wallet.existingSoraAddress
        )
        let original = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: wallet.id,
            wallets: [wallet],
            accounts: [account],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        try store.stageAndActivate(original)

        let proposals = [
            WalletNetworkSnapshot(
                schemaVersion:
                    WalletNetworkSnapshot.currentSchemaVersion,
                selectedWalletId: nil,
                wallets: [],
                accounts: [],
                createdAt: Date(timeIntervalSince1970: 2)
            ),
            WalletNetworkSnapshot(
                schemaVersion:
                    WalletNetworkSnapshot.currentSchemaVersion,
                selectedWalletId: wallet.id,
                wallets: [
                    WalletIdentity(
                        id: wallet.id,
                        displayName: wallet.displayName,
                        existingSoraAddress:
                            wallet.existingSoraAddress,
                        secretSource: .watchOnly
                    )
                ],
                accounts: [account],
                createdAt: Date(timeIntervalSince1970: 3)
            ),
            WalletNetworkSnapshot(
                schemaVersion:
                    WalletNetworkSnapshot.currentSchemaVersion,
                selectedWalletId: wallet.id,
                wallets: [wallet],
                accounts: [
                    NetworkAccount(
                        walletId: account.walletId,
                        networkId: account.networkId,
                        derivationVersion:
                            account.derivationVersion,
                        publicKey: Data(repeating: 8, count: 32),
                        address: account.address
                    )
                ],
                createdAt: Date(timeIntervalSince1970: 4)
            ),
        ]

        for proposal in proposals {
            XCTAssertThrowsError(
                try store.stageAndActivate(proposal)
            ) { error in
                guard
                    case WalletNetworkMigrationError
                        .snapshotVerificationFailed = error
                else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
            XCTAssertEqual(try store.load(), original)
        }

        let addedWallet = WalletIdentity(
            id: "new-wallet",
            displayName: "New",
            existingSoraAddress: "new-wallet",
            secretSource: .watchOnly
        )
        let addedAccount = NetworkAccount(
            walletId: addedWallet.id,
            networkId: .sora2,
            derivationVersion: 0,
            publicKey: Data(repeating: 9, count: 32),
            address: addedWallet.existingSoraAddress
        )
        let appended = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: addedWallet.id,
            wallets: [wallet, addedWallet],
            accounts: [account, addedAccount],
            createdAt: Date(timeIntervalSince1970: 5)
        )
        try store.stageAndActivate(appended)
        XCTAssertEqual(try store.load(), appended)
    }

    func testWalletNetworkStoreExplicitRemovalFailsClosedWithoutActiveTarget() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)

        XCTAssertThrowsError(
            try store.recordExplicitRemoval(
                walletId: "missing-wallet",
                expectedWalletIds: ["missing-wallet"],
                selectedWalletId: "missing-wallet"
            )
        ) { error in
            guard case WalletNetworkMigrationError.missingSnapshot = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let account = NetworkAccount(
            walletId: "retained-wallet",
            networkId: .sora2,
            derivationVersion: 0,
            publicKey: Data(repeating: 7, count: 32),
            address: "retained-wallet"
        )
        let snapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: account.walletId,
            wallets: [
                WalletIdentity(
                    id: account.walletId,
                    displayName: "Retained",
                    existingSoraAddress: account.address,
                    secretSource: .watchOnly
                )
            ],
            accounts: [account],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        try store.stageAndActivate(snapshot)

        XCTAssertThrowsError(
            try store.recordExplicitRemoval(
                walletId: "missing-wallet",
                expectedWalletIds: [account.walletId],
                selectedWalletId: account.walletId
            )
        ) { error in
            guard
                case WalletNetworkMigrationError
                    .explicitRemovalTargetMissing = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertThrowsError(
            try store.recordExplicitRemoval(
                walletId: account.walletId,
                expectedWalletIds: [
                    account.walletId,
                    "database-only-wallet"
                ],
                selectedWalletId: account.walletId
            )
        ) { error in
            guard
                case WalletNetworkMigrationError
                    .explicitRemovalInventoryMismatch = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertThrowsError(
            try store.recordExplicitRemoval(
                walletId: account.walletId,
                expectedWalletIds: [account.walletId],
                selectedWalletId: nil
            )
        ) { error in
            guard
                case WalletNetworkMigrationError
                    .explicitRemovalSelectionMismatch = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try store.load(), snapshot)
    }

    func testWalletNetworkStoreExplicitRemovalSelectsRetainedWallet() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let firstAccount = NetworkAccount(
            walletId: "first-wallet",
            networkId: .sora2,
            derivationVersion: 0,
            publicKey: Data(repeating: 7, count: 32),
            address: "first-wallet"
        )
        let secondAccount = NetworkAccount(
            walletId: "second-wallet",
            networkId: .sora2,
            derivationVersion: 0,
            publicKey: Data(repeating: 8, count: 32),
            address: "second-wallet"
        )
        try store.stageAndActivate(
            WalletNetworkSnapshot(
                schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
                selectedWalletId: firstAccount.walletId,
                wallets: [
                    WalletIdentity(
                        id: firstAccount.walletId,
                        displayName: "First",
                        existingSoraAddress: firstAccount.address,
                        secretSource: .watchOnly
                    ),
                    WalletIdentity(
                        id: secondAccount.walletId,
                        displayName: "Second",
                        existingSoraAddress: secondAccount.address,
                        secretSource: .watchOnly
                    )
                ],
                accounts: [firstAccount, secondAccount],
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )

        let afterRemoval = try store.recordExplicitRemoval(
            walletId: firstAccount.walletId,
            expectedWalletIds: [
                firstAccount.walletId,
                secondAccount.walletId
            ],
            selectedWalletId: firstAccount.walletId
        )
        XCTAssertEqual(afterRemoval.selectedWalletId, secondAccount.walletId)
        XCTAssertEqual(afterRemoval.wallets.map(\.id), [secondAccount.walletId])
        XCTAssertEqual(
            afterRemoval.accounts.map(\.walletId),
            [secondAccount.walletId]
        )
        XCTAssertEqual(try store.load(), afterRemoval)
    }

    func testWalletNetworkStoreRejectsStructurallyInvalidSnapshots() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let identity = WalletIdentity(
            id: "legacy-sora-address",
            displayName: "Existing",
            existingSoraAddress: "legacy-sora-address",
            secretSource: .watchOnly
        )
        let soraAccount = NetworkAccount(
            walletId: identity.id,
            networkId: .sora2,
            derivationVersion: 0,
            publicKey: Data(repeating: 7, count: 32),
            address: identity.existingSoraAddress
        )

        XCTAssertThrowsError(
            try store.stageAndActivate(
                WalletNetworkSnapshot(
                    schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
                    selectedWalletId: "unknown-wallet",
                    wallets: [identity],
                    accounts: [soraAccount],
                    createdAt: Date(timeIntervalSince1970: 1)
                )
            )
        )
        XCTAssertNil(try store.load())

        XCTAssertThrowsError(
            try store.stageAndActivate(
                WalletNetworkSnapshot(
                    schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
                    selectedWalletId: nil,
                    wallets: [identity],
                    accounts: [soraAccount],
                    createdAt: Date(timeIntervalSince1970: 2)
                )
            )
        )
        XCTAssertNil(try store.load())

        let orphan = NetworkAccount(
            walletId: "missing-wallet",
            networkId: .minamoto,
            derivationVersion: 1,
            publicKey: Data(repeating: 8, count: 32),
            address: "iroha:orphan"
        )
        XCTAssertThrowsError(
            try store.stageAndActivate(
                WalletNetworkSnapshot(
                    schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
                    selectedWalletId: identity.id,
                    wallets: [identity],
                    accounts: [soraAccount, orphan],
                    createdAt: Date(timeIntervalSince1970: 3)
                )
            )
        )
        XCTAssertNil(try store.load())
    }

    func testWalletNetworkStoreRejectsOversizedActivePointerBeforeDecoding()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let activePointer = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("WalletNetworks", isDirectory: true)
            .appendingPathComponent("active.json")
        try Data(repeating: 0x41, count: 4 * 1_024 + 1).write(
            to: activePointer,
            options: .atomic
        )

        XCTAssertThrowsError(try store.load())
    }

    func testWalletNetworkStoreRejectsSnapshotWithoutActivePointer() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let walletDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("WalletNetworks", isDirectory: true)
        try Data("retained activation evidence".utf8).write(
            to: walletDirectory.appendingPathComponent(
                "wallet-network-\(UUID().uuidString).json"
            ),
            options: .atomic
        )

        XCTAssertThrowsError(try store.load())
    }

    func testWalletNetworkStoreRejectsAndWillNotActivateOverNamespaceEvidence()
        throws
    {
        enum Evidence {
            case file(String)
            case directory(String)
            case danglingSymlink(String)
        }
        let evidenceCases: [Evidence] = [
            .file(".hidden"),
            .file("unexpected.txt"),
            .directory("unexpected-directory"),
            .danglingSymlink("active.json"),
            .file("wallet-network-\(UUID().uuidString).json"),
        ]
        for evidence in evidenceCases {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    UUID().uuidString,
                    isDirectory: true
                )
            defer {
                try? FileManager.default.removeItem(at: directory)
            }
            let store = try WalletNetworkStore(baseURL: directory)
            let walletDirectory = directory
                .appendingPathComponent("SORA", isDirectory: true)
                .appendingPathComponent(
                    "WalletNetworks",
                    isDirectory: true
                )
            switch evidence {
            case let .file(name):
                try Data("retained evidence".utf8).write(
                    to: walletDirectory.appendingPathComponent(name),
                    options: .atomic
                )
            case let .directory(name):
                try FileManager.default.createDirectory(
                    at: walletDirectory.appendingPathComponent(
                        name,
                        isDirectory: true
                    ),
                    withIntermediateDirectories: false
                )
            case let .danglingSymlink(name):
                try FileManager.default.createSymbolicLink(
                    at: walletDirectory.appendingPathComponent(name),
                    withDestinationURL: walletDirectory
                        .appendingPathComponent("missing-target")
                )
            }
            let before = Set(
                try FileManager.default.contentsOfDirectory(
                    atPath: walletDirectory.path
                )
            )

            XCTAssertThrowsError(try store.load()) { error in
                guard
                    case WalletNetworkMigrationError
                        .snapshotVerificationFailed = error
                else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
            XCTAssertThrowsError(
                try store.stageAndActivate(
                    WalletNetworkSnapshot(
                        schemaVersion:
                            WalletNetworkSnapshot.currentSchemaVersion,
                        selectedWalletId: nil,
                        wallets: [],
                        accounts: [],
                        createdAt: Date(timeIntervalSince1970: 1)
                    )
                )
            ) { error in
                guard
                    case WalletNetworkMigrationError
                        .snapshotVerificationFailed = error
                else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
            XCTAssertEqual(
                Set(
                    try FileManager.default.contentsOfDirectory(
                        atPath: walletDirectory.path
                    )
                ),
                before,
                "Preflight failure must leave recovery evidence untouched"
            )
        }
    }

    func testWalletNetworkStoreRejectsUnexpectedEntryBesideActiveSnapshot()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let snapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: nil,
            wallets: [],
            accounts: [],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        try store.stageAndActivate(snapshot)
        let walletDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("WalletNetworks", isDirectory: true)
        let activePointer = walletDirectory.appendingPathComponent(
            "active.json"
        )
        let pointerBefore = try Data(contentsOf: activePointer)
        let unexpected = walletDirectory.appendingPathComponent(".hidden")
        try Data("unfinished activation evidence".utf8).write(
            to: unexpected,
            options: .atomic
        )

        XCTAssertThrowsError(try store.load()) { error in
            guard
                case WalletNetworkMigrationError
                    .snapshotVerificationFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertThrowsError(try store.stageAndActivate(snapshot))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unexpected.path))
        XCTAssertEqual(try Data(contentsOf: activePointer), pointerBefore)

        try FileManager.default.removeItem(at: unexpected)
        XCTAssertEqual(try store.load(), snapshot)
    }

    func testWalletNetworkStoreRejectsMalformedRetainedSnapshotBesideActive()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let snapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: nil,
            wallets: [],
            accounts: [],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        try store.stageAndActivate(snapshot)
        let walletDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("WalletNetworks", isDirectory: true)
        let activePointer = walletDirectory.appendingPathComponent(
            "active.json"
        )
        let pointerBefore = try Data(contentsOf: activePointer)
        let malformed = walletDirectory.appendingPathComponent(
            "wallet-network-\(UUID().uuidString).json"
        )
        try Data("{".utf8).write(to: malformed, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            guard
                case WalletNetworkMigrationError
                    .snapshotVerificationFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertThrowsError(try store.stageAndActivate(snapshot))
        XCTAssertTrue(FileManager.default.fileExists(atPath: malformed.path))
        XCTAssertEqual(try Data(contentsOf: activePointer), pointerBefore)
    }

    func testWalletNetworkStoreRejectsUnprunedCanonicalSnapshotSet()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let snapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: nil,
            wallets: [],
            accounts: [],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        try store.stageAndActivate(snapshot)
        let walletDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("WalletNetworks", isDirectory: true)
        let originalSnapshot = try XCTUnwrap(
            try FileManager.default.contentsOfDirectory(
                at: walletDirectory,
                includingPropertiesForKeys: nil
            ).first(where: {
                $0.lastPathComponent.hasPrefix("wallet-network-")
            })
        )
        let bytes = try Data(contentsOf: originalSnapshot)
        for _ in 0 ..< 8 {
            try bytes.write(
                to: walletDirectory.appendingPathComponent(
                    "wallet-network-\(UUID().uuidString).json"
                ),
                options: .atomic
            )
        }

        XCTAssertThrowsError(try store.load()) { error in
            guard
                case WalletNetworkMigrationError
                    .snapshotVerificationFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testWalletNetworkStoreBoundsSelectionAndNameSnapshots() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let first = makeLegacyAccount(address: "retention-first")
        let secondSource = makeLegacyAccount(address: "retention-second")
        let second = AccountItem(
            address: secondSource.address,
            cryptoType: secondSource.cryptoType,
            networkType: secondSource.networkType,
            username: secondSource.username,
            publicKeyData: secondSource.publicKeyData,
            settings: secondSource.settings,
            order: 1,
            isSelected: false
        )
        let store = try WalletNetworkStore(baseURL: directory)
        try store.stageAndActivate(
            WalletNetworkSnapshot(
                schemaVersion:
                    WalletNetworkSnapshot.currentSchemaVersion,
                selectedWalletId: first.address,
                wallets: [
                    WalletIdentity(
                        id: first.address,
                        displayName: first.username,
                        existingSoraAddress: first.address,
                        secretSource: .watchOnly
                    ),
                    WalletIdentity(
                        id: second.address,
                        displayName: second.username,
                        existingSoraAddress: second.address,
                        secretSource: .watchOnly
                    ),
                ],
                accounts: [
                    NetworkAccount(
                        walletId: first.address,
                        networkId: .sora2,
                        derivationVersion: 0,
                        publicKey: first.publicKeyData,
                        address: first.address
                    ),
                    NetworkAccount(
                        walletId: second.address,
                        networkId: .sora2,
                        derivationVersion: 0,
                        publicKey: second.publicKeyData,
                        address: second.address
                    ),
                ],
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )

        for index in 0 ..< 24 {
            let selected = index.isMultiple(of: 2) ? first : second
            try store.selectWallet(
                walletId: selected.address,
                expectedAccounts: [first, second]
            )
            try store.updateWalletDisplayName(
                walletId: selected.address,
                displayName: "Wallet \(index)",
                expectedAccounts: [first, second]
            )
        }

        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.selectedWalletId, second.address)
        XCTAssertEqual(
            loaded.wallets.first(where: {
                $0.id == second.address
            })?.displayName,
            "Wallet 23"
        )
        let snapshotDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(
                "WalletNetworks",
                isDirectory: true
            )
        let snapshots = try FileManager.default
            .contentsOfDirectory(
                at: snapshotDirectory,
                includingPropertiesForKeys: nil
            )
            .filter {
                $0.lastPathComponent
                    .hasPrefix("wallet-network-")
            }
        XCTAssertLessThanOrEqual(snapshots.count, 8)
        XCTAssertGreaterThanOrEqual(snapshots.count, 2)
    }

    func testWalletAccountCommitJournalRequiresOrderedActivation()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletAccountCommitJournalStore(
            baseURL: directory
        )
        var journal = try store.begin(
            walletId: "new-wallet",
            existingWalletIds: ["retained-wallet"]
        )
        XCTAssertEqual(
            try store.unresolved().map(\.stage),
            [.prepared]
        )
        XCTAssertThrowsError(
            try store.advance(journal, to: .coreDataCommitted)
        )
        journal = try store.advance(
            journal,
            to: .secretsPersisted
        )
        journal = try store.advance(
            journal,
            to: .coreDataCommitted
        )
        journal = try store.advance(
            journal,
            to: .networkModelActivated
        )
        _ = try store.advance(journal, to: .activated)
        XCTAssertTrue(try store.unresolved().isEmpty)

        for index in 0 ..< 10 {
            var retained = try store.begin(
                walletId: "wallet-\(index)",
                existingWalletIds: []
            )
            retained = try store.advance(
                retained,
                to: .secretsPersisted
            )
            retained = try store.advance(
                retained,
                to: .coreDataCommitted
            )
            retained = try store.advance(
                retained,
                to: .networkModelActivated
            )
            _ = try store.advance(retained, to: .activated)
        }

        let journalDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(
                "WalletAccountCommits",
                isDirectory: true
            )
        let journals = try FileManager.default
            .contentsOfDirectory(
                at: journalDirectory,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "json" }
        XCTAssertEqual(journals.count, 8)
    }

    func testWalletAccountCommitJournalRejectsUnboundedFileSet() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletAccountCommitJournalStore(
            baseURL: directory
        )
        let journalDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(
                "WalletAccountCommits",
                isDirectory: true
            )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let now = Date()
        for index in 0 ..< 17 {
            let journal = WalletAccountCommitJournal(
                id: UUID(),
                walletId: "wallet-\(index)",
                expectedExistingWalletIds: [],
                stage: .activated,
                createdAt: now,
                updatedAt: now
            )
            try encoder.encode(journal).write(
                to: journalDirectory.appendingPathComponent(
                    "wallet-account-\(journal.id.uuidString).json"
                ),
                options: .atomic
            )
        }

        XCTAssertThrowsError(try store.unresolved())
    }

    func testWalletAccountCommitJournalRejectsUnexpectedNamespaceEntries()
        throws
    {
        enum Evidence {
            case file(String)
            case directory(String)
            case symlink(String)
        }
        let evidenceCases: [Evidence] = [
            .file(".hidden"),
            .file("unexpected.txt"),
            .directory("unexpected-directory"),
            .symlink("unexpected-link"),
        ]
        for evidence in evidenceCases {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    UUID().uuidString,
                    isDirectory: true
                )
            defer {
                try? FileManager.default.removeItem(at: directory)
            }
            let store = try WalletAccountCommitJournalStore(
                baseURL: directory
            )
            let journalDirectory = directory
                .appendingPathComponent("SORA", isDirectory: true)
                .appendingPathComponent(
                    "WalletAccountCommits",
                    isDirectory: true
                )
            switch evidence {
            case let .file(name):
                try Data("retained evidence".utf8).write(
                    to: journalDirectory.appendingPathComponent(name),
                    options: .atomic
                )
            case let .directory(name):
                try FileManager.default.createDirectory(
                    at: journalDirectory.appendingPathComponent(
                        name,
                        isDirectory: true
                    ),
                    withIntermediateDirectories: false
                )
            case let .symlink(name):
                try FileManager.default.createSymbolicLink(
                    at: journalDirectory.appendingPathComponent(name),
                    withDestinationURL: journalDirectory
                        .appendingPathComponent("missing-target")
                )
            }

            XCTAssertThrowsError(try store.unresolved()) { error in
                guard
                    case WalletNetworkMigrationError
                        .snapshotVerificationFailed = error
                else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }

    func testWalletAccountCommitJournalWillNotAdvanceBesideUnexpectedEvidence()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletAccountCommitJournalStore(
            baseURL: directory
        )
        let journal = try store.begin(
            walletId: "new-wallet",
            existingWalletIds: ["retained-wallet"]
        )
        let journalDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(
                "WalletAccountCommits",
                isDirectory: true
            )
        let journalURL = journalDirectory.appendingPathComponent(
            "wallet-account-\(journal.id.uuidString).json"
        )
        let journalBefore = try Data(contentsOf: journalURL)
        let unexpected = journalDirectory.appendingPathComponent(".hidden")
        try Data("interrupted commit evidence".utf8).write(
            to: unexpected,
            options: .atomic
        )

        XCTAssertThrowsError(
            try store.advance(journal, to: .secretsPersisted)
        ) { error in
            guard
                case WalletNetworkMigrationError
                    .snapshotVerificationFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: journalURL), journalBefore)

        try FileManager.default.removeItem(at: unexpected)
        XCTAssertEqual(try store.unresolved().map(\.stage), [.prepared])
    }

    func testWalletAccountCommitJournalRejectsStaleAdvanceHandle() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletAccountCommitJournalStore(
            baseURL: directory
        )
        let prepared = try store.begin(
            walletId: "new-wallet",
            existingWalletIds: ["retained-wallet"]
        )
        let secretsPersisted = try store.advance(
            prepared,
            to: .secretsPersisted
        )

        XCTAssertThrowsError(
            try store.advance(prepared, to: .coreDataCommitted)
        ) { error in
            guard
                case WalletNetworkMigrationError
                    .snapshotVerificationFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let unresolved = try store.unresolved()
        XCTAssertEqual(unresolved.map(\.id), [secretsPersisted.id])
        XCTAssertEqual(
            unresolved.map(\.stage),
            [.secretsPersisted]
        )
    }

    func testWalletAccountCommitJournalPrunesBeforeTerminalActivation()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let fileManager = WalletJournalRemovalFailingFileManager()
        let settings = InMemorySettingsManager()
        let recoveryGate = WalletRecoveryCapabilityGate(
            settings: settings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }
        )
        let store = try WalletAccountCommitJournalStore(
            fileManager: fileManager,
            baseURL: directory,
            recoveryGate: recoveryGate
        )

        for index in 0 ..< 8 {
            var completed = try store.begin(
                walletId: "retained-\(index)",
                existingWalletIds: []
            )
            completed = try store.advance(
                completed,
                to: .secretsPersisted
            )
            completed = try store.advance(
                completed,
                to: .coreDataCommitted
            )
            completed = try store.advance(
                completed,
                to: .networkModelActivated
            )
            _ = try store.advance(completed, to: .activated)
        }

        var pending = try store.begin(
            walletId: "pending-wallet",
            existingWalletIds: []
        )
        pending = try store.advance(pending, to: .secretsPersisted)
        pending = try store.advance(pending, to: .coreDataCommitted)
        pending = try store.advance(
            pending,
            to: .networkModelActivated
        )
        fileManager.failWalletJournalRemoval = true
        XCTAssertThrowsError(
            try store.advance(pending, to: .activated)
        )
        fileManager.failWalletJournalRemoval = false

        let unresolved = try store.unresolved()
        XCTAssertEqual(unresolved.map(\.id), [pending.id])
        XCTAssertEqual(
            unresolved.map(\.stage),
            [.networkModelActivated],
            "A cleanup failure must leave the terminal transition unresolved"
        )
        XCTAssertTrue(settings.walletMigrationRecoveryRequired)
        XCTAssertFalse(
            settings.walletMigrationRecoveryReason?.isEmpty ?? true
        )
    }

    func testWalletAccountCommitJournalRejectsOversizedFileBeforeDecoding()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletAccountCommitJournalStore(
            baseURL: directory
        )
        let journalDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(
                "WalletAccountCommits",
                isDirectory: true
            )
        try Data(repeating: 0x41, count: 64 * 1_024 + 1).write(
            to: journalDirectory.appendingPathComponent(
                "wallet-account-\(UUID().uuidString).json"
            ),
            options: .atomic
        )

        XCTAssertThrowsError(try store.unresolved())
    }

    func testWalletAccountCommitJournalNormalizesMalformedCanonicalEntry()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletAccountCommitJournalStore(
            baseURL: directory
        )
        let journalDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(
                "WalletAccountCommits",
                isDirectory: true
            )
        try Data("{".utf8).write(
            to: journalDirectory.appendingPathComponent(
                "wallet-account-\(UUID().uuidString).json"
            ),
            options: .atomic
        )

        XCTAssertThrowsError(try store.unresolved()) { error in
            guard
                case WalletNetworkMigrationError
                    .snapshotVerificationFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testSelectedWalletDualReadUsesCoreDataThenLegacyFallback() throws {
        let first = makeLegacyAccount(address: "first-selection")
        let secondSource = makeLegacyAccount(address: "second-selection")
        let second = AccountItem(
            address: secondSource.address,
            cryptoType: secondSource.cryptoType,
            networkType: secondSource.networkType,
            username: secondSource.username,
            publicKeyData: secondSource.publicKeyData,
            settings: secondSource.settings,
            order: 1,
            isSelected: false
        )

        XCTAssertEqual(
            try SelectedWalletSettings.resolveSelection(
                accounts: [first, second],
                legacySelectedAddress: second.address
            )?.address,
            first.address
        )

        let firstWithoutSelection = AccountItem(
            address: first.address,
            cryptoType: first.cryptoType,
            networkType: first.networkType,
            username: first.username,
            publicKeyData: first.publicKeyData,
            settings: first.settings,
            order: first.order,
            isSelected: false
        )
        XCTAssertEqual(
            try SelectedWalletSettings.resolveSelection(
                accounts: [firstWithoutSelection, second],
                legacySelectedAddress: second.address
            )?.address,
            second.address
        )
        XCTAssertThrowsError(
            try SelectedWalletSettings.resolveSelection(
                accounts: [firstWithoutSelection, second],
                legacySelectedAddress: nil
            )
        )
    }

    func testLegacyWalletUpgradeRequiresExplicitUnambiguousLegacyOnlyState()
        throws
    {
        XCTAssertEqual(
            WalletMnemonicWordPolicy.userImportWordCounts,
            [12, 24]
        )
        XCTAssertEqual(
            WalletMnemonicWordPolicy.retainedSoraWordCounts,
            [12, 15, 24]
        )
        XCTAssertEqual(
            WalletMnemonicWordPolicy.retainedSecretSource(forWordCount: 15),
            .legacyMnemonicEntropy
        )
        XCTAssertEqual(
            WalletMnemonicWordPolicy.retainedSecretSource(forWordCount: 24),
            .mnemonicEntropy
        )
        XCTAssertNil(
            WalletMnemonicWordPolicy.retainedSecretSource(forWordCount: 18)
        )
        let legacyEntropy = Data(repeating: 0, count: 20)
        let legacyMnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: Data(repeating: 0, count: 20))
        XCTAssertEqual(legacyMnemonic.allWords().count, 15)
        let phrase = legacyMnemonic.toString()
        XCTAssertThrowsError(
            try NexusKeyDerivation.derive(
                mnemonic: phrase,
                configuration: .minamoto
            )
        )

        // Exercise the actual retained-15 preparation and persistence
        // boundary. The normal importer may derive temporary material for
        // identity verification, but upgrade activation must discard those
        // copies and leave the original unsuffixed entropy byte-for-byte
        // unchanged.
        let keychain = InMemoryKeychain()
        let retainedDisplayName = "Retained 15-word wallet"
        try keychain.addKey(
            legacyEntropy,
            with: KeystoreTag.legacyEntropy.rawValue
        )
        try keychain.addKey(
            Data(retainedDisplayName.utf8),
            with: KeystoreTag.legacyUsername.rawValue
        )
        let retainedSettings = InMemorySettingsManager()
        let retainedRecoveryGate = WalletRecoveryCapabilityGate(
            settings: retainedSettings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }
        )
        XCTAssertEqual(
            try LegacyWalletUpgradeDisplayNameResolver.resolve(
                settings: retainedSettings,
                keystore: keychain
            ),
            retainedDisplayName
        )
        let factory = AccountOperationFactory(
            keystore: keychain,
            recoveryGate: retainedRecoveryGate
        )
        let preparation = factory.prepareAccountOperation(
            request: AccountCreationRequest(
                username: retainedDisplayName,
                type: .sora,
                derivationPath: "",
                cryptoType: .sr25519
            ),
            mnemonic: legacyMnemonic
        )
        OperationQueue().addOperations(
            [preparation],
            waitUntilFinished: true
        )
        let prepared = try preparation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let seedResult = try SeedFactory().deriveSeed(
            from: phrase,
            password: ""
        )
        var expectedSeed = seedResult.seed.miniSeed
        defer {
            expectedSeed.resetBytes(
                in: expectedSeed.startIndex ..< expectedSeed.endIndex
            )
        }
        let expectedKeypair = try SR25519KeypairFactory()
            .createKeypairFromSeed(expectedSeed, chaincodeList: [])
        let expectedAddress = try SS58AddressFactory().address(
            fromAccountId: expectedKeypair.publicKey().rawData(),
            type: SNAddressType(chain: .sora)
        )
        XCTAssertEqual(prepared.account.address, expectedAddress)
        XCTAssertEqual(
            prepared.account.publicKeyData,
            expectedKeypair.publicKey().rawData()
        )

        let originalIdentifiers = Set(try keychain.allKeyIdentifiers())
        try LegacyWalletUpgradeSecretRetention.consumeWithoutPersisting(
            prepared,
            keystore: keychain,
            settings: retainedSettings,
            expectedEntropyDigest: Data(
                SHA256.hash(data: legacyEntropy)
            ),
            expectedDisplayName: retainedDisplayName,
            recoveryGate: retainedRecoveryGate
        )
        XCTAssertEqual(
            Set(try keychain.allKeyIdentifiers()),
            originalIdentifiers
        )
        XCTAssertEqual(
            try keychain.fetchKey(
                for: KeystoreTag.legacyEntropy.rawValue
            ),
            legacyEntropy
        )
        let conflictingNameSettings = InMemorySettingsManager()
        conflictingNameSettings.set(
            value: "Conflicting retained name",
            for: KeystoreTag.legacyUsername.rawValue
        )
        XCTAssertThrowsError(
            try LegacyWalletUpgradeDisplayNameResolver.resolve(
                settings: conflictingNameSettings,
                keystore: keychain
            )
        )
        XCTAssertEqual(
            try keychain.fetchKey(
                for: KeystoreTag.legacyUsername.rawValue
            ),
            Data(retainedDisplayName.utf8)
        )
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTag.secretKeyTagForAddress(expectedAddress)
            )
        )
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTag.entropyTagForAddress(expectedAddress)
            )
        )
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTag.seedTagForAddress(expectedAddress)
            )
        )

        let retainedSnapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: expectedAddress,
            wallets: [
                WalletIdentity(
                    id: expectedAddress,
                    displayName: prepared.account.username,
                    existingSoraAddress: expectedAddress,
                    secretSource: .legacyMnemonicEntropy
                ),
            ],
            accounts: [
                NetworkAccount(
                    walletId: expectedAddress,
                    networkId: .sora2,
                    derivationVersion: 0,
                    publicKey: prepared.account.publicKeyData,
                    address: expectedAddress
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        XCTAssertTrue(
            try WalletExplicitRemovalIdentityPolicy.verify(
                accounts: [prepared.account],
                expectedAccount: prepared.account,
                walletId: expectedAddress,
                snapshot: retainedSnapshot,
                keystore: keychain,
                settings: retainedSettings,
                recoveryGate: retainedRecoveryGate
            )
        )
        XCTAssertEqual(
            try keychain.fetchKey(
                for: KeystoreTag.legacyEntropy.rawValue
            ),
            legacyEntropy
        )

        let corruptedKeychain = InMemoryKeychain()
        try corruptedKeychain.addKey(
            Data(repeating: 1, count: 20),
            with: KeystoreTag.legacyEntropy.rawValue
        )
        XCTAssertThrowsError(
            try WalletExplicitRemovalIdentityPolicy.verify(
                accounts: [prepared.account],
                expectedAccount: prepared.account,
                walletId: expectedAddress,
                snapshot: retainedSnapshot,
                keystore: corruptedKeychain,
                settings: retainedSettings,
                recoveryGate: retainedRecoveryGate
            )
        )
        XCTAssertTrue(
            try corruptedKeychain.checkKey(
                for: KeystoreTag.legacyEntropy.rawValue
            )
        )

        let migrationDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: migrationDirectory)
        }
        let migrationKeychain = InMemoryKeychain()
        try migrationKeychain.addKey(
            legacyEntropy,
            with: KeystoreTag.legacyEntropy.rawValue
        )
        let preMigrationIdentifiers = Set(
            try migrationKeychain.allKeyIdentifiers()
        )
        let migrationSettings = InMemorySettingsManager()
        let migrationRecoveryGate = WalletRecoveryCapabilityGate(
            settings: migrationSettings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }
        )
        let migrationLifecycleCoordinator = WalletLifecycleCoordinator(
            recoveryGate: migrationRecoveryGate
        )
        let migrationStore = try WalletNetworkStore(
            baseURL: migrationDirectory,
            recoveryGate: migrationRecoveryGate
        )
        try WalletNetworkModelMigrator(
            keystore: migrationKeychain,
            store: migrationStore,
            settings: migrationSettings,
            lifecycleCoordinator: migrationLifecycleCoordinator,
            recoveryGate: migrationRecoveryGate
        ).migrate(
            accounts: [prepared.account],
            selectedAddress: expectedAddress
        )
        let migratedSnapshot = try XCTUnwrap(migrationStore.load())
        XCTAssertEqual(
            migratedSnapshot.wallets.first?.secretSource,
            .legacyMnemonicEntropy
        )
        XCTAssertEqual(
            migratedSnapshot.wallets.first?.displayName,
            retainedDisplayName
        )
        XCTAssertEqual(
            migratedSnapshot.accounts.map(\.networkId),
            [.sora2]
        )
        XCTAssertEqual(
            migratedSnapshot.accounts.first?.publicKey,
            prepared.account.publicKeyData
        )
        XCTAssertEqual(
            Set(try migrationKeychain.allKeyIdentifiers()),
            preMigrationIdentifiers
        )

        // A retained keystore-import/secret-only wallet is a distinct
        // production source. It must retain its exact SORA2 identity, create
        // no Nexus child, and be revalidated before explicit deletion.
        let secretOnlyKeychain = InMemoryKeychain()
        var retainedSecret = expectedKeypair.privateKey().rawData()
        defer {
            retainedSecret.resetBytes(
                in: retainedSecret.startIndex ..< retainedSecret.endIndex
            )
        }
        try secretOnlyKeychain.addKey(
            retainedSecret,
            with: KeystoreTag.secretKeyTagForAddress(expectedAddress)
        )
        let secretOnlyIdentifiers = Set(
            try secretOnlyKeychain.allKeyIdentifiers()
        )
        let secretOnlySettings = InMemorySettingsManager()
        let secretOnlyRecoveryGate = WalletRecoveryCapabilityGate(
            settings: secretOnlySettings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }
        )
        let secretOnlyLifecycleCoordinator = WalletLifecycleCoordinator(
            recoveryGate: secretOnlyRecoveryGate
        )
        let secretOnlyStore = try WalletNetworkStore(
            baseURL: migrationDirectory.appendingPathComponent(
                "legacy-secret-only",
                isDirectory: true
            ),
            recoveryGate: secretOnlyRecoveryGate
        )
        try WalletNetworkModelMigrator(
            keystore: secretOnlyKeychain,
            store: secretOnlyStore,
            settings: secretOnlySettings,
            lifecycleCoordinator: secretOnlyLifecycleCoordinator,
            recoveryGate: secretOnlyRecoveryGate
        ).migrate(
            accounts: [prepared.account],
            selectedAddress: expectedAddress
        )
        let secretOnlySnapshot = try XCTUnwrap(secretOnlyStore.load())
        XCTAssertEqual(
            secretOnlySnapshot.wallets.first?.secretSource,
            .legacySecret
        )
        XCTAssertEqual(
            secretOnlySnapshot.accounts.map(\.networkId),
            [.sora2]
        )
        XCTAssertEqual(
            secretOnlySnapshot.accounts.first?.publicKey,
            prepared.account.publicKeyData
        )
        XCTAssertEqual(
            Set(try secretOnlyKeychain.allKeyIdentifiers()),
            secretOnlyIdentifiers
        )
        XCTAssertFalse(
            try WalletExplicitRemovalIdentityPolicy.verify(
                accounts: [prepared.account],
                expectedAccount: prepared.account,
                walletId: expectedAddress,
                snapshot: secretOnlySnapshot,
                keystore: secretOnlyKeychain,
                settings: secretOnlySettings,
                recoveryGate: secretOnlyRecoveryGate
            )
        )
        XCTAssertEqual(
            Set(try secretOnlyKeychain.allKeyIdentifiers()),
            secretOnlyIdentifiers
        )

        var corruptedSecret = retainedSecret
        corruptedSecret[corruptedSecret.startIndex] ^= 0xff
        defer {
            corruptedSecret.resetBytes(
                in: corruptedSecret.startIndex ..< corruptedSecret.endIndex
            )
        }
        let corruptedSecretKeychain = InMemoryKeychain()
        try corruptedSecretKeychain.addKey(
            corruptedSecret,
            with: KeystoreTag.secretKeyTagForAddress(expectedAddress)
        )
        XCTAssertThrowsError(
            try WalletExplicitRemovalIdentityPolicy.verify(
                accounts: [prepared.account],
                expectedAccount: prepared.account,
                walletId: expectedAddress,
                snapshot: secretOnlySnapshot,
                keystore: corruptedSecretKeychain,
                settings: secretOnlySettings,
                recoveryGate: secretOnlyRecoveryGate
            )
        )
        XCTAssertTrue(
            try corruptedSecretKeychain.checkKey(
                for: KeystoreTag.secretKeyTagForAddress(expectedAddress)
            )
        )

        // Raw-seed-only and explicit watch-only accounts do not enter the
        // pre-account-model RootInteractor import. Qualify their actual
        // Core-Data-to-network-model path and the same deletion preflight
        // without allowing either source to be rewritten or promoted to
        // Nexus children.
        let rawSeedSettings = InMemorySettingsManager()
        let rawSeedRecoveryGate = WalletRecoveryCapabilityGate(
            settings: rawSeedSettings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }
        )
        let rawSeedLifecycleCoordinator = WalletLifecycleCoordinator(
            recoveryGate: rawSeedRecoveryGate
        )
        let rawSeedKeychain = InMemoryKeychain()
        try rawSeedKeychain.addKey(
            expectedSeed,
            with: KeystoreTag.seedTagForAddress(expectedAddress)
        )
        let rawSeedIdentifiers = Set(
            try rawSeedKeychain.allKeyIdentifiers()
        )
        let rawSeedStore = try WalletNetworkStore(
            baseURL: migrationDirectory.appendingPathComponent(
                "legacy-raw-seed",
                isDirectory: true
            ),
            recoveryGate: rawSeedRecoveryGate
        )
        try WalletNetworkModelMigrator(
            keystore: rawSeedKeychain,
            store: rawSeedStore,
            settings: rawSeedSettings,
            lifecycleCoordinator: rawSeedLifecycleCoordinator,
            recoveryGate: rawSeedRecoveryGate
        ).migrate(
            accounts: [prepared.account],
            selectedAddress: expectedAddress
        )
        let rawSeedSnapshot = try XCTUnwrap(rawSeedStore.load())
        XCTAssertEqual(
            rawSeedSnapshot.wallets.first?.secretSource,
            .rawSeed
        )
        XCTAssertEqual(rawSeedSnapshot.accounts.map(\.networkId), [.sora2])
        XCTAssertEqual(
            rawSeedSnapshot.accounts.first?.publicKey,
            prepared.account.publicKeyData
        )
        XCTAssertFalse(
            try WalletExplicitRemovalIdentityPolicy.verify(
                accounts: [prepared.account],
                expectedAccount: prepared.account,
                walletId: expectedAddress,
                snapshot: rawSeedSnapshot,
                keystore: rawSeedKeychain,
                settings: rawSeedSettings,
                recoveryGate: rawSeedRecoveryGate
            )
        )
        XCTAssertEqual(
            Set(try rawSeedKeychain.allKeyIdentifiers()),
            rawSeedIdentifiers
        )
        XCTAssertEqual(
            try rawSeedKeychain.fetchKey(
                for: KeystoreTag.seedTagForAddress(expectedAddress)
            ),
            expectedSeed
        )

        let watchOnlySettings = InMemorySettingsManager()
        let watchOnlyKey = "wallet.watchOnly.\(expectedAddress)"
        watchOnlySettings.set(value: true, for: watchOnlyKey)
        let watchOnlyRecoveryGate = WalletRecoveryCapabilityGate(
            settings: watchOnlySettings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }
        )
        let watchOnlyLifecycleCoordinator = WalletLifecycleCoordinator(
            recoveryGate: watchOnlyRecoveryGate
        )
        let watchOnlyKeychain = InMemoryKeychain()
        let watchOnlyStore = try WalletNetworkStore(
            baseURL: migrationDirectory.appendingPathComponent(
                "legacy-watch-only",
                isDirectory: true
            ),
            recoveryGate: watchOnlyRecoveryGate
        )
        try WalletNetworkModelMigrator(
            keystore: watchOnlyKeychain,
            store: watchOnlyStore,
            settings: watchOnlySettings,
            lifecycleCoordinator: watchOnlyLifecycleCoordinator,
            recoveryGate: watchOnlyRecoveryGate
        ).migrate(
            accounts: [prepared.account],
            selectedAddress: expectedAddress
        )
        let watchOnlySnapshot = try XCTUnwrap(watchOnlyStore.load())
        XCTAssertEqual(
            watchOnlySnapshot.wallets.first?.secretSource,
            .watchOnly
        )
        XCTAssertEqual(
            watchOnlySnapshot.accounts.map(\.networkId),
            [.sora2]
        )
        XCTAssertFalse(
            try WalletExplicitRemovalIdentityPolicy.verify(
                accounts: [prepared.account],
                expectedAccount: prepared.account,
                walletId: expectedAddress,
                snapshot: watchOnlySnapshot,
                keystore: watchOnlyKeychain,
                settings: watchOnlySettings,
                recoveryGate: watchOnlyRecoveryGate
            )
        )
        XCTAssertTrue(try watchOnlyKeychain.allKeyIdentifiers().isEmpty)
        XCTAssertEqual(
            watchOnlySettings.anyValue(for: watchOnlyKey) as? Bool,
            true
        )

        func walletNetworkBytes(at baseURL: URL) throws -> [String: Data] {
            let walletDirectory = baseURL
                .appendingPathComponent("SORA", isDirectory: true)
                .appendingPathComponent("WalletNetworks", isDirectory: true)
            let entries = try FileManager.default.contentsOfDirectory(
                at: walletDirectory,
                includingPropertiesForKeys: nil
            )
            var result: [String: Data] = [:]
            for entry in entries {
                result[entry.lastPathComponent] = try Data(contentsOf: entry)
            }
            return result
        }

        // Activate a normal 12-word mnemonic wallet so the continuity matrix
        // also proves that loss of its protected entropy cannot silently
        // downgrade it to watch-only during a later startup reconciliation.
        let mnemonicEntropy = Data(repeating: 0x2a, count: 16)
        let mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: mnemonicEntropy)
        XCTAssertEqual(mnemonic.allWords().count, 12)
        var mnemonicSeed = try SeedFactory()
            .deriveSeed(from: mnemonic.toString(), password: "")
            .seed
            .miniSeed
        defer {
            mnemonicSeed.resetBytes(
                in: mnemonicSeed.startIndex ..< mnemonicSeed.endIndex
            )
        }
        let mnemonicKeypair = try SR25519KeypairFactory()
            .createKeypairFromSeed(mnemonicSeed, chaincodeList: [])
        let mnemonicPublicKey = mnemonicKeypair.publicKey().rawData()
        let mnemonicAddress = try SS58AddressFactory().address(
            fromAccountId: mnemonicPublicKey,
            type: Chain.sora.addressType()
        )
        let mnemonicAccount = AccountItem(
            address: mnemonicAddress,
            cryptoType: .sr25519,
            networkType: Chain.sora.addressType(),
            username: "Retained 12-word wallet",
            publicKeyData: mnemonicPublicKey,
            settings: AccountSettings(
                visibleAssetIds: [],
                orderedAssetIds: []
            ),
            order: 0,
            isSelected: true
        )
        let mnemonicKeychain = InMemoryKeychain()
        try mnemonicKeychain.addKey(
            mnemonicEntropy,
            with: KeystoreTag.entropyTagForAddress(mnemonicAddress)
        )
        let mnemonicSettings = InMemorySettingsManager()
        let mnemonicRecoveryGate = WalletRecoveryCapabilityGate(
            settings: mnemonicSettings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }
        )
        let mnemonicLifecycleCoordinator = WalletLifecycleCoordinator(
            recoveryGate: mnemonicRecoveryGate
        )
        let mnemonicBaseURL = migrationDirectory.appendingPathComponent(
            "mnemonic-entropy",
            isDirectory: true
        )
        let mnemonicStore = try WalletNetworkStore(
            baseURL: mnemonicBaseURL,
            recoveryGate: mnemonicRecoveryGate
        )
        try WalletNetworkModelMigrator(
            keystore: mnemonicKeychain,
            store: mnemonicStore,
            settings: mnemonicSettings,
            lifecycleCoordinator: mnemonicLifecycleCoordinator,
            recoveryGate: mnemonicRecoveryGate
        ).migrate(
            accounts: [mnemonicAccount],
            selectedAddress: mnemonicAddress
        )
        let mnemonicSnapshot = try XCTUnwrap(mnemonicStore.load())
        XCTAssertEqual(
            mnemonicSnapshot.wallets.first?.secretSource,
            .mnemonicEntropy
        )
        XCTAssertEqual(
            Set(mnemonicSnapshot.accounts.map(\.networkId)),
            Set(NetworkId.allCases)
        )

        // Once a wallet source is active, neither missing protected material
        // nor a stale watch-only marker may downgrade it and hide the recovery
        // condition. The exact active snapshot must remain untouched.
        let retainedSourceContinuityCases: [(
            source: WalletSecretSource,
            baseURL: URL,
            store: WalletNetworkStore,
            snapshot: WalletNetworkSnapshot,
            account: AccountItem
        )] = [
            (
                .mnemonicEntropy,
                mnemonicBaseURL,
                mnemonicStore,
                mnemonicSnapshot,
                mnemonicAccount
            ),
            (
                .legacyMnemonicEntropy,
                migrationDirectory,
                migrationStore,
                migratedSnapshot,
                prepared.account
            ),
            (
                .legacySecret,
                migrationDirectory.appendingPathComponent(
                    "legacy-secret-only",
                    isDirectory: true
                ),
                secretOnlyStore,
                secretOnlySnapshot,
                prepared.account
            ),
            (
                .rawSeed,
                migrationDirectory.appendingPathComponent(
                    "legacy-raw-seed",
                    isDirectory: true
                ),
                rawSeedStore,
                rawSeedSnapshot,
                prepared.account
            ),
        ]
        for continuityCase in retainedSourceContinuityCases {
            let continuitySettings = InMemorySettingsManager()
            continuitySettings.set(
                value: true,
                for: "wallet.watchOnly.\(continuityCase.account.address)"
            )
            let continuityRecoveryGate = WalletRecoveryCapabilityGate(
                settings: continuitySettings,
                unresolvedMigrationJournal: { false },
                unresolvedWalletCommitJournal: { false }
            )
            let continuityLifecycleCoordinator = WalletLifecycleCoordinator(
                recoveryGate: continuityRecoveryGate
            )
            let bytesBefore = try walletNetworkBytes(
                at: continuityCase.baseURL
            )

            XCTAssertThrowsError(
                try WalletNetworkModelMigrator(
                    keystore: InMemoryKeychain(),
                    store: continuityCase.store,
                    settings: continuitySettings,
                    lifecycleCoordinator: continuityLifecycleCoordinator,
                    recoveryGate: continuityRecoveryGate
                ).migrate(
                    accounts: [continuityCase.account],
                    selectedAddress: continuityCase.account.address
                ),
                "Activated \(continuityCase.source.rawValue) became watch-only"
            ) { error in
                guard
                    case let WalletNetworkMigrationError
                        .legacyIdentityMismatch(address) = error
                else {
                    return XCTFail("Unexpected error: \(error)")
                }
                XCTAssertEqual(address, continuityCase.account.address)
            }
            XCTAssertEqual(
                try continuityCase.store.load(),
                continuityCase.snapshot
            )
            XCTAssertEqual(
                try walletNetworkBytes(at: continuityCase.baseURL),
                bytesBefore
            )
            XCTAssertEqual(
                continuitySettings.walletNetworkStoreVersion,
                0
            )
        }

        // The inverse transition is equally unsafe without an explicit,
        // journaled user action: newly visible signing material cannot silently
        // convert an already active watch-only wallet.
        let watchOnlyToSigningSettings = InMemorySettingsManager()
        let watchOnlyToSigningRecoveryGate = WalletRecoveryCapabilityGate(
            settings: watchOnlyToSigningSettings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }
        )
        let watchOnlyToSigningLifecycleCoordinator =
            WalletLifecycleCoordinator(
                recoveryGate: watchOnlyToSigningRecoveryGate
            )
        let watchOnlyBaseURL = migrationDirectory.appendingPathComponent(
            "legacy-watch-only",
            isDirectory: true
        )
        let watchOnlyBytesBefore = try walletNetworkBytes(
            at: watchOnlyBaseURL
        )
        XCTAssertThrowsError(
            try WalletNetworkModelMigrator(
                keystore: rawSeedKeychain,
                store: watchOnlyStore,
                settings: watchOnlyToSigningSettings,
                lifecycleCoordinator:
                    watchOnlyToSigningLifecycleCoordinator,
                recoveryGate: watchOnlyToSigningRecoveryGate
            ).migrate(
                accounts: [prepared.account],
                selectedAddress: expectedAddress
            )
        ) { error in
            guard
                case let WalletNetworkMigrationError
                    .legacyIdentityMismatch(address) = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(address, expectedAddress)
        }
        XCTAssertEqual(try watchOnlyStore.load(), watchOnlySnapshot)
        XCTAssertEqual(
            try walletNetworkBytes(at: watchOnlyBaseURL),
            watchOnlyBytesBefore
        )
        XCTAssertEqual(
            watchOnlyToSigningSettings.walletNetworkStoreVersion,
            0
        )

        let emptySnapshot = WalletNetworkSnapshot(
            schemaVersion:
                WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: nil,
            wallets: [],
            accounts: [],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let legacyIdentifiers: Set<String> = [
            KeystoreTag.legacyEntropy.rawValue,
            KeystoreTag.pincode.rawValue,
        ]
        XCTAssertTrue(
            LegacyWalletUpgradePolicy.isCandidate(
                keyIdentifiers: legacyIdentifiers,
                hasWatchOnlyWallet: false,
                snapshot: emptySnapshot
            )
        )
        XCTAssertFalse(
            LegacyWalletUpgradePolicy.isCandidate(
                keyIdentifiers: legacyIdentifiers.union([
                    "existing-address-secretKey",
                ]),
                hasWatchOnlyWallet: false,
                snapshot: emptySnapshot
            )
        )
        XCTAssertFalse(
            LegacyWalletUpgradePolicy.isCandidate(
                keyIdentifiers: legacyIdentifiers.union([
                    "privateKey",
                ]),
                hasWatchOnlyWallet: false,
                snapshot: emptySnapshot
            )
        )
        XCTAssertFalse(
            LegacyWalletUpgradePolicy.isCandidate(
                keyIdentifiers: legacyIdentifiers,
                hasWatchOnlyWallet: true,
                snapshot: emptySnapshot
            )
        )
        XCTAssertTrue(
            LegacyWalletUpgradePolicy.isCandidate(
                keyIdentifiers: legacyIdentifiers,
                hasWatchOnlyWallet: false,
                snapshot: nil
            )
        )
        XCTAssertTrue(
            LegacyWalletUpgradePolicy.shouldDeferStorageMigration(
                storeExists: false,
                keyIdentifiers: legacyIdentifiers,
                hasWatchOnlyWallet: false,
                snapshot: nil
            )
        )
        XCTAssertFalse(
            LegacyWalletUpgradePolicy.shouldDeferStorageMigration(
                storeExists: true,
                keyIdentifiers: legacyIdentifiers,
                hasWatchOnlyWallet: false,
                snapshot: nil
            )
        )
        let inconsistentSnapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: "orphaned-selection",
            wallets: [],
            accounts: [],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        XCTAssertFalse(
            LegacyWalletUpgradePolicy.isCandidate(
                keyIdentifiers: legacyIdentifiers,
                hasWatchOnlyWallet: false,
                snapshot: inconsistentSnapshot
            )
        )

        for fixture in [
            (wordCount: 12, entropyBytes: 16),
            (wordCount: 15, entropyBytes: 20),
            (wordCount: 24, entropyBytes: 32),
        ] {
            try exerciseFullLegacyWalletUpgrade(
                wordCount: fixture.wordCount,
                entropyBytes: fixture.entropyBytes,
                corruptCommitJournal: false
            )
        }
        try exerciseFullLegacyWalletUpgrade(
            wordCount: 15,
            entropyBytes: 20,
            corruptCommitJournal: true
        )
    }

    func testRetainedVersionOneCoreDataMigratesCopyOnWriteWithoutLosingWallet() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let account = makeLegacyAccount(address: "retained-v1")
        let version1 = try userStorageModel(named: UserStorageVersion.version1.rawValue)
        try writeAccount(
            account,
            to: storeURL,
            model: version1,
            includesSelection: false
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: account,
            for: SettingsKey.selectedAccount.rawValue
        )
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )

        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        )
        try migrator.performMigration()

        let version2 = try userStorageModel(named: UserStorageVersion.version2.rawValue)
        try assertStoredAccount(
            account,
            at: storeURL,
            model: version2,
            expectedSelection: true
        )

        let safetyDirectory = directory
            .appendingPathComponent("WalletMigrationSafety", isDirectory: true)
        let attempts = try FileManager.default.contentsOfDirectory(
            at: safetyDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(attempts.count, 1)
        let attempt = try XCTUnwrap(attempts.first)
        let backupDirectory = attempt
            .appendingPathComponent("legacy-store", isDirectory: true)
        let backupStore = backupDirectory.appendingPathComponent(
            storeURL.lastPathComponent
        )
        try assertStoredAccount(
            account,
            at: backupStore,
            model: version1,
            expectedSelection: nil
        )

        let backupManifest = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: backupDirectory
                        .appendingPathComponent("backup-manifest.json")
                )
            ) as? [[String: Any]]
        )
        let databaseRecord = try XCTUnwrap(
            backupManifest.first {
                $0["fileName"] as? String == storeURL.lastPathComponent
            }
        )
        XCTAssertEqual((databaseRecord["sha256"] as? String)?.count, 64)
        XCTAssertGreaterThan(databaseRecord["byteCount"] as? Int ?? 0, 0)
        let journal = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: attempt.appendingPathComponent("journal.json"))
            ) as? [String: Any]
        )
        XCTAssertEqual(journal["state"] as? String, "activated")
        XCTAssertFalse(settings.walletMigrationRecoveryRequired)
    }

    func testRetainedMultiAccountMigrationPreservesOrderAndSelection() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let firstSource = makeLegacyAccount(address: "multi-first")
        let secondSource = makeLegacyAccount(address: "multi-second")
        let first = AccountItem(
            address: firstSource.address,
            cryptoType: firstSource.cryptoType,
            networkType: firstSource.networkType,
            username: firstSource.username,
            publicKeyData: firstSource.publicKeyData,
            settings: firstSource.settings,
            order: 17,
            isSelected: false
        )
        let second = AccountItem(
            address: secondSource.address,
            cryptoType: secondSource.cryptoType,
            networkType: secondSource.networkType,
            username: secondSource.username,
            publicKeyData: secondSource.publicKeyData,
            settings: secondSource.settings,
            order: 3,
            isSelected: false
        )
        let version1 = try userStorageModel(
            named: UserStorageVersion.version1.rawValue
        )
        try writeAccounts(
            [first, second],
            to: storeURL,
            model: version1,
            includesSelection: false
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: second,
            for: SettingsKey.selectedAccount.rawValue
        )
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(first.address)"
        )
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(second.address)"
        )

        try UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        ).performMigration()

        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: version2
        )
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            let rows = try context.fetch(
                NSFetchRequest<NSManagedObject>(
                    entityName: "CDAccountItem"
                )
            )
            XCTAssertEqual(rows.count, 2)
            let byAddress = Dictionary(
                uniqueKeysWithValues: rows.compactMap { row in
                    (row.value(forKey: "identifier") as? String).map {
                        ($0, row)
                    }
                }
            )
            XCTAssertEqual(
                (byAddress[first.address]?.value(forKey: "order")
                    as? NSNumber)?.intValue,
                Int(first.order)
            )
            XCTAssertEqual(
                (byAddress[second.address]?.value(forKey: "order")
                    as? NSNumber)?.intValue,
                Int(second.order)
            )
            XCTAssertEqual(
                (byAddress[first.address]?.value(forKey: "isSelected")
                    as? NSNumber)?.boolValue,
                false
            )
            XCTAssertEqual(
                (byAddress[second.address]?.value(forKey: "isSelected")
                    as? NSNumber)?.boolValue,
                true
            )
        }
        let retainedSelection = try XCTUnwrap(
            settings.value(
                of: AccountItem.self,
                for: SettingsKey.selectedAccount.rawValue
            )
        )
        XCTAssertEqual(retainedSelection.address, second.address)
        XCTAssertEqual(retainedSelection.publicKeyData, second.publicKeyData)
        XCTAssertEqual(retainedSelection.order, second.order)

        let safetyDirectory = directory.appendingPathComponent(
            "WalletMigrationSafety",
            isDirectory: true
        )
        let attempts = try FileManager.default.contentsOfDirectory(
            at: safetyDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(attempts.count, 1)
        let attempt = try XCTUnwrap(attempts.first)
        let journal = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: attempt.appendingPathComponent("journal.json")
                )
            ) as? [String: Any]
        )
        XCTAssertEqual(journal["state"] as? String, "activated")
        let backupStore = attempt
            .appendingPathComponent("legacy-store", isDirectory: true)
            .appendingPathComponent(storeURL.lastPathComponent)
        try assertStoredAccounts(
            [first, second],
            at: backupStore,
            model: version1,
            includesSelection: false
        )
    }

    func testRetainedVersionTwoCoreDataGetsVerifiedSafetySnapshotWithoutWalletRewrite() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let account = makeLegacyAccount(address: "retained-v2")
        let version2 = try userStorageModel(named: UserStorageVersion.version2.rawValue)
        try writeAccount(
            account,
            to: storeURL,
            model: version2,
            includesSelection: true
        )
        let originalFileIdentifier = String(
            describing: try storeURL.resourceValues(
                forKeys: [.fileResourceIdentifierKey]
            ).fileResourceIdentifier
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )

        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        )
        XCTAssertTrue(migrator.requiresMigration())
        try migrator.performMigration()

        try assertStoredAccount(
            account,
            at: storeURL,
            model: version2,
            expectedSelection: true
        )
        XCTAssertEqual(
            String(
                describing: try storeURL.resourceValues(
                    forKeys: [.fileResourceIdentifierKey]
                ).fileResourceIdentifier
            ),
            originalFileIdentifier
        )
        let safetyDirectory = directory.appendingPathComponent(
            "WalletMigrationSafety",
            isDirectory: true
        )
        let attempts = try FileManager.default.contentsOfDirectory(
            at: safetyDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(attempts.count, 1)
        let attempt = try XCTUnwrap(attempts.first)
        let journal = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: attempt.appendingPathComponent(
                        "journal.json"
                    )
                )
            ) as? [String: Any]
        )
        XCTAssertEqual(journal["state"] as? String, "activated")
        XCTAssertEqual(
            (journal["safetyArtifacts"] as? [[String: Any]])?.count,
            3
        )
        let legacyStore = attempt
            .appendingPathComponent("legacy-store", isDirectory: true)
            .appendingPathComponent(storeURL.lastPathComponent)
        try assertStoredAccount(
            account,
            at: legacyStore,
            model: version2,
            expectedSelection: true
        )
        XCTAssertFalse(migrator.requiresMigration())

        let rootResidue = attempt.appendingPathComponent(
            ".durable-migrator-root-residue.safety-anchor"
        )
        try Data("retained-old-inode".utf8).write(to: rootResidue)
        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.interruptedMigration = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        try FileManager.default.removeItem(at: rootResidue)
        XCTAssertFalse(migrator.requiresMigration())

        let legacyDirectory = attempt.appendingPathComponent(
            "legacy-store",
            isDirectory: true
        )
        let legacyResidue = legacyDirectory.appendingPathComponent(
            ".durable-migrator-legacy-residue.withdrawn"
        )
        try Data("retained-failed-new-inode".utf8).write(
            to: legacyResidue
        )
        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.interruptedMigration = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        try FileManager.default.removeItem(at: legacyResidue)
        XCTAssertFalse(migrator.requiresMigration())
        try assertStoredAccount(
            account,
            at: storeURL,
            model: version2,
            expectedSelection: true
        )
    }

    func testRetainedVersionTwoMultiAccountSafetySnapshotPreservesInventoryAndSelection() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let firstSource = makeLegacyAccount(address: "retained-v2-multi-first")
        let secondSource = makeLegacyAccount(address: "retained-v2-multi-second")
        let first = AccountItem(
            address: firstSource.address,
            cryptoType: firstSource.cryptoType,
            networkType: firstSource.networkType,
            username: "First retained wallet",
            publicKeyData: firstSource.publicKeyData,
            settings: firstSource.settings,
            order: 11,
            isSelected: false
        )
        let second = AccountItem(
            address: secondSource.address,
            cryptoType: secondSource.cryptoType,
            networkType: secondSource.networkType,
            username: "Selected retained wallet",
            publicKeyData: secondSource.publicKeyData,
            settings: secondSource.settings,
            order: 4,
            isSelected: true
        )
        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        try writeAccounts(
            [first, second],
            to: storeURL,
            model: version2,
            includesSelection: true
        )
        let originalFileIdentifier = String(
            describing: try storeURL.resourceValues(
                forKeys: [.fileResourceIdentifierKey]
            ).fileResourceIdentifier
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: second,
            for: SettingsKey.selectedAccount.rawValue
        )
        settings.set(value: true, for: "wallet.watchOnly.\(first.address)")
        settings.set(value: true, for: "wallet.watchOnly.\(second.address)")
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        try migrator.performMigration()

        XCTAssertEqual(
            String(
                describing: try storeURL.resourceValues(
                    forKeys: [.fileResourceIdentifierKey]
                ).fileResourceIdentifier
            ),
            originalFileIdentifier
        )
        try assertStoredAccounts(
            [first, second],
            at: storeURL,
            model: version2
        )
        let retainedSelection = try XCTUnwrap(
            settings.value(
                of: AccountItem.self,
                for: SettingsKey.selectedAccount.rawValue
            )
        )
        XCTAssertEqual(retainedSelection.address, second.address)
        XCTAssertEqual(retainedSelection.publicKeyData, second.publicKeyData)
        XCTAssertEqual(retainedSelection.order, second.order)
        XCTAssertEqual(retainedSelection.isSelected, second.isSelected)

        let safetyDirectory = directory.appendingPathComponent(
            "WalletMigrationSafety",
            isDirectory: true
        )
        let attempts = try FileManager.default.contentsOfDirectory(
            at: safetyDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(attempts.count, 1)
        let attempt = try XCTUnwrap(attempts.first)
        let journal = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: attempt.appendingPathComponent("journal.json")
                )
            ) as? [String: Any]
        )
        XCTAssertEqual(journal["state"] as? String, "activated")
        XCTAssertEqual(
            (journal["safetyArtifacts"] as? [[String: Any]])?.count,
            3
        )
        let backupStore = attempt
            .appendingPathComponent("legacy-store", isDirectory: true)
            .appendingPathComponent(storeURL.lastPathComponent)
        try assertStoredAccounts(
            [first, second],
            at: backupStore,
            model: version2
        )
        XCTAssertFalse(migrator.requiresMigration())
    }

    func testCurrentSchemaSafetyArtifactTamperBeforeActivationFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let account = makeLegacyAccount(
            address: "pre-activation-current-schema-tamper"
        )
        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        try writeAccount(
            account,
            to: storeURL,
            model: version2,
            includesSelection: true
        )
        let originalFileIdentifier = String(
            describing: try storeURL.resourceValues(
                forKeys: [.fileResourceIdentifierKey]
            ).fileResourceIdentifier
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            beforeSafetyActivationVerification: { attempt in
                let settingsURL = attempt.appendingPathComponent(
                    "settings-backup.plist"
                )
                var data = try Data(contentsOf: settingsURL)
                data.append(0x00)
                try data.write(to: settingsURL, options: .atomic)
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                case UserStorageMigrationError.backupVerificationFailed =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(
            String(
                describing: try storeURL.resourceValues(
                    forKeys: [.fileResourceIdentifierKey]
                ).fileResourceIdentifier
            ),
            originalFileIdentifier
        )
        try assertStoredAccount(
            account,
            at: storeURL,
            model: version2,
            expectedSelection: true
        )
        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertTrue(settings.walletMigrationRecoveryRequired)

        let safetyDirectory = directory.appendingPathComponent(
            "WalletMigrationSafety",
            isDirectory: true
        )
        let attempt = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(
                at: safetyDirectory,
                includingPropertiesForKeys: nil
            ).first
        )
        let journal = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: attempt.appendingPathComponent(
                        "journal.json"
                    )
                )
            ) as? [String: Any]
        )
        XCTAssertEqual(
            journal["state"] as? String,
            "failed"
        )
    }

    func testCurrentSchemaRejectsUnreadableCopiedStoreBeforeActivation()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let account = makeLegacyAccount(
            address: "unreadable-copied-current-schema"
        )
        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        try writeAccount(
            account,
            to: storeURL,
            model: version2,
            includesSelection: true
        )
        let originalFileIdentifier = String(
            describing: try storeURL.resourceValues(
                forKeys: [.fileResourceIdentifierKey]
            ).fileResourceIdentifier
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            afterLegacyStoreCopyBeforeVerification: { backupDirectory in
                try Data("not-a-sqlite-store".utf8).write(
                    to: backupDirectory.appendingPathComponent(
                        storeURL.lastPathComponent
                    ),
                    options: .atomic
                )
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                case UserStorageMigrationError.backupVerificationFailed =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(
            String(
                describing: try storeURL.resourceValues(
                    forKeys: [.fileResourceIdentifierKey]
                ).fileResourceIdentifier
            ),
            originalFileIdentifier
        )
        try assertStoredAccount(
            account,
            at: storeURL,
            model: version2,
            expectedSelection: true
        )
        XCTAssertTrue(settings.walletMigrationRecoveryRequired)
        XCTAssertTrue(migrator.requiresMigration())
    }

    func testSuccessfulCurrentSchemaSafetySnapshotDoesNotClearConcurrentRecoveryMarker()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let account = makeLegacyAccount(
            address: "concurrent-sticky-recovery"
        )
        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        try writeAccount(
            account,
            to: storeURL,
            model: version2,
            includesSelection: true
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )
        let recoveryReason =
            "A concurrent integrity check preserved another wallet artifact."
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            beforeSafetyActivationVerification: { _ in
                settings.walletMigrationRecoveryRequired = true
                settings.walletMigrationRecoveryReason = recoveryReason
            }
        )

        XCTAssertNoThrow(try migrator.performMigration())
        XCTAssertTrue(settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(
            settings.walletMigrationRecoveryReason,
            recoveryReason
        )
        try assertStoredAccount(
            account,
            at: storeURL,
            model: version2,
            expectedSelection: true
        )
    }

    func testMappedSchemaSafetyArtifactTamperBeforeActivationRestoresLegacyStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let account = makeLegacyAccount(
            address: "pre-activation-mapped-schema-tamper"
        )
        let version1 = try userStorageModel(
            named: UserStorageVersion.version1.rawValue
        )
        try writeAccount(
            account,
            to: storeURL,
            model: version1,
            includesSelection: false
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: account,
            for: SettingsKey.selectedAccount.rawValue
        )
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            beforeSafetyActivationVerification: { attempt in
                let manifestURL = attempt.appendingPathComponent(
                    "account-manifest.json"
                )
                var data = try Data(contentsOf: manifestURL)
                data.append(0x00)
                try data.write(to: manifestURL, options: .atomic)
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                case UserStorageMigrationError.backupVerificationFailed =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(
            settings.walletMigrationRecoveryRequired,
            true
        )
        XCTAssertTrue(migrator.requiresMigration())
        try assertStoredAccount(
            account,
            at: storeURL,
            model: version1,
            expectedSelection: nil
        )

        let safetyDirectory = directory.appendingPathComponent(
            "WalletMigrationSafety",
            isDirectory: true
        )
        let attempt = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(
                at: safetyDirectory,
                includingPropertiesForKeys: nil
            ).first
        )
        let journal = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: attempt.appendingPathComponent(
                        "journal.json"
                    )
                )
            ) as? [String: Any]
        )
        XCTAssertEqual(journal["state"] as? String, "failed")
    }

    func testSymlinkedLegacyRollbackSourceIsNeverFollowed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let decoyURL = directory.appendingPathComponent(
            "external-rollback-decoy.sqlite"
        )
        let account = makeLegacyAccount(
            address: "rollback-symlink-wallet"
        )
        let decoyAccount = makeLegacyAccount(
            address: "rollback-symlink-decoy"
        )
        let version1 = try userStorageModel(
            named: UserStorageVersion.version1.rawValue
        )
        try writeAccount(
            account,
            to: storeURL,
            model: version1,
            includesSelection: false
        )
        try writeAccount(
            decoyAccount,
            to: decoyURL,
            model: version1,
            includesSelection: false
        )
        let decoyBefore = try Data(contentsOf: decoyURL)
        let settings = InMemorySettingsManager()
        settings.set(
            value: account,
            for: SettingsKey.selectedAccount.rawValue
        )
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            beforeSafetyActivationVerification: { attempt in
                let legacyStoreURL = attempt
                    .appendingPathComponent(
                        "legacy-store",
                        isDirectory: true
                    )
                    .appendingPathComponent(storeURL.lastPathComponent)
                try FileManager.default.removeItem(at: legacyStoreURL)
                try FileManager.default.createSymbolicLink(
                    at: legacyStoreURL,
                    withDestinationURL: decoyURL
                )
            }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                case UserStorageMigrationError.backupVerificationFailed =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try Data(contentsOf: decoyURL), decoyBefore)
        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        try assertStoredAccount(
            account,
            at: storeURL,
            model: version2,
            expectedSelection: true
        )
    }

    func testTamperedCurrentSchemaSafetySnapshotFailsClosedWithoutTouchingLiveWallet() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let account = makeLegacyAccount(
            address: "tampered-current-schema-backup"
        )
        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        try writeAccount(
            account,
            to: storeURL,
            model: version2,
            includesSelection: true
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        )

        try migrator.performMigration()
        let liveStore = try Data(contentsOf: storeURL)
        let safetyDirectory = directory.appendingPathComponent(
            "WalletMigrationSafety",
            isDirectory: true
        )
        let attempt = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(
                at: safetyDirectory,
                includingPropertiesForKeys: nil
            ).first
        )
        let backupURL = attempt
            .appendingPathComponent("legacy-store", isDirectory: true)
            .appendingPathComponent(storeURL.lastPathComponent)
        var tampered = try Data(contentsOf: backupURL)
        tampered.append(0x00)
        try tampered.write(to: backupURL, options: .atomic)

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                case UserStorageMigrationError.interruptedMigration =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: storeURL), liveStore)
    }

    func testMissingCoreDataStoreWithSelectedWalletEvidenceFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let account = makeLegacyAccount(address: "orphaned-wallet-storage")
        let settings = InMemorySettingsManager()
        settings.set(
            value: account,
            for: SettingsKey.selectedAccount.rawValue
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testMissingCoreDataStoreWithRetainedActivatedSafetyBackupFailsClosed()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let account = makeLegacyAccount(
            address: "retained-activated-safety-backup"
        )
        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        try writeAccount(
            account,
            to: storeURL,
            model: version2,
            includesSelection: true
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        )
        try migrator.performMigration()

        let safetyDirectory = directory.appendingPathComponent(
            "WalletMigrationSafety",
            isDirectory: true
        )
        let attempts = try FileManager.default.contentsOfDirectory(
            at: safetyDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(attempts.count, 1)
        let attempt = try XCTUnwrap(attempts.first)
        let backupStoreURL = attempt
            .appendingPathComponent("legacy-store", isDirectory: true)
            .appendingPathComponent(storeURL.lastPathComponent)
        let backupBefore = try Data(contentsOf: backupStoreURL)

        settings.removeAll()
        for suffix in ["", "-wal", "-shm", "-journal"] {
            let liveComponent = URL(
                fileURLWithPath: storeURL.path + suffix
            )
            if FileManager.default.fileExists(atPath: liveComponent.path) {
                try FileManager.default.removeItem(at: liveComponent)
            }
        }

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertEqual(try Data(contentsOf: backupStoreURL), backupBefore)
    }

    func testMissingCoreDataStoreWithOrphanedSQLiteSidecarFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let sidecarURL = URL(fileURLWithPath: storeURL.path + "-wal")
        let sidecarBefore = Data("retained SQLite wallet pages".utf8)
        try sidecarBefore.write(to: sidecarURL, options: .atomic)
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertEqual(try Data(contentsOf: sidecarURL), sidecarBefore)
    }

    func testDanglingCoreDataStoreSymlinkCannotBecomeNewWallet() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let missingTarget = directory.appendingPathComponent(
            "missing-wallet-store"
        )
        try FileManager.default.createSymbolicLink(
            at: storeURL,
            withDestinationURL: missingTarget
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.unknownStoreVersion = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(
            try FileManager.default.destinationOfSymbolicLink(
                atPath: storeURL.path
            ),
            missingTarget.path
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingTarget.path))
    }

    func testReachableCoreDataStoreSymlinkIsRejectedBeforeCoreDataAccess()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let targetURL = directory.appendingPathComponent(
            "reachable-wallet-target.sqlite"
        )
        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        try writeAccounts(
            [],
            to: targetURL,
            model: version2,
            includesSelection: true
        )
        let targetBefore = try Data(contentsOf: targetURL)
        try FileManager.default.createSymbolicLink(
            at: storeURL,
            withDestinationURL: targetURL
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.unknownStoreVersion = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: targetURL), targetBefore)
        XCTAssertEqual(
            try FileManager.default.destinationOfSymbolicLink(
                atPath: storeURL.path
            ),
            targetURL.path
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory
                    .appendingPathComponent("WalletMigrationSafety")
                    .path
            )
        )
    }

    func testSQLiteSidecarSymlinkIsRejectedBeforeCoreDataAccess() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        try writeAccounts(
            [],
            to: storeURL,
            model: version2,
            includesSelection: true
        )
        let storeBefore = try Data(contentsOf: storeURL)
        let externalSidecarTarget = directory.appendingPathComponent(
            "external-wallet-pages"
        )
        let externalBefore = Data("must remain untouched".utf8)
        try externalBefore.write(to: externalSidecarTarget, options: .atomic)
        let sidecarURL = URL(fileURLWithPath: storeURL.path + "-wal")
        if FileManager.default.fileExists(atPath: sidecarURL.path) {
            try FileManager.default.removeItem(at: sidecarURL)
        }
        try FileManager.default.createSymbolicLink(
            at: sidecarURL,
            withDestinationURL: externalSidecarTarget
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.unknownStoreVersion = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: storeURL), storeBefore)
        XCTAssertEqual(try Data(contentsOf: externalSidecarTarget), externalBefore)
        XCTAssertEqual(
            try FileManager.default.destinationOfSymbolicLink(
                atPath: sidecarURL.path
            ),
            externalSidecarTarget.path
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory
                    .appendingPathComponent("WalletMigrationSafety")
                    .path
            )
        )
    }

    func testMissingCoreDataStoreWithUnreadableSelectedWalletEvidenceFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let settings = InMemorySettingsManager()
        settings.set(
            value: Data([0xff, 0x00, 0x7f]),
            for: SettingsKey.selectedAccount.rawValue
        )
        XCTAssertNil(
            settings.value(
                of: AccountItem.self,
                for: SettingsKey.selectedAccount.rawValue
            )
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testMissingCoreDataStoreWithOnlyScopedKeychainSecretFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let retainedIdentifiers = [
            KeystoreTag.secretKeyTagForAddress(
                "orphaned-keychain-wallet"
            ),
            // A surviving pre-account-model username with missing entropy is
            // an inconsistent wallet upgrade, never a clean installation.
            KeystoreTag.legacyUsername.rawValue,
        ]
        for (index, identifier) in retainedIdentifiers.enumerated() {
            let storeURL = directory
                .appendingPathComponent("case-\(index)", isDirectory: true)
                .appendingPathComponent("UserDataModel.sqlite")
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let keystore = InMemoryKeychain()
            try keystore.addKey(Data([0x01]), with: identifier)
            XCTAssertTrue(try keystore.hasRetainedWalletMaterial())
            let migrator = UserStorageMigrator(
                targetVersion: .version2,
                storeURL: storeURL,
                modelDirectory: UserStorageParams.modelDirectory,
                keystore: keystore,
                settings: InMemorySettingsManager(),
                fileManager: .default
            )

            XCTAssertTrue(migrator.requiresMigration())
            XCTAssertThrowsError(try migrator.performMigration()) { error in
                guard
                    case UserStorageMigrationError.missingWalletStore = error
                else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: storeURL.path)
            )
        }

        let settingsOnlyStoreURL = directory
            .appendingPathComponent(
                "legacy-username-setting",
                isDirectory: true
            )
            .appendingPathComponent("UserDataModel.sqlite")
        try FileManager.default.createDirectory(
            at: settingsOnlyStoreURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let retainedSettings = InMemorySettingsManager()
        retainedSettings.set(
            value: "retained-wallet-name",
            for: KeystoreTag.legacyUsername.rawValue
        )
        XCTAssertTrue(retainedSettings.hasRetainedWalletSettings())
        let activatedSnapshotSettings = InMemorySettingsManager()
        activatedSnapshotSettings.set(
            value: WalletNetworkSnapshot.currentSchemaVersion,
            for: SettingsKey.walletNetworkStoreVersion.rawValue
        )
        XCTAssertTrue(
            activatedSnapshotSettings.hasRetainedWalletSettings()
        )
        let legacyIdentitySettings: [
            (String, (InMemorySettingsManager) -> Void)
        ] = [
            ("decentralized-id", { settings in
                settings.set(
                    value: "did:sora:retained",
                    for: SettingsKey.decentralizedId.rawValue
                )
            }),
            ("public-key-id", { settings in
                settings.set(
                    value: "did:sora:retained#keys-1",
                    for: SettingsKey.publicKeyId.rawValue
                )
            }),
            ("migration-completed", { settings in
                settings.set(
                    value: true,
                    for: SettingsKey.hasMigrated.rawValue
                )
            }),
            ("migration-account-completed", { settings in
                settings.set(
                    value: Data([0x01]),
                    for: SettingsKey.migratedAccountsV1.rawValue
                )
            }),
        ]
        for retainedIdentity in legacyIdentitySettings {
            let identityStoreURL = directory
                .appendingPathComponent(
                    "legacy-identity-setting-\(retainedIdentity.0)",
                    isDirectory: true
                )
                .appendingPathComponent("UserDataModel.sqlite")
            try FileManager.default.createDirectory(
                at: identityStoreURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let identitySettings = InMemorySettingsManager()
            retainedIdentity.1(identitySettings)
            XCTAssertTrue(identitySettings.hasRetainedWalletSettings())
            let identityMigrator = UserStorageMigrator(
                targetVersion: .version2,
                storeURL: identityStoreURL,
                modelDirectory: UserStorageParams.modelDirectory,
                keystore: InMemoryKeychain(),
                settings: identitySettings,
                fileManager: .default
            )

            XCTAssertTrue(identityMigrator.requiresMigration())
            XCTAssertThrowsError(
                try identityMigrator.performMigration()
            ) { error in
                guard
                    case UserStorageMigrationError.missingWalletStore = error
                else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: identityStoreURL.path)
            )
        }
        let settingsOnlyMigrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: settingsOnlyStoreURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: retainedSettings,
            fileManager: .default
        )

        XCTAssertTrue(settingsOnlyMigrator.requiresMigration())
        XCTAssertThrowsError(
            try settingsOnlyMigrator.performMigration()
        ) { error in
            guard
                case UserStorageMigrationError.missingWalletStore = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: settingsOnlyStoreURL.path
            )
        )
    }

    func testMissingCoreDataStoreWithOnlyRetainedPinFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let keystore = InMemoryKeychain()
        try keystore.addKey(
            Data([0x01]),
            with: KeystoreTag.pincode.rawValue
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testEmptyCurrentStoreWithRetainedPinCannotBecomeNewWallet() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let version2 = try userStorageModel(
            named: UserStorageVersion.version2.rawValue
        )
        try writeAccounts(
            [],
            to: storeURL,
            model: version2,
            includesSelection: true
        )
        let originalStore = try Data(contentsOf: storeURL)
        let keystore = InMemoryKeychain()
        try keystore.addKey(
            Data([0x01]),
            with: KeystoreTag.pincode.rawValue
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore,
            settings: InMemorySettingsManager(),
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: storeURL), originalStore)
    }

    func testMissingCoreDataStoreWithOnlyWatchOnlyMarkerFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let settings = InMemorySettingsManager()
        settings.set(
            value: true,
            for: "wallet.watchOnly.orphaned-watch-only-wallet"
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testMissingCoreDataStoreWithUnreadableWatchOnlyMarkerFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let settings = InMemorySettingsManager()
        settings.set(
            value: Data([0xde, 0xad, 0xbe, 0xef]),
            for: "wallet.watchOnly.unreadable-watch-only-wallet"
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testMissingCoreDataAfterExplicitFinalWalletRemovalRemainsClean() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let emptySnapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: nil,
            wallets: [],
            accounts: [],
            createdAt: Date()
        )
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            loadWalletNetworkSnapshot: { emptySnapshot }
        )

        XCTAssertFalse(migrator.requiresMigration())
        XCTAssertNoThrow(try migrator.performMigration())
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testLowStorageFailsBeforeTouchingInstalledWalletStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let account = makeLegacyAccount(address: "low-storage-wallet")
        let version1 = try userStorageModel(named: UserStorageVersion.version1.rawValue)
        try writeAccount(
            account,
            to: storeURL,
            model: version1,
            includesSelection: false
        )
        let originalStore = try Data(contentsOf: storeURL)
        let settings = InMemorySettingsManager()
        settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        settings.set(value: true, for: "wallet.watchOnly.\(account.address)")
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default,
            availableCapacity: { _ in 0 }
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.insufficientStorage = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: storeURL), originalStore)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory
                    .appendingPathComponent("WalletMigrationSafety")
                    .path
            )
        )
    }

    func testFailedCoreDataMigrationJournalRequiresExplicitRecovery() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let attempt = directory
            .appendingPathComponent("WalletMigrationSafety", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: attempt,
            withIntermediateDirectories: true
        )
        let journal: [String: Any] = [
            "migrationID": UUID().uuidString,
            "sourceVersion": UserStorageVersion.version1.rawValue,
            "destinationVersion": UserStorageVersion.version2.rawValue,
            "state": "failed",
            "updatedAt": "2026-08-02T00:00:00Z",
            "failureReason": "account inventory mismatch"
        ]
        try JSONSerialization.data(
            withJSONObject: journal,
            options: [.sortedKeys]
        ).write(
            to: attempt.appendingPathComponent("journal.json"),
            options: .atomic
        )
        let settings = InMemorySettingsManager()
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: directory.appendingPathComponent("UserDataModel.sqlite"),
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: settings,
            fileManager: .default
        )

        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.interruptedMigration = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testUnboundedMigrationSafetyNamespaceFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let safetyDirectory = directory.appendingPathComponent(
            "WalletMigrationSafety",
            isDirectory: true
        )
        for _ in 0 ..< 17 {
            try FileManager.default.createDirectory(
                at: safetyDirectory.appendingPathComponent(
                    UUID().uuidString,
                    isDirectory: true
                ),
                withIntermediateDirectories: true
            )
        }
        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: directory.appendingPathComponent(
                "UserDataModel.sqlite"
            ),
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default
        )

        XCTAssertTrue(migrator.requiresMigration())
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard
                case UserStorageMigrationError.interruptedMigration =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testUnexpectedMigrationSafetyEntriesFailClosed() throws {
        for entryName in [".hidden", "unexpected.txt"] {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    UUID().uuidString,
                    isDirectory: true
                )
            defer {
                try? FileManager.default.removeItem(at: directory)
            }
            let safetyDirectory = directory.appendingPathComponent(
                "WalletMigrationSafety",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: safetyDirectory,
                withIntermediateDirectories: true
            )
            try Data("unexpected".utf8).write(
                to: safetyDirectory.appendingPathComponent(
                    entryName
                ),
                options: .atomic
            )
            let migrator = UserStorageMigrator(
                targetVersion: .version2,
                storeURL: directory.appendingPathComponent(
                    "UserDataModel.sqlite"
                ),
                modelDirectory: UserStorageParams.modelDirectory,
                keystore: InMemoryKeychain(),
                settings: InMemorySettingsManager(),
                fileManager: .default
            )

            XCTAssertTrue(
                migrator.requiresMigration(),
                "Unexpected entry \(entryName) must block migration"
            )
            XCTAssertThrowsError(
                try migrator.performMigration()
            ) { error in
                guard
                    case UserStorageMigrationError.interruptedMigration =
                        error
                else {
                    return XCTFail(
                        "Unexpected error for \(entryName): \(error)"
                    )
                }
            }
        }
    }

    func testMigrationWithMissingSecretDoesNotActivateStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let settings = InMemorySettingsManager()
        let account = makeLegacyAccount(address: "missing-secret")
        let migrator = WalletNetworkModelMigrator(
            keystore: InMemoryKeychain(),
            store: store,
            settings: settings
        )

        XCTAssertThrowsError(
            try migrator.migrate(
                accounts: [account],
                selectedAddress: account.address
            )
        ) { error in
            guard
                case WalletNetworkMigrationError.legacyIdentityMismatch =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertNil(try store.load())
        XCTAssertEqual(settings.walletNetworkStoreVersion, 0)
    }

    func testLegacyMnemonicMigrationRejectsMismatchedRetainedSeed() throws {
        let entropy = Data((0..<16).map { UInt8($0) })
        let mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: entropy)
        let derivedSeed = try SeedFactory()
            .deriveSeed(from: mnemonic.toString(), password: "")
            .seed
            .miniSeed
        let keypair = try SR25519KeypairFactory().createKeypairFromSeed(
            derivedSeed,
            chaincodeList: []
        )
        let publicKey = keypair.publicKey().rawData()
        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: Chain.sora.addressType()
        )
        var mismatchedSeed = derivedSeed
        mismatchedSeed[mismatchedSeed.startIndex] ^= 0x01

        XCTAssertThrowsError(
            try LegacySoraIdentityValidator.validate(
                address: address,
                publicKey: publicKey,
                cryptoType: .sr25519,
                networkType: Chain.sora.addressType(),
                derivationPath: nil,
                entropy: entropy,
                rawSeed: mismatchedSeed,
                secret: keypair.privateKey().rawData()
            )
        ) { error in
            guard
                case WalletNetworkMigrationError.legacyIdentityMismatch =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testExplicitWatchOnlyMigrationNeverSynthesizesNexusChildren() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let settings = InMemorySettingsManager()
        let account = makeLegacyAccount(address: "watch-only")
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )
        let migrator = WalletNetworkModelMigrator(
            keystore: InMemoryKeychain(),
            store: store,
            settings: settings
        )

        try migrator.migrate(
            accounts: [account],
            selectedAddress: account.address
        )

        let snapshot = try XCTUnwrap(store.load())
        XCTAssertEqual(snapshot.selectedWalletId, account.address)
        XCTAssertEqual(snapshot.wallets.count, 1)
        XCTAssertEqual(snapshot.wallets.first?.secretSource, .watchOnly)
        XCTAssertEqual(snapshot.accounts.map(\.networkId), [.sora2])
        XCTAssertEqual(snapshot.accounts.first?.address, account.address)
        XCTAssertEqual(
            snapshot.accounts.first?.publicKey,
            account.publicKeyData
        )
    }

    func testExplicitWatchOnlyAddressMustMatchItsStoredPublicKey() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let valid = makeLegacyAccount(address: "watch-only-integrity")
        let tampered = AccountItem(
            address: "cnTamperedWatchOnlyAddress",
            cryptoType: valid.cryptoType,
            networkType: valid.networkType,
            username: valid.username,
            publicKeyData: valid.publicKeyData,
            settings: valid.settings,
            order: valid.order,
            isSelected: valid.isSelected
        )
        let settings = InMemorySettingsManager()
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(tampered.address)"
        )
        let store = try WalletNetworkStore(baseURL: directory)
        let migrator = WalletNetworkModelMigrator(
            keystore: InMemoryKeychain(),
            store: store,
            settings: settings
        )

        XCTAssertThrowsError(
            try migrator.migrate(
                accounts: [tampered],
                selectedAddress: tampered.address
            )
        ) { error in
            guard
                case WalletNetworkMigrationError.legacyIdentityMismatch =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertNil(try store.load())
    }

    func testExplicitWatchOnlyMigrationRejectsRetainedSigningMaterial() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let account = makeLegacyAccount(address: "watch-only-secret-conflict")
        let settings = InMemorySettingsManager()
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )
        let keystore = InMemoryKeychain()
        try keystore.addKey(
            Data(repeating: 0x11, count: 32),
            with: KeystoreTag.secretKeyTagForAddress(account.address)
        )
        let store = try WalletNetworkStore(baseURL: directory)

        XCTAssertThrowsError(
            try WalletNetworkModelMigrator(
                keystore: keystore,
                store: store,
                settings: settings
            ).migrate(
                accounts: [account],
                selectedAddress: account.address
            )
        ) { error in
            guard
                case WalletNetworkMigrationError.legacyIdentityMismatch =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertNil(try store.load())
    }

    func testUnreadableWatchOnlyMarkerCannotBeReclassifiedDuringMigration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let account = makeLegacyAccount(address: "watch-only-marker-unreadable")
        let settings = InMemorySettingsManager()
        settings.set(
            value: Data([0xca, 0xfe]),
            for: "wallet.watchOnly.\(account.address)"
        )
        let store = try WalletNetworkStore(baseURL: directory)

        XCTAssertThrowsError(
            try WalletNetworkModelMigrator(
                keystore: InMemoryKeychain(),
                store: store,
                settings: settings
            ).migrate(
                accounts: [account],
                selectedAddress: account.address
            )
        ) { error in
            guard
                case WalletNetworkMigrationError.legacyIdentityMismatch =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertNil(try store.load())
    }

    func testExistingAccountWithoutSelectionFailsIntoRecoveryPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let settings = InMemorySettingsManager()
        let account = makeLegacyAccount(address: "selection-was-lost")
        settings.set(
            value: true,
            for: "wallet.watchOnly.\(account.address)"
        )
        let migrator = WalletNetworkModelMigrator(
            keystore: InMemoryKeychain(),
            store: store,
            settings: settings
        )

        XCTAssertThrowsError(
            try migrator.migrate(
                accounts: [account],
                selectedAddress: nil
            )
        ) { error in
            guard
                case WalletNetworkMigrationError.missingSelectedWallet =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertNil(try store.load())
        XCTAssertEqual(settings.walletNetworkStoreVersion, 0)
    }

    func testMigrationCannotDropPreviouslyInventoriedAccount() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let account = makeLegacyAccount(address: "must-survive")
        let original = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: account.address,
            wallets: [
                WalletIdentity(
                    id: account.address,
                    displayName: account.username,
                    existingSoraAddress: account.address,
                    secretSource: .watchOnly
                )
            ],
            accounts: [
                NetworkAccount(
                    walletId: account.address,
                    networkId: .sora2,
                    derivationVersion: 0,
                    publicKey: account.publicKeyData,
                    address: account.address
                )
            ],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        try store.stageAndActivate(original)
        let migrator = WalletNetworkModelMigrator(
            keystore: InMemoryKeychain(),
            store: store,
            settings: InMemorySettingsManager()
        )

        XCTAssertThrowsError(
            try migrator.migrate(accounts: [], selectedAddress: nil)
        ) { error in
            guard
                case WalletNetworkMigrationError.legacyIdentityMismatch =
                    error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try store.load(), original)
    }

    func testCorruptActivePointerFailsClosedInsteadOfCreatingEmptyWallet() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try WalletNetworkStore(baseURL: directory)
        let account = makeLegacyAccount(address: "recoverable-wallet")
        let snapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: account.address,
            wallets: [
                WalletIdentity(
                    id: account.address,
                    displayName: account.username,
                    existingSoraAddress: account.address,
                    secretSource: .watchOnly
                )
            ],
            accounts: [
                NetworkAccount(
                    walletId: account.address,
                    networkId: .sora2,
                    derivationVersion: 0,
                    publicKey: account.publicKeyData,
                    address: account.address
                )
            ],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        try store.stageAndActivate(snapshot)

        let activePointer = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("WalletNetworks", isDirectory: true)
            .appendingPathComponent("active.json")
        try Data("interrupted-pointer".utf8).write(
            to: activePointer,
            options: .atomic
        )

        XCTAssertThrowsError(try store.load()) { error in
            guard
                case WalletNetworkMigrationError
                    .snapshotVerificationFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let retainedSnapshots = try FileManager.default.contentsOfDirectory(
            at: activePointer.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        ).filter {
            $0.lastPathComponent.hasPrefix("wallet-network-")
        }
        XCTAssertEqual(retainedSnapshots.count, 1)
    }

    func testPreciseWireQuantitiesRejectFloatingPointSyntax() throws {
        XCTAssertEqual(try PIQuantity("999999999999999999.000000000000000001").rawValue,
                       "999999999999999999.000000000000000001")
        for invalid in [
            "1e18", "NaN", "+1", "01", ".1", "1.", " 1", "1 ", "1\n",
        ] {
            XCTAssertThrowsError(try PIQuantity(invalid))
        }
        XCTAssertThrowsError(try PIQuantity(String(repeating: "9", count: 4_097)))
    }

    func testPIChartConversionRequiresFiniteBoundedDerivedValues() throws {
        XCTAssertEqual(
            try PIQuantity("0.5").unitIntervalDoubleForRendering,
            0.5
        )
        XCTAssertNil(try PIQuantity("-0").unitIntervalDoubleForRendering)
        XCTAssertNil(try PIQuantity("2").unitIntervalDoubleForRendering)
        XCTAssertNil(
            try PIQuantity(
                String(repeating: "9", count: PIQuantity.maximumWireBytes)
            ).finiteDoubleForRendering
        )
    }

    func testPIFiatAndApyAdaptersPreserveExactWireValues() throws {
        let raw = "123456789012345678901234567890.123456789"
        let quantity = try PIQuantity(raw)
        let fiat = PIExactFiatData(id: "xor", priceUsd: quantity)
        let apy = PIExactApyInfo(id: "pool", sbApy: quantity)

        XCTAssertEqual(fiat.priceUsd?.rawValue, raw)
        XCTAssertEqual(apy.sbApy?.rawValue, raw)
    }

    func testProductionMutationFlagsFailClosedWhenUnset() {
        let settings = InMemorySettingsManager()

        XCTAssertTrue(settings.nexusEnabled)
        XCTAssertFalse(settings.nexusSendsEnabled)
        XCTAssertTrue(settings.polkamarktEnabled)
        XCTAssertFalse(settings.polkamarktMutationsEnabled)
        XCTAssertTrue(settings.isTairaEnabled)
    }

    func testTairaSendAvailabilityRequiresVisibleTestNetworks() {
        XCTAssertTrue(
            NexusSendAvailabilityPolicy.permits(
                networkId: .minamoto,
                nexusEnabled: true,
                sendsEnabled: true,
                tairaEnabled: false
            )
        )
        XCTAssertFalse(
            NexusSendAvailabilityPolicy.permits(
                networkId: .taira,
                nexusEnabled: true,
                sendsEnabled: true,
                tairaEnabled: false
            )
        )
        XCTAssertTrue(
            NexusSendAvailabilityPolicy.permits(
                networkId: .taira,
                nexusEnabled: true,
                sendsEnabled: true,
                tairaEnabled: true
            )
        )
        XCTAssertFalse(
            NexusSendAvailabilityPolicy.permits(
                networkId: .taira,
                nexusEnabled: false,
                sendsEnabled: true,
                tairaEnabled: true
            )
        )
    }

    func testProductionMutationSessionRequiresFreshLiveConfigInCurrentProcess() {
        let session = ProductionRemoteCapabilitySession.shared
        session.invalidate()
        defer { session.invalidate() }

        XCTAssertFalse(
            session.permitsMutation(
                localQualification: true,
                capability: .nexusSends
            )
        )

        let refreshToken = session.beginLiveRefresh()
        var permittedDuringPublication = true
        session.publishFreshConfig(
            refreshToken,
            nexusSends: true,
            polkamarktMutations: true
        ) {
            permittedDuringPublication = session.permitsMutation(
                localQualification: true,
                capability: .nexusSends
            )
        }
        XCTAssertFalse(permittedDuringPublication)
        XCTAssertTrue(
            session.permitsMutation(
                localQualification: true,
                capability: .nexusSends
            )
        )
        XCTAssertFalse(
            session.permitsMutation(
                localQualification: false,
                capability: .nexusSends
            )
        )
        XCTAssertTrue(
            session.permitsMutation(
                localQualification: true,
                capability: .polkamarktMutations
            )
        )

        let staleToken = session.beginLiveRefresh()
        let currentToken = session.beginLiveRefresh()
        XCTAssertFalse(
            session.publishFreshConfig(
                staleToken,
                nexusSends: true,
                polkamarktMutations: true,
                publication: {}
            )
        )
        XCTAssertTrue(
            session.publishFreshConfig(
                currentToken,
                nexusSends: false,
                polkamarktMutations: true,
                publication: {}
            )
        )
        XCTAssertFalse(
            session.permitsMutation(
                localQualification: true,
                capability: .nexusSends
            )
        )

        session.invalidate()
        XCTAssertFalse(
            session.permitsMutation(
                localQualification: true,
                capability: .nexusSends
            )
        )
    }

    func testPIMobileFlagsCannotEnableUnqualifiedMutationsOrOverrideTairaChoice() {
        let settings = InMemorySettingsManager()
        let config = PIMobileConfig(
            blockExplorerUrl: URL(
                string: "https://sorametrics.org/tx/%7Btransaction%7D"
            )!,
            substrateTypesUrl: URL(string: "https://example.org/types.json"),
            soracard: false,
            nodes: [
                PIMobileChainNode(
                    name: "SORA",
                    address: URL(string: "wss://mof2.sora.org")!
                )
            ],
            nexusAvailable: true,
            nexusSendsAvailable: true,
            polkamarktVisible: true,
            polkamarktMutationsAvailable: true,
            tairaDefaultVisible: false
        )

        settings.applyPIMobileConfig(
            config,
            refreshToken:
                ProductionRemoteCapabilitySession.shared.beginLiveRefresh()
        )

        XCTAssertTrue(settings.nexusEnabled)
        XCTAssertFalse(settings.nexusSendsEnabled)
        XCTAssertTrue(settings.polkamarktEnabled)
        XCTAssertFalse(settings.polkamarktMutationsEnabled)
        XCTAssertFalse(config.typedAccountBalancesAvailable)
        XCTAssertFalse(settings.isTairaEnabled)

        settings.isTairaEnabled = true
        XCTAssertEqual(
            settings.string(
                for: SettingsKey.tairaExplicitPreference.rawValue
            ),
            "enabled"
        )
        XCTAssertEqual(
            settings.bool(for: SettingsKey.tairaPreferenceWasSet.rawValue),
            true
        )
        settings.applyPIMobileConfig(
            config,
            refreshToken:
                ProductionRemoteCapabilitySession.shared.beginLiveRefresh()
        )
        XCTAssertTrue(settings.isTairaEnabled)

        settings.isTairaEnabled = false
        settings.set(
            value: true,
            for: SettingsKey.tairaRemoteDefault.rawValue
        )
        XCTAssertEqual(
            settings.string(
                for: SettingsKey.tairaExplicitPreference.rawValue
            ),
            "disabled"
        )
        XCTAssertFalse(settings.isTairaEnabled)

        let retainedLegacyChoice = InMemorySettingsManager()
        retainedLegacyChoice.set(
            value: false,
            for: SettingsKey.tairaEnabled.rawValue
        )
        retainedLegacyChoice.set(
            value: true,
            for: SettingsKey.tairaPreferenceWasSet.rawValue
        )
        retainedLegacyChoice.set(
            value: true,
            for: SettingsKey.tairaRemoteDefault.rawValue
        )
        XCTAssertFalse(retainedLegacyChoice.isTairaEnabled)

        retainedLegacyChoice.set(
            value: "malformed",
            for: SettingsKey.tairaExplicitPreference.rawValue
        )
        XCTAssertFalse(retainedLegacyChoice.isTairaEnabled)

        let wrongTypedAtomicChoice = InMemorySettingsManager()
        wrongTypedAtomicChoice.set(
            anyValue: 1,
            for: SettingsKey.tairaExplicitPreference.rawValue
        )
        XCTAssertFalse(wrongTypedAtomicChoice.isTairaEnabled)

        let incompleteLegacyChoice = InMemorySettingsManager()
        incompleteLegacyChoice.set(
            value: true,
            for: SettingsKey.tairaPreferenceWasSet.rawValue
        )
        XCTAssertFalse(incompleteLegacyChoice.isTairaEnabled)
        incompleteLegacyChoice.set(
            anyValue: "false",
            for: SettingsKey.tairaEnabled.rawValue
        )
        XCTAssertFalse(incompleteLegacyChoice.isTairaEnabled)

        let partialLegacyValue = InMemorySettingsManager()
        partialLegacyValue.set(
            value: false,
            for: SettingsKey.tairaEnabled.rawValue
        )
        partialLegacyValue.set(
            value: true,
            for: SettingsKey.tairaRemoteDefault.rawValue
        )
        XCTAssertFalse(partialLegacyValue.isTairaEnabled)

        let falseLegacyMarker = InMemorySettingsManager()
        falseLegacyMarker.set(
            value: false,
            for: SettingsKey.tairaPreferenceWasSet.rawValue
        )
        falseLegacyMarker.set(
            value: true,
            for: SettingsKey.tairaRemoteDefault.rawValue
        )
        XCTAssertFalse(falseLegacyMarker.isTairaEnabled)

        let wrongTypedLegacyMarker = InMemorySettingsManager()
        wrongTypedLegacyMarker.set(
            anyValue: "true",
            for: SettingsKey.tairaPreferenceWasSet.rawValue
        )
        wrongTypedLegacyMarker.set(
            value: true,
            for: SettingsKey.tairaRemoteDefault.rawValue
        )
        XCTAssertFalse(wrongTypedLegacyMarker.isTairaEnabled)

        let wrongTypedRemoteDefault = InMemorySettingsManager()
        wrongTypedRemoteDefault.set(
            anyValue: "true",
            for: SettingsKey.tairaRemoteDefault.rawValue
        )
        XCTAssertFalse(wrongTypedRemoteDefault.isTairaEnabled)
    }

    func testPIMobileConfigRejectsConflictingMutationFlagsBeforeCacheEligibility() {
        let config = PIMobileConfig(
            blockExplorerUrl: URL(
                string: "https://sorametrics.org/tx/%7Btransaction%7D"
            )!,
            substrateTypesUrl: URL(string: "https://example.org/types.json"),
            soracard: false,
            nodes: [
                PIMobileChainNode(
                    name: "SORA",
                    address: URL(string: "wss://mof2.sora.org")!
                )
            ],
            nexusAvailable: false,
            nexusSendsAvailable: true,
            polkamarktVisible: true,
            polkamarktMutationsAvailable: false,
            tairaDefaultVisible: true
        )

        XCTAssertThrowsError(
            try PIIndexerClient.validateMobileConfig(config)
        )
    }

    func testGraphQLQuantityRequiresExactDecimalStringWireFormat() throws {
        let quantity = try JSONDecoder().decode(
            PIQuantity.self,
            from: Data(#""123456789.123456789123456789""#.utf8)
        )
        XCTAssertEqual(quantity.rawValue, "123456789.123456789123456789")
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PIQuantity.self,
                from: Data("123456789.123456789123456789".utf8)
            )
        )
    }

    func testGraphQLErrorNeverRetainsOrSurfacesRawServerMessage() {
        let sensitive = "query rejected for 5ExampleWalletAddress"
        let decoded = PIGraphQLError(
            message: sensitive,
            path: [.string("account")]
        )
        XCTAssertEqual(decoded.message, sensitive)

        let surfaced = PIIndexerError.graphQLErrors
        XCTAssertFalse(surfaced.localizedDescription.contains(sensitive))
        XCTAssertFalse(String(describing: surfaced).contains(sensitive))
    }

    func testPIProtocolErrorsNeverRetainRawQuantityOrCursorText() {
        // These compile as values only while the cases are payload-free. Raw
        // quantities and opaque account-bound cursors must not survive in
        // Error reflection used by generic diagnostics.
        let errors: [PIIndexerError] = [
            .invalidQuantity,
            .repeatedCursor,
        ]

        XCTAssertEqual(errors.count, 2)
        XCTAssertEqual(
            errors[0].errorDescription,
            "PI returned an invalid precise quantity."
        )
        XCTAssertEqual(
            errors[1].errorDescription,
            "PI repeated a pagination cursor."
        )
    }

    func testPIHealthAcceptsNumericAndCanonicalQuotedIntegerWireForms() throws {
        let decoder = JSONDecoder()
        let numericData = piHealthPayload(quotedIntegers: false)
        let quotedData = piHealthPayload(quotedIntegers: true)

        try PIStrictJSONAdmission.validate(
            piHealthAdmissionEnvelope(numericData)
        )
        try PIStrictJSONAdmission.validate(
            piHealthAdmissionEnvelope(quotedData)
        )
        let numeric = try decoder.decode(PIHealth.self, from: numericData)
        let quoted = try decoder.decode(PIHealth.self, from: quotedData)

        XCTAssertEqual(quoted, numeric)
        XCTAssertEqual(numeric.latestIndexedBlock, 123)
        XCTAssertEqual(numeric.latestIndexedAt, 2_000_000)
        XCTAssertEqual(numeric.workerLatestFinalizedBlock, 125)
        XCTAssertEqual(numeric.workerLatestIndexedBlock, 123)
        XCTAssertEqual(numeric.workerLag, 2)
        XCTAssertEqual(
            numeric.workerLastSuccessfulIndexTimestamp,
            2_000_000
        )
        XCTAssertEqual(numeric.workerLastErrorTimestamp, 1_999_999)
        XCTAssertNoThrow(
            try PIIndexerClient.validateHealth(
                numeric,
                nowEpochSeconds: 2_000_000
            )
        )

        // PIResponseCache encodes the bounded projection as JSON integers.
        // Those bytes must continue to pass the same strict admission and
        // decode path after an app restart.
        let cached = try JSONEncoder().encode(quoted)
        try PIStrictJSONAdmission.validate(
            piHealthAdmissionEnvelope(cached, cacheField: true)
        )
        XCTAssertEqual(
            try decoder.decode(PIHealth.self, from: cached),
            quoted
        )
    }

    func testPIHealthIntegerWireRejectsNoncanonicalOverflowAndTypedValues()
        throws
    {
        let decoder = JSONDecoder()
        let invalidTokens = [
            "2e0",
            "2.0",
            "-1",
            "true",
            #""02""#,
            "[]",
            "{}",
        ]

        for token in invalidTokens {
            let data = piHealthPayload(
                quotedIntegers: false,
                workerLagToken: token
            )
            XCTAssertThrowsError(
                try {
                    try PIStrictJSONAdmission.validate(
                        piHealthAdmissionEnvelope(data)
                    )
                    _ = try decoder.decode(PIHealth.self, from: data)
                }()
            ) { error in
                guard case PIIndexerError.invalidQuantity = error else {
                    return XCTFail("Unexpected error class: \(error)")
                }
                XCTAssertFalse(String(describing: error).contains(token))
            }
        }

        let unbounded = String(repeating: "9", count: 1_024)
        let unboundedData = piHealthPayload(
            quotedIntegers: false,
            workerLagToken: unbounded
        )
        // The strict parser admits the arbitrary-precision canonical lexeme;
        // the health domain then rejects its bounded Int projection without
        // retaining the raw value in the error.
        XCTAssertNoThrow(
            try PIStrictJSONAdmission.validate(
                piHealthAdmissionEnvelope(unboundedData)
            )
        )
        XCTAssertThrowsError(
            try decoder.decode(PIHealth.self, from: unboundedData)
        ) { error in
            guard case PIIndexerError.invalidQuantity = error else {
                return XCTFail("Unexpected error class: \(error)")
            }
            XCTAssertFalse(String(describing: error).contains(unbounded))
        }

        let oversized = String(
            repeating: "9",
            count: PIStrictJSONAdmission.maximumHealthIntegerBytes + 1
        )
        let oversizedData = piHealthPayload(
            quotedIntegers: false,
            workerLagToken: oversized
        )
        XCTAssertThrowsError(
            try PIStrictJSONAdmission.validate(
                piHealthAdmissionEnvelope(oversizedData)
            )
        ) { error in
            guard case PIIndexerError.invalidQuantity = error else {
                return XCTFail("Unexpected error class: \(error)")
            }
            XCTAssertFalse(String(describing: error).contains(oversized))
        }

        let nullableData = piHealthPayload(
            quotedIntegers: false,
            workerLastErrorTimestampToken: "null"
        )
        try PIStrictJSONAdmission.validate(
            piHealthAdmissionEnvelope(nullableData)
        )
        let nullable = try decoder.decode(
            PIHealth.self,
            from: nullableData
        )
        XCTAssertNil(nullable.workerLastErrorTimestamp)
    }

    func testPIHealthAcceptsDeployedWorkerFinalizedCheckpointContract() {
        let now = 2_000_000
        let deployedHealth = PIHealth(
            ok: true,
            repositoryReady: true,
            service: "polkaswap-indexer",
            serviceId: "pi.soramitsu.io",
            schemaVersion: 1,
            ecosystem: "sora2",
            chainId: "sora:mainnet",
            network: "mainnet",
            publicBaseUrl: PIIndexerClient.endpoint,
            readOnly: true,
            genesisHash: nil,
            latestIndexedBlock: nil,
            latestIndexedBlockHash: nil,
            latestIndexedAt: nil,
            workerAvailable: true,
            workerReady: true,
            workerReadinessReason: nil,
            workerLifecycle: "running",
            workerStartupComplete: true,
            workerLatestFinalizedBlock: 100,
            workerLatestIndexedBlock: 100,
            workerLag: 0,
            workerLastSuccessfulIndexTimestamp: now,
            workerLastError: nil,
            workerLastErrorTimestamp: nil
        )

        XCTAssertNoThrow(
            try PIIndexerClient.validateHealth(
                deployedHealth,
                nowEpochSeconds: now
            )
        )
    }

    private func piHealthPayload(
        quotedIntegers: Bool,
        workerLagToken: String? = nil,
        workerLastErrorTimestampToken: String? = nil
    ) -> Data {
        func integer(_ value: Int) -> String {
            quotedIntegers ? #""\#(value)""# : String(value)
        }

        return Data(
            """
            {
              "ok": true,
              "repositoryReady": true,
              "service": "polkaswap-indexer",
              "serviceId": "pi.soramitsu.io",
              "schemaVersion": 1,
              "ecosystem": "sora2",
              "chainId": "sora:mainnet",
              "network": "mainnet",
              "publicBaseUrl": "https://pi.soramitsu.io/graphql",
              "readOnly": true,
              "genesisHash": null,
              "latestIndexedBlock": \(integer(123)),
              "latestIndexedBlockHash": null,
              "latestIndexedAt": \(integer(2_000_000)),
              "workerAvailable": true,
              "workerReady": true,
              "workerReadinessReason": null,
              "workerLifecycle": "running",
              "workerStartupComplete": true,
              "workerLatestFinalizedBlock": \(integer(125)),
              "workerLatestIndexedBlock": \(integer(123)),
              "workerLag": \(workerLagToken ?? integer(2)),
              "workerLastSuccessfulIndexTimestamp": \(integer(2_000_000)),
              "workerLastError": "transient",
              "workerLastErrorTimestamp": \(
                  workerLastErrorTimestampToken ?? integer(1_999_999)
              )
            }
            """.utf8
        )
    }

    private func piHealthAdmissionEnvelope(
        _ payload: Data,
        cacheField: Bool = false
    ) -> Data {
        var envelope = Data(
            (cacheField ? #"{"health":"# : #"{"_health":"#).utf8
        )
        envelope.append(payload)
        envelope.append(Data("}".utf8))
        return envelope
    }

    func testPIHealthAcceptsOnlyFreshCoherentFinalizedIdentity() throws {
        let now = 2_000_000
        let health = PIHealth(
            ok: true,
            repositoryReady: true,
            service: "polkaswap-indexer",
            serviceId: "pi.soramitsu.io",
            schemaVersion: 1,
            ecosystem: "sora2",
            chainId: "sora:mainnet",
            network: "mainnet",
            publicBaseUrl: PIIndexerClient.endpoint,
            readOnly: true,
            genesisHash: PIIndexerClient.soraMainnetGenesis,
            latestIndexedBlock: 123,
            latestIndexedBlockHash:
                "0x1111111111111111111111111111111111111111111111111111111111111111",
            latestIndexedAt: now,
            workerAvailable: true,
            workerReady: true,
            workerReadinessReason: nil,
            workerLifecycle: "running",
            workerStartupComplete: true,
            workerLatestFinalizedBlock: 125,
            workerLatestIndexedBlock: 123,
            workerLag: 2,
            workerLastSuccessfulIndexTimestamp: now,
            workerLastError: nil,
            workerLastErrorTimestamp: nil
        )

        XCTAssertNoThrow(
            try PIIndexerClient.validateHealth(
                health,
                nowEpochSeconds: now
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateHealth(
                health,
                nowEpochSeconds: now + 301
            )
        ) { error in
            guard case PIIndexerError.staleCheckpoint = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPIResponseRequiresStablePreflightAndPostflightCheckpoint() throws {
        let now = 2_000_000
        let health = PIHealth(
            ok: true,
            repositoryReady: true,
            service: "polkaswap-indexer",
            serviceId: "pi.soramitsu.io",
            schemaVersion: 1,
            ecosystem: "sora2",
            chainId: "sora:mainnet",
            network: "mainnet",
            publicBaseUrl: PIIndexerClient.endpoint,
            readOnly: true,
            genesisHash: PIIndexerClient.soraMainnetGenesis,
            latestIndexedBlock: 123,
            latestIndexedBlockHash:
                "0x1111111111111111111111111111111111111111111111111111111111111111",
            latestIndexedAt: now,
            workerAvailable: true,
            workerReady: true,
            workerReadinessReason: nil,
            workerLifecycle: "running",
            workerStartupComplete: true,
            workerLatestFinalizedBlock: 125,
            workerLatestIndexedBlock: 123,
            workerLag: 2,
            workerLastSuccessfulIndexTimestamp: now,
            workerLastError: nil,
            workerLastErrorTimestamp: nil
        )

        XCTAssertNoThrow(
            try PIIndexerClient.validateStableResponseCheckpoint(
                preflight: health,
                postflight: health
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateStableResponseCheckpoint(
                preflight: health,
                postflight: PIHealth(
                    ok: health.ok,
                    repositoryReady: health.repositoryReady,
                    service: health.service,
                    serviceId: health.serviceId,
                    schemaVersion: health.schemaVersion,
                    ecosystem: health.ecosystem,
                    chainId: health.chainId,
                    network: health.network,
                    publicBaseUrl: health.publicBaseUrl,
                    readOnly: health.readOnly,
                    genesisHash: health.genesisHash,
                    latestIndexedBlock: 124,
                    latestIndexedBlockHash: health.latestIndexedBlockHash,
                    latestIndexedAt: health.latestIndexedAt,
                    workerAvailable: health.workerAvailable,
                    workerReady: health.workerReady,
                    workerReadinessReason: health.workerReadinessReason,
                    workerLifecycle: health.workerLifecycle,
                    workerStartupComplete: health.workerStartupComplete,
                    workerLatestFinalizedBlock: 125,
                    workerLatestIndexedBlock: 124,
                    workerLag: 1,
                    workerLastSuccessfulIndexTimestamp:
                        health.workerLastSuccessfulIndexTimestamp,
                    workerLastError: health.workerLastError,
                    workerLastErrorTimestamp:
                        health.workerLastErrorTimestamp
                )
            )
        ) { error in
            guard case PIIndexerError.staleCheckpoint = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPIResponseRowsCannotExceedAttributedCheckpoint() {
        let qualification = makePIQualification(indexedBlock: 100)

        XCTAssertNoThrow(
            try PIIndexerClient.validateResponseHeights(
                [nil, 0, 100],
                qualification: qualification
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateResponseHeights(
                [101],
                qualification: qualification
            )
        ) { error in
            guard case PIIndexerError.staleCheckpoint = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPIReturnedPolkamarktRowsAreBoundToRequestedIdentity() throws {
        let decoder = JSONDecoder()
        let wrongSnapshot = try decoder.decode(
            PIMarketSnapshot.self,
            from: Data(
                #"{"id":"snapshot","marketId":8,"timestamp":100,"type":"DEFAULT","blockHeight":100}"#.utf8
            )
        )
        let wrongPosition = try decoder.decode(
            PIAccountPosition.self,
            from: Data(
                #"{"id":"position","account":"cnOther","marketId":7,"market":{"id":"market","marketId":7,"status":"Open","updatedAtBlock":100}}"#.utf8
            )
        )
        let blockHash =
            "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
        let extrinsicHash =
            "0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
        let wrongNestedTrade = try decoder.decode(
            PIAccountTrade.self,
            from: Data(
                """
                {"id":"trade","account":"cnAccount","marketId":7,"blockNumber":100,"blockHash":"\(blockHash)","extrinsicHash":"\(extrinsicHash)","market":{"id":"market","marketId":8,"status":"Open","updatedAtBlock":100}}
                """.utf8
            )
        )

        XCTAssertThrowsError(
            try PIIndexerClient.validateMarketSnapshots(
                [wrongSnapshot],
                marketId: 7
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountPositions(
                [wrongPosition],
                account: "cnAccount"
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountTrades(
                [wrongNestedTrade],
                account: "cnAccount"
            )
        )
    }

    func testPIPolkamarktRowsRejectNegativeAccountAndSnapshotQuantities() throws {
        let decoder = JSONDecoder()
        let snapshot = try decoder.decode(
            PIMarketSnapshot.self,
            from: Data(
                #"{"id":"snapshot","marketId":7,"timestamp":100,"type":"DEFAULT","blockHeight":100,"liquidityUSD":"-1"}"#.utf8
            )
        )
        let position = try decoder.decode(
            PIAccountPosition.self,
            from: Data(
                #"{"id":"position","account":"cnAccount","marketId":7,"shares":"-1","market":{"id":"market","marketId":7,"status":"Open","updatedAtBlock":100}}"#.utf8
            )
        )
        let blockHash =
            "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
        let extrinsicHash =
            "0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
        let trade = try decoder.decode(
            PIAccountTrade.self,
            from: Data(
                """
                {"id":"trade","account":"cnAccount","marketId":7,"feeUsd":"-1","blockNumber":100,"blockHash":"\(blockHash)","extrinsicHash":"\(extrinsicHash)","market":{"id":"market","marketId":7,"status":"Open","updatedAtBlock":100}}
                """.utf8
            )
        )

        XCTAssertThrowsError(
            try PIIndexerClient.validateMarketSnapshots(
                [snapshot],
                marketId: 7
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountPositions(
                [position],
                account: "cnAccount"
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountTrades(
                [trade],
                account: "cnAccount"
            )
        )
    }

    func testPIMarketSnapshotsRequireCoordinatesAndCanonicalOrdering() throws {
        let decoder = JSONDecoder()
        let first = try decoder.decode(
            PIMarketSnapshot.self,
            from: Data(
                #"{"id":"snapshot-a","marketId":7,"timestamp":100,"blockHeight":100,"type":"DEFAULT","status":"Open","probability":"50.66","priceYes":"0.5066","priceNo":"0.4934"}"#.utf8
            )
        )
        let second = try decoder.decode(
            PIMarketSnapshot.self,
            from: Data(
                #"{"id":"snapshot-b","marketId":7,"timestamp":101,"blockHeight":101,"type":"DEFAULT","status":"Open"}"#.utf8
            )
        )
        let missingTimestamp = try decoder.decode(
            PIMarketSnapshot.self,
            from: Data(
                #"{"id":"snapshot-missing","marketId":7,"blockHeight":100,"type":"DEFAULT"}"#.utf8
            )
        )
        let unsupportedBlockSeries = try decoder.decode(
            PIMarketSnapshot.self,
            from: Data(
                #"{"id":"snapshot-block","marketId":7,"timestamp":102,"blockHeight":102,"type":"BLOCK"}"#.utf8
            )
        )
        let invalidPercentage = try decoder.decode(
            PIMarketSnapshot.self,
            from: Data(
                #"{"id":"snapshot-invalid","marketId":7,"timestamp":102,"blockHeight":102,"type":"DEFAULT","probability":"100.01"}"#.utf8
            )
        )

        XCTAssertNoThrow(
            try PIIndexerClient.validateMarketSnapshots(
                [first, second],
                marketId: 7
            )
        )
        XCTAssertEqual(
            try XCTUnwrap(first.probability?.percentageFractionForRendering),
            0.5066,
            accuracy: 0.000_000_1
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateMarketSnapshots(
                [second, first],
                marketId: 7
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateMarketSnapshots(
                [missingTimestamp],
                marketId: 7
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateMarketSnapshots(
                [unsupportedBlockSeries],
                marketId: 7
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateMarketSnapshots(
                [invalidPercentage],
                marketId: 7
            )
        )
    }

    func testPIMarketCatalogBindsTypedStatusAndQuantitySemantics() throws {
        let decoder = JSONDecoder()
        let valid = try decoder.decode(
            PIMarket.self,
            from: Data(
                #"{"id":"market","marketId":7,"status":"Open","probability":"50.66","priceYes":"0.5066","priceNo":"0.4934","marginalYesPriceBps":5066,"updatedAtBlock":100}"#.utf8
            )
        )
        let negativeLiquidity = try decoder.decode(
            PIMarket.self,
            from: Data(
                #"{"id":"market","marketId":7,"status":"Open","liquidityUSD":"-1","updatedAtBlock":100}"#.utf8
            )
        )
        let invalidUnitPrice = try decoder.decode(
            PIMarket.self,
            from: Data(
                #"{"id":"market","marketId":7,"status":"Open","probability":"50","priceYes":"1.01","updatedAtBlock":100}"#.utf8
            )
        )
        let duplicateRuntimeMarket = try decoder.decode(
            PIMarket.self,
            from: Data(
                #"{"id":"different-row-id","marketId":7,"status":"Open","updatedAtBlock":101}"#.utf8
            )
        )
        let distinctRuntimeMarket = try decoder.decode(
            PIMarket.self,
            from: Data(
                #"{"id":"distinct-market","marketId":8,"status":"Open","updatedAtBlock":101}"#.utf8
            )
        )

        XCTAssertNoThrow(
            try PIIndexerClient.validateMarkets(
                [valid],
                expectedStatus: .open
            )
        )
        XCTAssertEqual(
            try XCTUnwrap(valid.probability?.percentageFractionForRendering),
            0.5066,
            accuracy: 0.000_000_1
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateMarkets(
                [valid],
                expectedStatus: .locked
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateMarkets(
                [negativeLiquidity],
                expectedStatus: .open
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateMarkets(
                [invalidUnitPrice],
                expectedStatus: .open
            )
        )
        XCTAssertNoThrow(
            try PIIndexerClient.validateUniqueRuntimeMarketIds(
                [valid, distinctRuntimeMarket]
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateUniqueRuntimeMarketIds(
                [valid, duplicateRuntimeMarket]
            )
        )
    }

    func testPIMarketIdentifiersCoverExactRuntimeUInt32Domain() throws {
        let decoder = JSONDecoder()
        let maximum = try decoder.decode(
            PIMarket.self,
            from: Data(
                #"{"id":"market-max","marketId":4294967295,"conditionId":4294967295,"closeBlock":4294967295,"status":"Open","updatedAtBlock":100}"#.utf8
            )
        )
        let overflow = try decoder.decode(
            PIMarket.self,
            from: Data(
                #"{"id":"market-overflow","marketId":4294967296,"status":"Open","updatedAtBlock":100}"#.utf8
            )
        )
        let maximumSnapshot = try decoder.decode(
            PIMarketSnapshot.self,
            from: Data(
                #"{"id":"snapshot-max","marketId":4294967295,"timestamp":100,"blockHeight":100,"type":"DEFAULT"}"#.utf8
            )
        )
        let closeBlockOverflow = try decoder.decode(
            PIMarket.self,
            from: Data(
                #"{"id":"market-close-overflow","marketId":1,"closeBlock":4294967296,"status":"Open","updatedAtBlock":100}"#.utf8
            )
        )

        XCTAssertNoThrow(
            try PIIndexerClient.validateMarkets(
                [maximum],
                expectedStatus: .open
            )
        )
        XCTAssertNoThrow(
            try PIIndexerClient.validateMarketSnapshots(
                [maximumSnapshot],
                marketId: 4_294_967_295
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateMarkets(
                [overflow],
                expectedStatus: .open
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateMarkets(
                [closeBlockOverflow],
                expectedStatus: .open
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateMarketSnapshots(
                [maximumSnapshot],
                marketId: 4_294_967_296
            )
        )
    }

    func testPIPolkamarktAccountRowsRequireCheckpointCoordinatesBeforeUse()
        throws
    {
        let decoder = JSONDecoder()
        let blockHash =
            "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
        let extrinsicHash =
            "0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
        let position = try decoder.decode(
            PIAccountPosition.self,
            from: Data(
                #"{"id":"position","account":"cnAccount","marketId":7,"shares":"1","market":{"id":"market","marketId":7,"status":"Open","updatedAtBlock":100}}"#.utf8
            )
        )
        let trade = try decoder.decode(
            PIAccountTrade.self,
            from: Data(
                """
                {"id":"trade","account":"cnAccount","marketId":7,"marketIds":[7,8],"shares":"1","blockNumber":100,"blockHash":"\(blockHash)","extrinsicHash":"\(extrinsicHash)","market":{"id":"market","marketId":7,"status":"Open","updatedAtBlock":100}}
                """.utf8
            )
        )
        let mismatchedBatch = try decoder.decode(
            PIAccountTrade.self,
            from: Data(
                """
                {"id":"trade-batch-mismatch","account":"cnAccount","marketId":7,"marketIds":[8,7],"shares":"1","blockNumber":100,"blockHash":"\(blockHash)","extrinsicHash":"\(extrinsicHash)","market":{"id":"market","marketId":7,"status":"Open","updatedAtBlock":100}}
                """.utf8
            )
        )
        let ordinaryTrade = try decoder.decode(
            PIAccountTrade.self,
            from: Data(
                """
                {"id":"trade-ordinary","account":"cnAccount","marketId":7,"marketIds":[],"shares":"1","blockNumber":100,"blockHash":"\(blockHash)","extrinsicHash":"\(extrinsicHash)","market":{"id":"market","marketId":7,"status":"Open","updatedAtBlock":100}}
                """.utf8
            )
        )
        let legacyCachedTrade = try decoder.decode(
            PIAccountTrade.self,
            from: Data(
                """
                {"id":"trade-legacy-cache","account":"cnAccount","marketId":7,"shares":"1","blockNumber":100,"blockHash":"\(blockHash)","extrinsicHash":"\(extrinsicHash)","market":{"id":"market","marketId":7,"status":"Open","updatedAtBlock":100}}
                """.utf8
            )
        )
        let missingBlockHash = try decoder.decode(
            PIAccountTrade.self,
            from: Data(
                #"{"id":"trade-missing","account":"cnAccount","marketId":7,"shares":"1","blockNumber":100,"extrinsicHash":"0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","market":{"id":"market","marketId":7,"status":"Open","updatedAtBlock":100}}"#.utf8
            )
        )

        XCTAssertNoThrow(
            try PIIndexerClient.validateAccountPositions(
                [position],
                account: "cnAccount"
            )
        )
        XCTAssertNoThrow(
            try PIIndexerClient.validateAccountTrades(
                [trade],
                account: "cnAccount"
            )
        )
        XCTAssertEqual(trade.marketIds, [7, 8])
        XCTAssertTrue(trade.includesMarket(7))
        XCTAssertTrue(trade.includesMarket(8))
        XCTAssertFalse(trade.includesMarket(9))
        XCTAssertNoThrow(
            try PIIndexerClient.validateAccountTrades(
                [ordinaryTrade],
                account: "cnAccount"
            )
        )
        XCTAssertTrue(ordinaryTrade.includesMarket(7))
        XCTAssertNil(legacyCachedTrade.marketIds)
        XCTAssertNoThrow(
            try PIIndexerClient.validateAccountTrades(
                [legacyCachedTrade],
                account: "cnAccount"
            )
        )
        XCTAssertTrue(legacyCachedTrade.includesMarket(7))
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountTrades(
                [mismatchedBatch],
                account: "cnAccount"
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountTrades(
                [missingBlockHash],
                account: "cnAccount"
            )
        )
    }

    func testPIReturnedHistoryRowsAreBoundToRequestedAccountAndHash() throws {
        let decoder = JSONDecoder()
        let transactionHash =
            "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let anotherHash =
            "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        let blockHash =
            "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
        let wrongAccount = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {"id":"\(transactionHash)","timestamp":1,"address":"cnOther","blockHeight":100,"blockHash":"\(blockHash)","networkFee":"0","execution":{"success":true}}
                """.utf8
            )
        )
        let wrongHash = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {"id":"\(anotherHash)","timestamp":1,"address":"cnAccount","blockHeight":100,"blockHash":"\(blockHash)","networkFee":"0","execution":{"success":true}}
                """.utf8
            )
        )
        let syntheticBridgeEvent = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {"id":"\(transactionHash)-mint","timestamp":1,"address":"cnAccount","blockHeight":100,"blockHash":"\(blockHash)","networkFee":"0","execution":{"success":true}}
                """.utf8
            )
        )
        let canonicalDuplicate = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {"id":"\(anotherHash.uppercased())","timestamp":1,"address":"cnAccount","blockHeight":100,"blockHash":"\(blockHash)","networkFee":"0","execution":{"success":true}}
                """.utf8
            )
        )
        let controlledSyntheticIdentifier = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {"id":"bridge\\u0000mint","timestamp":1,"address":"cnAccount","blockHeight":100,"blockHash":"\(blockHash)","networkFee":"0","execution":{"success":true}}
                """.utf8
            )
        )

        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountHistory(
                [wrongAccount],
                account: "cnAccount"
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountHistory(
                [wrongHash],
                account: "cnAccount",
                expectedTransactionHashes: [transactionHash]
            )
        )
        XCTAssertNoThrow(
            try PIIndexerClient.validateAccountHistory(
                [syntheticBridgeEvent],
                account: "cnAccount"
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountHistory(
                [syntheticBridgeEvent],
                account: "cnAccount",
                expectedTransactionHashes: [transactionHash]
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountHistory(
                [wrongHash, canonicalDuplicate],
                account: "cnAccount"
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountHistory(
                [controlledSyntheticIdentifier],
                account: "cnAccount"
            )
        )
        XCTAssertEqual(
            PIHistoryCheckpointValidator.canonicalHistoryIdentifier(
                transactionHash.uppercased()
            ),
            transactionHash
        )
        XCTAssertEqual(
            PIHistoryCheckpointValidator.canonicalHistoryIdentifier(
                syntheticBridgeEvent.id
            ),
            syntheticBridgeEvent.id
        )
        XCTAssertNil(
            PIHistoryCheckpointValidator.canonicalHistoryIdentifier(
                String(repeating: "0", count: 64)
            )
        )
    }

    func testPIHistoryRequiresCanonicalChainCoordinatesBeforeUse() throws {
        let decoder = JSONDecoder()
        let transactionHash =
            "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let blockHash =
            "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
        let valid = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {
                  "id":"\(transactionHash)",
                  "timestamp":1,
                  "address":"cnAccount",
                  "blockHeight":100,
                  "blockHash":"\(blockHash)",
                  "networkFee":"1",
                  "execution":{"success":true}
                }
                """.utf8
            )
        )
        let missingBlockHash = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {
                  "id":"\(transactionHash)",
                  "timestamp":1,
                  "address":"cnAccount",
                  "blockHeight":100,
                  "networkFee":"0",
                  "execution":{"success":true}
                }
                """.utf8
            )
        )

        XCTAssertNoThrow(
            try PIIndexerClient.validateAccountHistory(
                [valid],
                account: "cnAccount",
                expectedTransactionHashes: [transactionHash]
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountHistory(
                [missingBlockHash],
                account: "cnAccount"
            )
        )

        let missingExecution = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {
                  "id":"\(transactionHash)",
                  "timestamp":1,
                  "address":"cnAccount",
                  "blockHeight":100,
                  "blockHash":"\(blockHash)",
                  "networkFee":"0"
                }
                """.utf8
            )
        )
        let negativeFee = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {
                  "id":"\(transactionHash)",
                  "timestamp":1,
                  "address":"cnAccount",
                  "blockHeight":100,
                  "blockHash":"\(blockHash)",
                  "networkFee":"-1",
                  "execution":{"success":true}
                }
                """.utf8
            )
        )
        let decimalFee = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {
                  "id":"\(transactionHash)",
                  "timestamp":1,
                  "address":"cnAccount",
                  "blockHeight":100,
                  "blockHash":"\(blockHash)",
                  "networkFee":"0.1",
                  "execution":{"success":true}
                }
                """.utf8
            )
        )
        let missingTimestamp = try decoder.decode(
            PIHistoryElement.self,
            from: Data(
                """
                {
                  "id":"\(transactionHash)",
                  "address":"cnAccount",
                  "blockHeight":100,
                  "blockHash":"\(blockHash)",
                  "networkFee":"0",
                  "execution":{"success":true}
                }
                """.utf8
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountHistory(
                [missingExecution],
                account: "cnAccount"
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountHistory(
                [negativeFee],
                account: "cnAccount"
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountHistory(
                [decimalFee],
                account: "cnAccount"
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateAccountHistory(
                [missingTimestamp],
                account: "cnAccount"
            )
        )
    }

    func testPIPolkamarktSignalsRejectNegativeCountsAndDuplicateLabels() throws {
        let signals = try JSONDecoder().decode(
            PIPolkamarktSignals.self,
            from: Data(
                """
                {
                  "totalVolumeUsd":"1",
                  "activeMarkets":-1,
                  "activeAccounts":1,
                  "liquidityUsd":"1",
                  "liquiditySeries":[
                    {"label":"same","value":"1"},
                    {"label":"same","value":"2"}
                  ],
                  "answerBreakdown":[]
                }
                """.utf8
            )
        )

        XCTAssertThrowsError(
            try PIIndexerClient.validatePolkamarktSignals(signals)
        )

        let negativeVolume = try JSONDecoder().decode(
            PIPolkamarktSignals.self,
            from: Data(
                """
                {
                  "totalVolumeUsd":"-1",
                  "activeMarkets":1,
                  "activeAccounts":1,
                  "liquidityUsd":"1",
                  "liquiditySeries":[],
                  "answerBreakdown":[]
                }
                """.utf8
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validatePolkamarktSignals(negativeVolume)
        )

        let validAccuracy = try JSONDecoder().decode(
            PIPolkamarktSignals.self,
            from: Data(
                #"{"totalVolumeUsd":"1","activeMarkets":1,"activeAccounts":1,"liquidityUsd":"1","liquiditySeries":[],"answerBreakdown":[],"accuracySummary":{"accuracyPercent":99.5}}"#.utf8
            )
        )
        XCTAssertNoThrow(
            try PIIndexerClient.validatePolkamarktSignals(validAccuracy)
        )
        XCTAssertEqual(validAccuracy.accuracySummary?.accuracyPercent, 99.5)

        let invalidAccuracy = try JSONDecoder().decode(
            PIPolkamarktSignals.self,
            from: Data(
                #"{"totalVolumeUsd":"1","activeMarkets":1,"activeAccounts":1,"liquidityUsd":"1","liquiditySeries":[],"answerBreakdown":[],"accuracySummary":{"accuracyPercent":100.1}}"#.utf8
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validatePolkamarktSignals(invalidAccuracy)
        )
    }

    func testPIAssetPoolAndRewardRowsRejectInvalidSemantics() throws {
        let decoder = JSONDecoder()
        let asset = try decoder.decode(
            PIAsset.self,
            from: Data(#"{"id":"xor","priceUSD":"-1"}"#.utf8)
        )
        let pool = try decoder.decode(
            PIPoolXYK.self,
            from: Data(
                #"{"id":"pool","strategicBonusApy":"-0.1"}"#.utf8
            )
        )
        let reward = try decoder.decode(
            PIReferrerReward.self,
            from: Data(
                #"{"id":"reward","referrer":"cnOther","blockHeight":"100","amount":"1"}"#.utf8
            )
        )
        let presentationAsset = try decoder.decode(
            PIAsset.self,
            from: Data(
                #"{"id":"xor","priceChangeDay":-4.5,"priceChangeWeek":3,"volumeDayUSD":"999999999999999999999.1"}"#.utf8
            )
        )

        XCTAssertThrowsError(try PIIndexerClient.validateAssets([asset]))
        XCTAssertNoThrow(
            try PIIndexerClient.validateAssets([presentationAsset])
        )
        XCTAssertEqual(presentationAsset.priceChangeDay, -4.5)
        XCTAssertEqual(
            presentationAsset.volumeDayUSD?.rawValue,
            "999999999999999999999.1"
        )
        XCTAssertThrowsError(
            try decoder.decode(
                PIAsset.self,
                from: Data(
                    #"{"id":"xor","volumeDayUSD":1.5}"#.utf8
                )
            )
        )
        XCTAssertThrowsError(try PIIndexerClient.validatePools([pool]))
        XCTAssertThrowsError(
            try PIIndexerClient.validateReferrerRewards(
                [reward],
                account: "cnAccount",
                qualification: makePIQualification(indexedBlock: 100)
            )
        )
        XCTAssertEqual(
            try PIMarketCapLiquidityValidator.validatedWireValue(
                try PIQuantity("123")
            ),
            "123"
        )
        XCTAssertThrowsError(
            try PIMarketCapLiquidityValidator.validatedWireValue(nil)
        )
        XCTAssertThrowsError(
            try PIMarketCapLiquidityValidator.validatedWireValue(
                try PIQuantity("1.5")
            )
        )
        XCTAssertThrowsError(
            try PIMarketCapLiquidityValidator.validatedWireValue(
                try PIQuantity("-1")
            )
        )
        XCTAssertNoThrow(
            try PIMarketCapCatalogValidator.requireExactRequestedCoverage(
                requestedAssetIDs: ["xor", "val"],
                returnedAssetIDs: ["val", "xor"]
            )
        )
        XCTAssertThrowsError(
            try PIMarketCapCatalogValidator.requireExactRequestedCoverage(
                requestedAssetIDs: ["xor", "val"],
                returnedAssetIDs: ["xor"]
            )
        )
        XCTAssertThrowsError(
            try PIMarketCapCatalogValidator.requireExactRequestedCoverage(
                requestedAssetIDs: ["xor"],
                returnedAssetIDs: ["xor", "xor"]
            )
        )
        XCTAssertThrowsError(
            try PIMarketCapCatalogValidator.requireExactRequestedCoverage(
                requestedAssetIDs: [],
                returnedAssetIDs: []
            )
        )
        XCTAssertThrowsError(
            try PIMarketCapCatalogValidator.requireExactRequestedCoverage(
                requestedAssetIDs: ["xor", "xor"],
                returnedAssetIDs: ["xor"]
            )
        )
        XCTAssertThrowsError(
            try PIMarketCapCatalogValidator.validatedRequestedAssetIDs([
                String(
                    repeating: "x",
                    count: PIMarketCapCatalogValidator.maximumAssetIDBytes + 1
                ),
            ])
        )
        XCTAssertThrowsError(
            try PIMarketCapCatalogValidator.validatedRequestedAssetIDs([
                "xor\nval",
            ])
        )
        XCTAssertThrowsError(
            try PIMarketCapCatalogValidator.validatedRequestedAssetIDs(
                (0 ... PIMarketCapCatalogValidator.maximumRequestedAssetCount)
                    .map { "asset-\($0)" }
            )
        )
    }

    func testPIPendingLookupRequiresBoundedUniqueCanonicalHashes() throws {
        let hash =
            "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        XCTAssertEqual(
            try PIIndexerClient.validatedPendingTransactionHashes([hash]),
            [hash]
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validatedPendingTransactionHashes([hash, hash])
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validatedPendingTransactionHashes(
                Array(repeating: hash, count: 101)
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validatedPendingTransactionHashes(["invalid"])
        )
    }

    private func makePIQualification(
        indexedBlock: Int
    ) -> PIReadQualification {
        let now = Int(Date().timeIntervalSince1970)
        return PIReadQualification(
            health: PIHealth(
                ok: true,
                repositoryReady: true,
                service: "polkaswap-indexer",
                serviceId: "pi.soramitsu.io",
                schemaVersion: 1,
                ecosystem: "sora2",
                chainId: "sora:mainnet",
                network: "mainnet",
                publicBaseUrl: PIIndexerClient.endpoint,
                readOnly: true,
                genesisHash: PIIndexerClient.soraMainnetGenesis,
                latestIndexedBlock: indexedBlock,
                latestIndexedBlockHash:
                    "0x1111111111111111111111111111111111111111111111111111111111111111",
                latestIndexedAt: now,
                workerAvailable: true,
                workerReady: true,
                workerReadinessReason: nil,
                workerLifecycle: "running",
                workerStartupComplete: true,
                workerLatestFinalizedBlock: indexedBlock,
                workerLatestIndexedBlock: indexedBlock,
                workerLag: 0,
                workerLastSuccessfulIndexTimestamp: now,
                workerLastError: nil,
                workerLastErrorTimestamp: nil
            ),
            source: .live
        )
    }

    func testPIHistoryBindsAccountCheckpointAndCanonicalBlockHash()
        async throws
    {
        let address = "cnVudGltZS1hY2NvdW50"
        let blockHash =
            "0x1111111111111111111111111111111111111111111111111111111111111111"
        let item = PIHistoryElement(
            id:
                "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            type: "TRANSFER",
            timestamp: 1,
            blockHash: blockHash,
            blockHeight: 42,
            module: "assets",
            method: "transfer",
            address: address,
            networkFee: try PIQuantity("1"),
            execution: .object(["success": .bool(true)]),
            data: nil,
            dataFrom: nil,
            dataTo: nil,
            dataAssets: nil,
            callNames: nil,
            calls: nil
        )

        try await PIHistoryCheckpointValidator.validate(
            [item],
            expectedAddress: address,
            finalizedCheckpoint: 42,
            canonicalBlockHash: { height in
                XCTAssertEqual(height, 42)
                return blockHash
            }
        )
        let dataFromItem = PIHistoryElement(
            id: String(repeating: "BB", count: 32),
            type: "TRANSFER",
            timestamp: 2,
            blockHash: blockHash,
            blockHeight: 42,
            module: "assets",
            method: "transfer",
            address: nil,
            networkFee: try PIQuantity("1"),
            execution: .object(["success": .bool(true)]),
            data: nil,
            dataFrom: address,
            dataTo: nil,
            dataAssets: nil,
            callNames: nil,
            calls: nil
        )
        try await PIHistoryCheckpointValidator.validate(
            [item, dataFromItem],
            expectedAddress: address,
            finalizedCheckpoint: 42,
            canonicalBlockHash: { _ in blockHash }
        )
        let missingExecution = PIHistoryElement(
            id: item.id,
            type: item.type,
            timestamp: item.timestamp,
            blockHash: item.blockHash,
            blockHeight: item.blockHeight,
            module: item.module,
            method: item.method,
            address: item.address,
            networkFee: item.networkFee,
            execution: nil,
            data: item.data,
            dataFrom: item.dataFrom,
            dataTo: item.dataTo,
            dataAssets: item.dataAssets,
            callNames: item.callNames,
            calls: item.calls
        )
        let missingExecutionResolverCalled = LockedInvocationFlag()
        do {
            try await PIHistoryCheckpointValidator.validate(
                [missingExecution],
                expectedAddress: address,
                finalizedCheckpoint: 42,
                canonicalBlockHash: { _ in
                    missingExecutionResolverCalled.markCalled()
                    return blockHash
                }
            )
            XCTFail("History without a boolean execution result was accepted")
        } catch {
            XCTAssertTrue(error is PIIndexerError)
        }
        XCTAssertFalse(missingExecutionResolverCalled.value)
        let missingTimestamp = PIHistoryElement(
            id: item.id,
            type: item.type,
            timestamp: nil,
            blockHash: item.blockHash,
            blockHeight: item.blockHeight,
            module: item.module,
            method: item.method,
            address: item.address,
            networkFee: item.networkFee,
            execution: item.execution,
            data: item.data,
            dataFrom: item.dataFrom,
            dataTo: item.dataTo,
            dataAssets: item.dataAssets,
            callNames: item.callNames,
            calls: item.calls
        )
        let missingTimestampResolverCalled = LockedInvocationFlag()
        do {
            try await PIHistoryCheckpointValidator.validate(
                [missingTimestamp],
                expectedAddress: address,
                finalizedCheckpoint: 42,
                canonicalBlockHash: { _ in
                    missingTimestampResolverCalled.markCalled()
                    return blockHash
                }
            )
            XCTFail("History without a timestamp was accepted")
        } catch {
            XCTAssertTrue(error is PIIndexerError)
        }
        XCTAssertFalse(missingTimestampResolverCalled.value)
        try await PIHistoryCheckpointValidator.validate(
            [],
            expectedAddress: address,
            finalizedCheckpoint: 42,
            indexedCheckpointHash: blockHash,
            canonicalBlockHash: { height in
                XCTAssertEqual(height, 42)
                return blockHash
            }
        )

        do {
            try await PIHistoryCheckpointValidator.validate(
                [item],
                expectedAddress: "different-account",
                finalizedCheckpoint: 42,
                canonicalBlockHash: { _ in blockHash }
            )
            XCTFail("Cross-account PI history was accepted")
        } catch {
            XCTAssertTrue(error is PIIndexerError)
        }
        do {
            try await PIHistoryCheckpointValidator.validate(
                [item],
                expectedAddress: address,
                finalizedCheckpoint: 41,
                canonicalBlockHash: { _ in blockHash }
            )
            XCTFail("History above the finalized checkpoint was accepted")
        } catch {
            XCTAssertTrue(error is PIIndexerError)
        }
        do {
            try await PIHistoryCheckpointValidator.validate(
                [item],
                expectedAddress: address,
                finalizedCheckpoint: 42,
                canonicalBlockHash: { _ in
                    "0x2222222222222222222222222222222222222222222222222222222222222222"
                }
            )
            XCTFail("Non-canonical PI block hash was accepted")
        } catch {
            XCTAssertTrue(error is PIIndexerError)
        }
        do {
            try await PIHistoryCheckpointValidator.validate(
                [],
                expectedAddress: address,
                finalizedCheckpoint: 42,
                indexedCheckpointHash: blockHash,
                canonicalBlockHash: { _ in
                    "0x2222222222222222222222222222222222222222222222222222222222222222"
                }
            )
            XCTFail("Non-canonical PI indexed checkpoint hash was accepted")
        } catch {
            XCTAssertTrue(error is PIIndexerError)
        }
        let syntheticIdentityItem = PIHistoryElement(
            id: "\(item.id)-mint",
            type: item.type,
            timestamp: item.timestamp,
            blockHash: item.blockHash,
            blockHeight: item.blockHeight,
            module: item.module,
            method: item.method,
            address: item.address,
            networkFee: item.networkFee,
            execution: item.execution,
            data: item.data,
            dataFrom: item.dataFrom,
            dataTo: item.dataTo,
            dataAssets: item.dataAssets,
            callNames: item.callNames,
            calls: item.calls
        )
        try await PIHistoryCheckpointValidator.validate(
            [syntheticIdentityItem],
            expectedAddress: address,
            finalizedCheckpoint: 42,
            canonicalBlockHash: { _ in blockHash }
        )

        let malformedIdentityItem = PIHistoryElement(
            id: " transaction-1",
            type: item.type,
            timestamp: item.timestamp,
            blockHash: item.blockHash,
            blockHeight: item.blockHeight,
            module: item.module,
            method: item.method,
            address: item.address,
            networkFee: item.networkFee,
            execution: item.execution,
            data: item.data,
            dataFrom: item.dataFrom,
            dataTo: item.dataTo,
            dataAssets: item.dataAssets,
            callNames: item.callNames,
            calls: item.calls
        )
        do {
            try await PIHistoryCheckpointValidator.validate(
                [malformedIdentityItem],
                expectedAddress: address,
                finalizedCheckpoint: 42,
                canonicalBlockHash: { _ in blockHash }
            )
            XCTFail("Malformed PI transaction identity was accepted")
        } catch {
            XCTAssertTrue(error is PIIndexerError)
        }
    }

    func testPIHistoryRejectsIncoherentPageMetadataAndDuplicateIDs()
        throws
    {
        let address = "cnVudGltZS1hY2NvdW50"
        let item = PIHistoryElement(
            id:
                "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            type: "TRANSFER",
            timestamp: 1,
            blockHash:
                "0x1111111111111111111111111111111111111111111111111111111111111111",
            blockHeight: 42,
            module: "assets",
            method: "transfer",
            address: address,
            networkFee: try PIQuantity("1"),
            execution: .object(["success": .bool(true)]),
            data: nil,
            dataFrom: nil,
            dataTo: nil,
            dataAssets: nil,
            callNames: nil,
            calls: nil
        )
        let terminalPage = PIPageInfo(
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: nil,
            endCursor: nil
        )
        let valid = PIConnection(
            nodes: [item],
            edges: nil,
            pageInfo: terminalPage,
            totalCount: 1
        )
        XCTAssertEqual(
            try PIHistoryPageValidator.validate(
                valid,
                hasPriorPage: false,
                pageSize: 100
            ),
            [item]
        )

        let duplicate = PIConnection(
            nodes: [item, item],
            edges: nil,
            pageInfo: terminalPage,
            totalCount: 2
        )
        XCTAssertThrowsError(
            try PIHistoryPageValidator.validate(
                duplicate,
                hasPriorPage: false,
                pageSize: 100
            )
        )

        let emptyRepeatedPage = PIConnection<PIHistoryElement>(
            nodes: [],
            edges: nil,
            pageInfo: PIPageInfo(
                hasNextPage: true,
                hasPreviousPage: false,
                startCursor: nil,
                endCursor: "cursor-1"
            ),
            totalCount: 2
        )
        XCTAssertThrowsError(
            try PIHistoryPageValidator.validate(
                emptyRepeatedPage,
                hasPriorPage: false,
                pageSize: 100
            )
        )

        let missingRepresentation = PIConnection<PIHistoryElement>(
            nodes: nil,
            edges: nil,
            pageInfo: terminalPage,
            totalCount: 0
        )
        XCTAssertThrowsError(
            try PIHistoryPageValidator.validate(
                missingRepresentation,
                hasPriorPage: false,
                pageSize: 100
            )
        )

        let truncatedTerminalPage = PIConnection(
            nodes: [item],
            edges: nil,
            pageInfo: terminalPage,
            totalCount: 2
        )
        XCTAssertThrowsError(
            try PIHistoryPageValidator.validate(
                truncatedTerminalPage,
                hasPriorPage: false,
                pageSize: 100
            )
        )
    }

    func testPolkamarktIntegerAmountAndSlippageVectors() throws {
        let oneAndAHalf = try PolkamarktAmountCodec.parse("1.5")
        XCTAssertEqual(
            oneAndAHalf,
            try XCTUnwrap(BigUInt("1500000000000000000"))
        )
        XCTAssertEqual(PolkamarktAmountCodec.format(oneAndAHalf), "1.5")
        XCTAssertEqual(
            try PolkamarktQuoteValidator.minimumOutput(
                quoteOutput: 1_000_000,
                slippageBasisPoints: 50
            ),
            995_000
        )
        XCTAssertEqual(
            PolkamarktRuntimeContract.defaultSlippageBasisPoints,
            50
        )
        XCTAssertEqual(
            PolkamarktRuntimeContract.maximumBatchClaims,
            24
        )
        XCTAssertThrowsError(
            try PolkamarktQuoteValidator.minimumOutput(
                quoteOutput: 1_000_000,
                slippageBasisPoints: 0
            )
        )
        XCTAssertThrowsError(
            try PolkamarktQuoteValidator.minimumOutput(
                quoteOutput: 1_000_000,
                slippageBasisPoints: 1_001
            )
        )
        XCTAssertThrowsError(try PolkamarktAmountCodec.parse("0"))
        XCTAssertThrowsError(try PolkamarktAmountCodec.parse("1e3"))
        XCTAssertThrowsError(
            try PolkamarktAmountCodec.parse(
                String(repeating: "1", count: 4_097)
            )
        )

        XCTAssertNoThrow(
            try PolkamarktQuoteValidator.validateOutcome(
                "Yes",
                expected: .yes
            )
        )
        XCTAssertNoThrow(
            try PolkamarktQuoteValidator.validateOutcome(
                "No",
                expected: .no
            )
        )
        let nonCanonicalOutcomes: [(String, PolkamarktOutcome)] = [
            ("yes", .yes),
            ("YES", .yes),
            ("no", .no),
            ("NO", .no),
            (" Yes", .yes),
            ("No ", .no)
        ]
        for (wrongCaseOrShape, expected) in nonCanonicalOutcomes {
            XCTAssertThrowsError(
                try PolkamarktQuoteValidator.validateOutcome(
                    wrongCaseOrShape,
                    expected: expected
                ),
                "Wrong-case runtime outcome projection was accepted: \(wrongCaseOrShape)"
            )
        }
    }

    func testPolkaswapSlippageUsesExactBasisPointVectors() throws {
        let tenth = try XCTUnwrap(PolkaswapSlippage(contextValue: "0.1"))
        let half = try XCTUnwrap(PolkaswapSlippage(contextValue: "0.50"))
        let one = try XCTUnwrap(PolkaswapSlippage(contextValue: "1.0"))

        XCTAssertEqual(tenth.basisPoints, 10)
        XCTAssertEqual(half.basisPoints, 50)
        XCTAssertEqual(one.basisPoints, 100)
        XCTAssertEqual(half.contextValue, "0.5")
        XCTAssertEqual(one.contextValue, "1")
        XCTAssertEqual(
            half.minimumAmount(for: 1),
            try XCTUnwrap(Decimal(string: "0.995"))
        )
        XCTAssertEqual(
            half.maximumAmount(for: 1),
            try XCTUnwrap(Decimal(string: "1.005"))
        )
        XCTAssertEqual(
            try XCTUnwrap(
                half.minimumAmount(for: 1)
                    .toSubstrateAmountRoundingDown(precision: 2)
            ),
            BigUInt(99)
        )
        XCTAssertEqual(
            try XCTUnwrap(
                half.maximumAmount(for: 1)
                    .toSubstrateAmountRoundingUp(precision: 2)
            ),
            BigUInt(101)
        )

        ["0", "-0.5", "10.01", "0.001", "1e0", " 0.5", "٠.٥"].forEach {
            XCTAssertNil(PolkaswapSlippage(contextValue: $0), $0)
        }
    }

    func testPolkaswapDesiredOutputSignsExactMaximumInput() throws {
        let quotedInput = "1.000000000000000001"
        let maxInput = "1.005000000000000001005"
        let info = TransferInfo(
            source: "",
            destination: "output",
            amount: AmountDecimal(string: quotedInput)!,
            asset: "input",
            details: "",
            fees: [],
            context: [
                TransactionContextKeys.transactionType: TransactionType.swap.rawValue,
                TransactionContextKeys.estimatedAmount: "2",
                TransactionContextKeys.marketType: LiquiditySourceType.smart.rawValue,
                TransactionContextKeys.slippage: "0.5",
                TransactionContextKeys.desire: SwapVariant.desiredOutput.rawValue,
                TransactionContextKeys.minMaxValue: maxInput,
                TransactionContextKeys.dex: "0"
            ]
        )

        let amount = try XCTUnwrap(info.amountCall?[.desiredOutput])
        XCTAssertEqual(
            amount.desired,
            try XCTUnwrap(BigUInt("2000000000000000000"))
        )
        XCTAssertEqual(
            amount.slip,
            try XCTUnwrap(BigUInt("1005000000000000002"))
        )

        var malformedContext = try XCTUnwrap(info.context)
        malformedContext[TransactionContextKeys.slippage] = "5e-1"
        let malformed = TransferInfo(
            source: info.source,
            destination: info.destination,
            amount: info.amount,
            asset: info.asset,
            details: info.details,
            fees: info.fees,
            context: malformedContext
        )
        XCTAssertNil(malformed.amountCall)

        var weakenedContext = try XCTUnwrap(info.context)
        weakenedContext[TransactionContextKeys.minMaxValue] = quotedInput
        let weakened = TransferInfo(
            source: info.source,
            destination: info.destination,
            amount: info.amount,
            asset: info.asset,
            details: info.details,
            fees: info.fees,
            context: weakenedContext
        )
        XCTAssertNil(weakened.amountCall)
    }

    func testPolkaswapDesiredInputSignsExactMinimumOutput() throws {
        let info = TransferInfo(
            source: "",
            destination: "output",
            amount: AmountDecimal(string: "1")!,
            asset: "input",
            details: "",
            fees: [],
            context: [
                TransactionContextKeys.transactionType: TransactionType.swap.rawValue,
                TransactionContextKeys.estimatedAmount: "2",
                TransactionContextKeys.marketType: LiquiditySourceType.smart.rawValue,
                TransactionContextKeys.slippage: "0.50",
                TransactionContextKeys.desire: SwapVariant.desiredInput.rawValue,
                TransactionContextKeys.minMaxValue: "1.99",
                TransactionContextKeys.dex: "0"
            ]
        )

        let amount = try XCTUnwrap(info.amountCall?[.desiredInput])
        XCTAssertEqual(
            amount.desired,
            try XCTUnwrap(BigUInt("1000000000000000000"))
        )
        XCTAssertEqual(
            amount.slip,
            try XCTUnwrap(BigUInt("1990000000000000000"))
        )
    }

    func testDemeterFarmSliderQuantizesBeforeTransactionMath() throws {
        let quarter = try XCTUnwrap(FarmShareSelection(percent: 25))
        let rounded = try XCTUnwrap(
            FarmShareSelection(percent: Decimal(string: "33.335")!)
        )

        XCTAssertEqual(quarter.basisPoints, 2_500)
        XCTAssertEqual(quarter.percent, 25)
        XCTAssertEqual(
            quarter.fraction,
            try XCTUnwrap(Decimal(string: "0.25"))
        )
        XCTAssertEqual(
            Decimal(10) * quarter.fraction,
            try XCTUnwrap(Decimal(string: "2.5"))
        )
        XCTAssertEqual(rounded.basisPoints, 3_334)
        XCTAssertNil(FarmShareSelection(percent: -1))
        XCTAssertNil(FarmShareSelection(percent: 101))
    }

    func testLiquidityBatchHistoryPreservesSignedCallOrdering() throws {
        let assetA = String(repeating: "01", count: 32)
        let assetB = String(repeating: "02", count: 32)
        let batchFixture = try makeLiquidityBatchWireFixture(
            assetA: assetA,
            assetB: assetB
        )
        let info = TransferInfo(
            source: assetA,
            destination: assetB,
            amount: AmountDecimal(value: 1),
            asset: assetA,
            details: "",
            fees: [],
            context: [
                TransactionContextKeys.transactionType:
                    TransactionType.liquidityAddNewPool.rawValue
            ]
        )
        let historyItem = try TransactionHistoryItem
            .createFromPreparedLiquidity(
                info,
                transactionHash: Data([0x01]),
                senderAddress: "sender",
                rawFee: "7",
                exactCall: batchFixture.call
            )

        XCTAssertEqual(historyItem.fee, "7")
        XCTAssertEqual(historyItem.txHash, "0x01")
        XCTAssertThrowsError(
            try TransactionHistoryItem.createFromTransferInfo(
                info,
                transactionHash: Data([0x01]),
                senderAddress: "sender",
                networkType: 69,
                addressFactory: SS58AddressFactory()
            )
        )

        XCTAssertTrue(historyItem.callPath.isUtilityBatch)
        let decodedBatch = try JSONDecoder.scaleCompatible().decode(
            RuntimeCall<BatchArgs>.self,
            from: historyItem.call
        )
        XCTAssertEqual(decodedBatch.args.calls.count, 3)
        XCTAssertEqual(
            try decodedBatch.args.calls[0]
                .map(to: RuntimeCall<PairRegisterCall>.self).callName,
            batchFixture.registerCallName
        )
        XCTAssertEqual(
            try decodedBatch.args.calls[1]
                .map(to: RuntimeCall<InitializePoolCall>.self).callName,
            batchFixture.initializeCallName
        )
        let decodedDeposit = try XCTUnwrap(
            AssetTransactionData.depositLiquidityCall(from: historyItem)
        )
        XCTAssertEqual(decodedDeposit.desiredA, 101)
        XCTAssertEqual(decodedDeposit.desiredB, 202)
        XCTAssertEqual(decodedDeposit.minA, 100)
        XCTAssertEqual(decodedDeposit.minB, 200)
    }

    func testLiquidityPairStateResolvesCanonicalMutationMatrix() {
        XCTAssertEqual(
            PoolNetworkState(isPresented: false, isEnabled: false)
                .liquidityAction,
            .registerInitializeAndDeposit
        )
        XCTAssertEqual(
            PoolNetworkState(isPresented: false, isEnabled: true)
                .liquidityAction,
            .initializeAndDeposit
        )
        XCTAssertEqual(
            PoolNetworkState(isPresented: true, isEnabled: true)
                .liquidityAction,
            .deposit
        )
        XCTAssertEqual(
            PoolNetworkState(isPresented: true, isEnabled: false)
                .liquidityAction,
            .reject
        )
    }

    func testLiquidityExactFeeMustRemainWithinReviewedBound() {
        XCTAssertTrue(
            LiquidityFeeQualification.accepts(freshFee: 1, reviewedFee: 1)
        )
        XCTAssertTrue(
            LiquidityFeeQualification.accepts(freshFee: 0.9, reviewedFee: 1)
        )
        XCTAssertFalse(
            LiquidityFeeQualification.accepts(freshFee: 1.1, reviewedFee: 1)
        )
        XCTAssertFalse(
            LiquidityFeeQualification.accepts(freshFee: 0, reviewedFee: 1)
        )
        XCTAssertFalse(
            LiquidityFeeQualification.accepts(freshFee: 1, reviewedFee: 0)
        )

        // Ordinary SORA2 sends intentionally use a stricter contract than
        // liquidity: the fee returned for the exact signed bytes must equal the
        // fee explicitly reviewed by the user in both directions.
        XCTAssertEqual(
            try Sora2TransferFeeQualification.requireExact(
                reviewedFee: 1,
                signedBytesFee: 1
            ),
            1
        )
        XCTAssertThrowsError(
            try Sora2TransferFeeQualification.requireExact(
                reviewedFee: 1,
                signedBytesFee: 0.9
            )
        )
        XCTAssertThrowsError(
            try Sora2TransferFeeQualification.requireExact(
                reviewedFee: 1,
                signedBytesFee: 1.1
            )
        )
        XCTAssertEqual(
            try Sora2SignedFeeRevalidation.requireExact(
                expectedRawFee: "1000000000000000000",
                actualRawFee: "1000000000000000000"
            ).description,
            "1000000000000000000"
        )
        XCTAssertThrowsError(
            try Sora2SignedFeeRevalidation.requireExact(
                expectedRawFee: "1000000000000000000",
                actualRawFee: "999999999999999999"
            )
        )
        XCTAssertThrowsError(
            try Sora2SignedFeeRevalidation.requireExact(
                expectedRawFee: "1000000000000000000",
                actualRawFee: "not-an-integer"
            )
        )
        XCTAssertThrowsError(
            try Sora2LegacyTransferAdmission.requirePreparedPath(
                for: .outgoing
            )
        )
        XCTAssertNoThrow(
            try Sora2LegacyTransferAdmission.requirePreparedPath(for: .swap)
        )

        let xorBalances = [
            BalanceData(
                identifier: WalletAssetId.xor.rawValue,
                balance: AmountDecimal(value: 3)
            )
        ]
        XCTAssertNoThrow(
            try Sora2TransferFeeQualification.requireSufficientBalances(
                amount: 2,
                assetId: WalletAssetId.xor.rawValue,
                exactFee: 1,
                balances: xorBalances
            )
        )
        XCTAssertThrowsError(
            try Sora2TransferFeeQualification.requireSufficientBalances(
                amount: 2.1,
                assetId: WalletAssetId.xor.rawValue,
                exactFee: 1,
                balances: xorBalances
            )
        )
        XCTAssertThrowsError(
            try Sora2TransferFeeQualification.requireSufficientBalances(
                amount: 1,
                assetId: "non-xor-asset",
                exactFee: 1,
                balances: xorBalances
            )
        )
    }

    func testPolkamarktExactSignedFeeMustRemainWithinConfirmedBound()
        throws
    {
        XCTAssertEqual(
            try PolkamarktExactFeeValidator.validate(
                rawFee: "9",
                maximumNetworkFee: 10
            ),
            9
        )
        XCTAssertThrowsError(
            try PolkamarktExactFeeValidator.validate(
                rawFee: "11",
                maximumNetworkFee: 10
            )
        ) { error in
            guard case PolkamarktRuntimeError.staleQuote = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertThrowsError(
            try PolkamarktExactFeeValidator.validate(
                rawFee: "0",
                maximumNetworkFee: 10
            )
        )
        XCTAssertThrowsError(
            try PolkamarktExactFeeValidator.validate(
                rawFee: "not-an-integer",
                maximumNetworkFee: nil
            )
        )
    }

    func testPolkamarktSigningHeadMustMatchTheRevalidatedQuoteHead()
        throws
    {
        let expected = String(repeating: "ab", count: 32)
        XCTAssertNoThrow(
            try PolkamarktSigningHeadValidator.validate(
                expected: "0x\(expected.uppercased())",
                actual: expected
            )
        )
        XCTAssertThrowsError(
            try PolkamarktSigningHeadValidator.validate(
                expected: expected,
                actual: String(repeating: "cd", count: 32)
            )
        ) { error in
            guard case PolkamarktRuntimeError.staleQuote = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRuntimeFeeDetailsRejectsMalformedHexComponents() throws {
        let valid = try JSONDecoder().decode(
            InclusionFeeInfo.self,
            from: Data(
                #"{"inclusionFee":{"baseFee":"0x0","lenFee":"0x2","adjustedWeightFee":"0x3"}}"#.utf8
            )
        )
        XCTAssertEqual(valid.fee, "5")

        let malformedPayloads = [
            #"{"inclusionFee":{"baseFee":"1","lenFee":"0x2","adjustedWeightFee":"0x3"}}"#,
            #"{"inclusionFee":{"baseFee":"0x1","lenFee":"0x","adjustedWeightFee":"0x3"}}"#,
            #"{"inclusionFee":{"baseFee":"0x1","lenFee":"0x2","adjustedWeightFee":"0xzz"}}"#,
            #"{"inclusionFee":{"baseFee":"-0x1","lenFee":"0x2","adjustedWeightFee":"0x3"}}"#,
            #"{"inclusionFee":{"baseFee":"0x1","lenFee":"0x2"}}"#,
            #"{"inclusionFee":{"baseFee":1,"lenFee":"0x2","adjustedWeightFee":"0x3"}}"#
        ]
        for payload in malformedPayloads {
            XCTAssertThrowsError(
                try JSONDecoder().decode(
                    InclusionFeeInfo.self,
                    from: Data(payload.utf8)
                ),
                payload
            )
        }
    }

    func testLocalHistoryUsesFacadeBoundSenderAddress() throws {
        let senderAddress = "bound-signer-address"
        let destination = String(repeating: "03", count: 32)
        let assetId = String(repeating: "04", count: 32)
        let info = TransferInfo(
            source: senderAddress,
            destination: destination,
            amount: AmountDecimal(value: 1),
            asset: assetId,
            details: "",
            fees: [],
            context: [
                TransactionContextKeys.transactionType:
                    TransactionType.outgoing.rawValue
            ]
        )

        let history = try TransactionHistoryItem.createFromTransferInfo(
            info,
            transactionHash: Data([0x01]),
            senderAddress: senderAddress,
            networkType: 69,
            addressFactory: SS58AddressFactory()
        )

        XCTAssertEqual(history.sender, senderAddress)
    }

    func testPolkamarktClaimsBindEveryAccountAndMarketBeforeSigning()
        throws
    {
        func claim(
            marketId: UInt32,
            account: String,
            payout: BigUInt
        ) -> PolkamarktClaimable {
            PolkamarktClaimable(
                marketId: marketId,
                account: account,
                status: "Resolved",
                resolutionOutcome: "Yes",
                yesShares: 0,
                noShares: 0,
                netCollateralPaid: 0,
                traderPayout: payout,
                claimablePayout: payout,
                creatorFees: 0,
                isCreator: false
            )
        }

        let account = "cnV0aW1lLWFjY291bnQ="
        let first = claim(marketId: 7, account: account, payout: 10)
        let second = claim(marketId: 8, account: account, payout: 20)

        XCTAssertEqual(
            try PolkamarktClaimValidator.validated(
                first,
                account: account,
                marketId: 7
            ),
            first
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.validated(
                first,
                account: "different-account",
                marketId: 7
            )
        )
        XCTAssertNoThrow(
            try PolkamarktClaimValidator.requireTraderPayouts(
                [first, second],
                account: account,
                marketIds: [7, 8]
            )
        )
        XCTAssertEqual(
            try PolkamarktClaimValidator.reviewedClaims(
                [second, first],
                account: account,
                requestedMarketIds: [7, 8]
            ),
            [first, second]
        )
        XCTAssertEqual(
            try PolkamarktClaimValidator.reviewedClaims(
                [first],
                account: account,
                requestedMarketIds: [7, 8]
            ),
            [first],
            "A runtime review may omit a requested market with no position"
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.reviewedClaims(
                [first, first],
                account: account,
                requestedMarketIds: [7, 8]
            )
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.reviewedClaims(
                [first],
                account: "different-account",
                requestedMarketIds: [7, 8]
            )
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.reviewedClaims(
                [claim(marketId: 9, account: account, payout: 10)],
                account: account,
                requestedMarketIds: [7, 8]
            )
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.requireTraderPayouts(
                [first],
                account: account,
                marketIds: [7, 8]
            )
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.requireTraderPayouts(
                [first, first],
                account: account,
                marketIds: [7, 7]
            )
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.requireTraderPayouts(
                [claim(marketId: 9, account: account, payout: 0)],
                account: account,
                marketIds: [9]
            )
        )
        var openClaim = claim(
            marketId: 10,
            account: account,
            payout: 10
        )
        openClaim = PolkamarktClaimable(
            marketId: openClaim.marketId,
            account: openClaim.account,
            status: "Open",
            resolutionOutcome: openClaim.resolutionOutcome,
            yesShares: openClaim.yesShares,
            noShares: openClaim.noShares,
            netCollateralPaid: openClaim.netCollateralPaid,
            traderPayout: openClaim.traderPayout,
            claimablePayout: openClaim.claimablePayout,
            creatorFees: openClaim.creatorFees,
            isCreator: openClaim.isCreator
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.requireTraderPayouts(
                [openClaim],
                account: account,
                marketIds: [10]
            )
        )

        let creatorClaim = PolkamarktClaimable(
            marketId: 11,
            account: account,
            status: "Resolved",
            resolutionOutcome: "Yes",
            yesShares: 0,
            noShares: 0,
            netCollateralPaid: 0,
            traderPayout: 0,
            claimablePayout: 0,
            creatorFees: 25,
            isCreator: true
        )
        XCTAssertNoThrow(
            try PolkamarktClaimValidator.requireCreatorFees(
                creatorClaim,
                account: account,
                marketId: 11
            )
        )
        let openCreatorClaim = PolkamarktClaimable(
            marketId: creatorClaim.marketId,
            account: creatorClaim.account,
            status: "Open",
            resolutionOutcome: creatorClaim.resolutionOutcome,
            yesShares: creatorClaim.yesShares,
            noShares: creatorClaim.noShares,
            netCollateralPaid: creatorClaim.netCollateralPaid,
            traderPayout: creatorClaim.traderPayout,
            claimablePayout: creatorClaim.claimablePayout,
            creatorFees: creatorClaim.creatorFees,
            isCreator: creatorClaim.isCreator
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.requireCreatorFees(
                openCreatorClaim,
                account: account,
                marketId: 11
            )
        )

        let reviewedHash = "0x" + String(repeating: "ab", count: 32)
        let traderAuthorization = try PolkamarktClaimValidator
            .reviewedTraderAuthorization(
                claims: [second, first],
                account: account,
                source: .reviewedPositions,
                finalizedBlockHash: reviewedHash
            )
        XCTAssertEqual(traderAuthorization.marketIds, [7, 8])
        XCTAssertEqual(traderAuthorization.claims, [first, second])
        XCTAssertEqual(traderAuthorization.source, .reviewedPositions)
        XCTAssertNoThrow(
            try PolkamarktClaimValidator.requireFreshAuthorization(
                traderAuthorization,
                freshClaims: [second, first]
            )
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.requireFreshAuthorization(
                traderAuthorization,
                freshClaims: [
                    first,
                    claim(marketId: 8, account: account, payout: 21)
                ]
            )
        ) { error in
            guard case PolkamarktRuntimeError.staleClaim = error else {
                return XCTFail("Unexpected stale-claim error: \(error)")
            }
        }
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.requireFreshAuthorization(
                traderAuthorization,
                freshClaims: [first]
            )
        ) { error in
            guard case PolkamarktRuntimeError.staleClaim = error else {
                return XCTFail("Unexpected vanished-claim error: \(error)")
            }
        }
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.reviewedTraderAuthorization(
                claims: [first],
                account: account,
                source: .selectedDetail,
                finalizedBlockHash: reviewedHash.uppercased()
            )
        )
        XCTAssertThrowsError(
            try PolkamarktClaimValidator.reviewedTraderAuthorization(
                claims: [first],
                account: account,
                source: .reviewedPositions,
                finalizedBlockHash: reviewedHash
            )
        )
        let creatorAuthorization = try PolkamarktClaimValidator
            .reviewedCreatorAuthorization(
                claim: creatorClaim,
                account: account,
                finalizedBlockHash: reviewedHash
            )
        XCTAssertEqual(creatorAuthorization.source, .selectedDetail)
        XCTAssertNoThrow(
            try PolkamarktClaimValidator.requireFreshAuthorization(
                creatorAuthorization,
                freshClaims: [creatorClaim]
            )
        )
    }

    func testPolkamarktTransactionHashRequiresExactOptionalPrefixAnd32Bytes() {
        let lower = String(repeating: "ab", count: 32)
        let upper = lower.uppercased()

        XCTAssertEqual(PolkamarktTransactionHash.normalized(lower), lower)
        XCTAssertEqual(
            PolkamarktTransactionHash.normalized("0x\(upper)"),
            lower
        )
        XCTAssertEqual(
            PolkamarktTransactionHash.normalized("0X\(upper)"),
            lower
        )
        XCTAssertNil(
            PolkamarktTransactionHash.normalized(
                "0x\(String(repeating: "a", count: 63))"
            )
        )
        XCTAssertNil(
            PolkamarktTransactionHash.normalized(
                "0x\(String(repeating: "a", count: 32))0x" +
                    String(repeating: "a", count: 32)
            )
        )
        XCTAssertNil(
            PolkamarktTransactionHash.normalized(
                String(repeating: "g", count: 64)
            )
        )
        XCTAssertNil(
            PolkamarktTransactionHash.normalized(
                String(repeating: "0", count: 64)
            )
        )
        XCTAssertNil(PolkamarktTransactionHash.normalized(" \(lower)"))
    }

    func testPolkamarktExternalLinksRequireCredentialFreeHTTPS() {
        XCTAssertEqual(
            PolkamarktExternalLinkPolicy.validated(
                URL(string: "https://example.com/market/evidence")
            ),
            URL(string: "https://example.com/market/evidence")
        )
        XCTAssertNil(
            PolkamarktExternalLinkPolicy.validated(
                URL(string: "http://example.com/market/evidence")
            )
        )
        XCTAssertNil(
            PolkamarktExternalLinkPolicy.validated(
                URL(string: "sora://wallet/send")
            )
        )
        XCTAssertNil(
            PolkamarktExternalLinkPolicy.validated(
                URL(string: "https://user:secret@example.com/evidence")
            )
        )
    }

    func testRetainedNetworkDetailsRejectAChangedSelectedWallet() throws {
        XCTAssertEqual(MainTabBarAccountRebindPolicy.expectedTabCount, 5)
        XCTAssertFalse(
            MainTabBarAccountRebindPolicy
                .requiresRecoveryAfterRebuildFailure(
                    boundWalletId: "wallet-a",
                    selectedWalletId: "wallet-a"
                )
        )
        XCTAssertTrue(
            MainTabBarAccountRebindPolicy
                .requiresRecoveryAfterRebuildFailure(
                    boundWalletId: "wallet-a",
                    selectedWalletId: "wallet-b"
                )
        )
        XCTAssertTrue(
            MainTabBarAccountRebindPolicy
                .requiresRecoveryAfterRebuildFailure(
                    boundWalletId: "wallet-a",
                    selectedWalletId: nil
                )
        )
        XCTAssertTrue(
            MainTabBarAccountRebindPolicy
                .requiresRecoveryAfterRebuildFailure(
                    boundWalletId: nil,
                    selectedWalletId: nil
                )
        )
        XCTAssertTrue(
            MainTabBarAccountRebindPolicy
                .requiresRecoveryAfterRebuildFailure(
                    boundWalletId: "wallet-a",
                    selectedWalletId: ""
                )
        )
        XCTAssertTrue(
            MainTabBarAccountRebindPolicy.canPresentAccountBoundRoute(
                boundWalletId: "wallet-a",
                selectedWalletId: "wallet-a",
                routeWalletId: "wallet-a",
                recoveryActive: false
            )
        )
        XCTAssertFalse(
            MainTabBarAccountRebindPolicy.canPresentAccountBoundRoute(
                boundWalletId: "wallet-b",
                selectedWalletId: "wallet-b",
                routeWalletId: "wallet-a",
                recoveryActive: false
            )
        )
        XCTAssertFalse(
            MainTabBarAccountRebindPolicy.canPresentAccountBoundRoute(
                boundWalletId: "wallet-a",
                selectedWalletId: "wallet-a",
                routeWalletId: "wallet-a",
                recoveryActive: true
            )
        )

        XCTAssertTrue(
            NexusPortfolioPresentationPolicy.detailMatchesSelectedWallet(
                walletId: "wallet-a",
                selectedWalletId: "wallet-a"
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.detailMatchesSelectedWallet(
                walletId: "wallet-a",
                selectedWalletId: "wallet-b"
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.detailMatchesSelectedWallet(
                walletId: "wallet-a",
                selectedWalletId: nil
            )
        )
        XCTAssertTrue(
            NexusPortfolioPresentationPolicy.rowsMatchSelectedWallet(
                walletIds: ["wallet-a", "wallet-a"],
                selectedWalletId: "wallet-a"
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.rowsMatchSelectedWallet(
                walletIds: ["wallet-a"],
                selectedWalletId: "wallet-b"
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.rowsMatchSelectedWallet(
                walletIds: ["wallet-a"],
                selectedWalletId: nil
            )
        )
        XCTAssertTrue(
            NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
                networkId: .minamoto,
                nexusEnabled: true,
                tairaEnabled: false
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
                networkId: .minamoto,
                nexusEnabled: false,
                tairaEnabled: true
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
                networkId: .taira,
                nexusEnabled: true,
                tairaEnabled: false
            )
        )
        let journalRecoveryAccess =
            NexusPortfolioPresentationPolicy.networkDetailAccess(
                networkId: .minamoto,
                nexusEnabled: true,
                tairaEnabled: false,
                mutationCoordinatorAvailable: false
            )
        XCTAssertTrue(journalRecoveryAccess.readsAvailable)
        XCTAssertFalse(journalRecoveryAccess.mutationSurfaceAvailable)
        let qualifiedMutationAccess =
            NexusPortfolioPresentationPolicy.networkDetailAccess(
                networkId: .minamoto,
                nexusEnabled: true,
                tairaEnabled: false,
                mutationCoordinatorAvailable: true
            )
        XCTAssertTrue(qualifiedMutationAccess.readsAvailable)
        XCTAssertTrue(qualifiedMutationAccess.mutationSurfaceAvailable)
        XCTAssertTrue(
            NexusPortfolioPresentationPolicy.mutationIsReady(
                mutationCoordinatorAvailable: true,
                pendingJournalLoaded: true,
                containsAssetRecovery: false,
                currentXorIdentityVerified: true,
                featureEnabled: true
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.mutationIsReady(
                mutationCoordinatorAvailable: false,
                pendingJournalLoaded: true,
                containsAssetRecovery: false,
                currentXorIdentityVerified: true,
                featureEnabled: true
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.mutationIsReady(
                mutationCoordinatorAvailable: true,
                pendingJournalLoaded: false,
                containsAssetRecovery: false,
                currentXorIdentityVerified: true,
                featureEnabled: true
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.mutationIsReady(
                mutationCoordinatorAvailable: true,
                pendingJournalLoaded: true,
                containsAssetRecovery: true,
                currentXorIdentityVerified: true,
                featureEnabled: true
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.mutationIsReady(
                mutationCoordinatorAvailable: true,
                pendingJournalLoaded: true,
                containsAssetRecovery: false,
                currentXorIdentityVerified: false,
                featureEnabled: true
            )
        )
        XCTAssertFalse(
            NexusPortfolioPresentationPolicy.mutationIsReady(
                mutationCoordinatorAvailable: true,
                pendingJournalLoaded: true,
                containsAssetRecovery: false,
                currentXorIdentityVerified: true,
                featureEnabled: false
            )
        )
        func pending(
            id: String,
            assetDefinitionID: String?,
            chainId: UUID? = NexusNetworkConfiguration.minamoto.chainId
        ) throws -> NexusPendingTransaction {
            NexusPendingTransaction(
                id: try XCTUnwrap(UUID(uuidString: id)),
                idempotencyKey: try XCTUnwrap(
                    UUID(uuidString: "00000000-0000-0000-0000-000000000010")
                ),
                walletId: "wallet-a",
                networkId: .minamoto,
                chainId: chainId,
                sender: "sender",
                receiver: "receiver",
                assetDefinitionID: assetDefinitionID,
                amount: try PIQuantity("1"),
                fee: try PIQuantity("0.1"),
                createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 2),
                hash: nil,
                state: .signing,
                terminalBlockHeight: nil,
                errorClass: nil,
                historyReconciledAt: nil
            )
        }
        let currentPending = try pending(
            id: "00000000-0000-0000-0000-000000000001",
            assetDefinitionID: Self.nexusXorAssetDefinitionID
        )
        let reboundPending = try pending(
            id: "00000000-0000-0000-0000-000000000002",
            assetDefinitionID: "61CtjvNd9T3THAR65GsMVHr82Bjc"
        )
        let legacyPending = try pending(
            id: "00000000-0000-0000-0000-000000000003",
            assetDefinitionID: nil
        )
        let unboundChainPending = try pending(
            id: "00000000-0000-0000-0000-000000000004",
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            chainId: nil
        )
        let retiredChainPending = try pending(
            id: "00000000-0000-0000-0000-000000000005",
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            chainId: UUID(uuidString: "809574f5-fee7-5e69-bfcf-52451e42d50f")
        )
        let pendingRows = NexusPortfolioPresentationPolicy.pendingRows(
            [
                currentPending,
                reboundPending,
                legacyPending,
                unboundChainPending,
                retiredChainPending
            ],
            currentXorAssetDefinitionID: Self.nexusXorAssetDefinitionID
        )
        XCTAssertEqual(pendingRows.map(\.kind), [
            .currentXor,
            .assetRecovery,
            .assetRecovery,
            .assetRecovery,
            .assetRecovery
        ])
        XCTAssertTrue(
            NexusPortfolioPresentationPolicy.pendingRows(
                [currentPending],
                currentXorAssetDefinitionID: nil
            ).allSatisfy { $0.kind == .assetRecovery }
        )

        XCTAssertTrue(
            PolkamarktPresentationPolicy.canPresentAccountDetail(
                featureEnabled: true,
                capturedAccount: "wallet-a",
                selectedAccount: "wallet-a"
            )
        )
        XCTAssertFalse(
            PolkamarktPresentationPolicy.canPresentAccountDetail(
                featureEnabled: true,
                capturedAccount: "wallet-a",
                selectedAccount: "wallet-b"
            )
        )
        XCTAssertFalse(
            PolkamarktPresentationPolicy.canPresentAccountDetail(
                featureEnabled: false,
                capturedAccount: "wallet-a",
                selectedAccount: "wallet-a"
            )
        )
        XCTAssertTrue(
            PolkamarktPresentationPolicy.canCommitCatalogAccountState(
                featureEnabled: true,
                capturedAccount: "wallet-a",
                selectedAccount: "wallet-a"
            )
        )
        XCTAssertFalse(
            PolkamarktPresentationPolicy.canCommitCatalogAccountState(
                featureEnabled: true,
                capturedAccount: "wallet-a",
                selectedAccount: "wallet-b"
            )
        )
        XCTAssertTrue(
            PolkamarktPresentationPolicy.matchesOwnerFilter(
                creator: "5ExactCaseSensitiveOwner",
                selectedAccount: "5ExactCaseSensitiveOwner",
                mineOnly: true
            )
        )
        XCTAssertFalse(
            PolkamarktPresentationPolicy.matchesOwnerFilter(
                creator: "5exactCaseSensitiveOwner",
                selectedAccount: "5ExactCaseSensitiveOwner",
                mineOnly: true
            )
        )
        XCTAssertFalse(
            PolkamarktPresentationPolicy.matchesOwnerFilter(
                creator: nil,
                selectedAccount: nil,
                mineOnly: true
            )
        )
        XCTAssertTrue(
            PolkamarktPresentationPolicy.matchesOwnerFilter(
                creator: nil,
                selectedAccount: nil,
                mineOnly: false
            )
        )
    }

    func testEventCenterCompletionRunsAfterQueuedObserverThroughProtocol() {
        let syncQueue = DispatchQueue(
            label: "wallet-modernization.event-center"
        )
        let center: EventCenterProtocol = EventCenter(syncQueue: syncQueue)
        var deliveryOrder: [String] = []
        let observer = AccountSelectionDeliveryObserver {
            deliveryOrder.append("observer")
        }
        center.add(observer: observer, dispatchIn: .main)
        // EventCenter serializes observer registration on this exact queue.
        syncQueue.sync {}

        let completion = expectation(description: "delivery completion")
        center.notify(
            with: SelectedAccountChanged(),
            completionOnMain: {
                deliveryOrder.append("completion")
                completion.fulfill()
            }
        )

        wait(for: [completion], timeout: 2)
        XCTAssertEqual(deliveryOrder, ["observer", "completion"])
    }

    @MainActor
    func testAccountDeletionTargetsContainingModalFromRootAndPushedRoutes() {
        let container = UIViewController()
        let root = UIViewController()
        let navigationController = UINavigationController(
            rootViewController: root
        )
        container.add(navigationController)
        let pushed = UIViewController()
        navigationController.pushViewController(pushed, animated: false)

        XCTAssertTrue(
            AccountOptionsDeletionPresentationPolicy
                .dismissalContainer(for: root) === container
        )
        XCTAssertTrue(
            AccountOptionsDeletionPresentationPolicy
                .dismissalContainer(for: pushed) === container
        )

        let standalone = UIViewController()
        XCTAssertTrue(
            AccountOptionsDeletionPresentationPolicy
                .dismissalContainer(for: standalone) === standalone
        )
    }

    func testPolkamarktPendingJournalUsesCrashDurableProtectedPublication()
        async throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try PolkamarktPendingStore(baseURL: directory)
        let pending = PolkamarktPendingMutation(
            id: UUID(),
            account: "sora-account",
            action: "buy_yes",
            marketIds: [1],
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            extrinsicHash: nil,
            state: .preparing,
            finalizedBlock: nil,
            errorClass: nil
        )

        _ = try await store.put(pending)
        do {
            try await store.requireMutationAdmission(account: pending.account)
            XCTFail("An unresolved durable mutation allowed a second submission")
        } catch {
            guard case PolkamarktRuntimeError.pendingRecovery = error else {
                return XCTFail("Unexpected admission error: \(error)")
            }
        }

        let admissionGate = PolkamarktMutationAdmissionGate()
        let admissionToken = try await admissionGate.acquire(
            account: pending.account
        )
        do {
            _ = try await admissionGate.acquire(account: pending.account)
            XCTFail("Concurrent mutation admission was not rejected")
        } catch {
            guard case PolkamarktRuntimeError.mutationInFlight = error else {
                return XCTFail("Unexpected in-flight error: \(error)")
            }
        }
        do {
            _ = try await admissionGate.acquire(account: "other-account")
            XCTFail("A second account bypassed the app-wide journal gate")
        } catch {
            guard case PolkamarktRuntimeError.mutationInFlight = error else {
                return XCTFail("Unexpected cross-account error: \(error)")
            }
        }
        await admissionGate.release(
            account: pending.account,
            token: admissionToken
        )
        let reacquiredToken = try await admissionGate.acquire(
            account: pending.account
        )
        await admissionGate.release(
            account: pending.account,
            token: reacquiredToken
        )

        let journalDirectory = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
        let journal = journalDirectory.appendingPathComponent(
            "polkamarkt-v1.json"
        )
        let values = try journal.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        XCTAssertEqual(values.isRegularFile, true)
        XCTAssertNotEqual(values.isSymbolicLink, true)
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(
                atPath: journalDirectory.path
            ).contains(where: { $0.hasPrefix(".durable-") })
        )
        let reloaded = try await store.all()
        XCTAssertEqual(reloaded, [pending])

        let sora2Store = try Sora2PendingSubmissionStore(
            baseURL: directory
        )
        let canonicalHash = String(repeating: "56", count: 32)
        let sora2Witness = try sora2Store.stage(
            account: pending.account,
            hash: canonicalHash
        )
        try sora2Store.update(
            sora2Witness,
            state: .submissionUnknown
        )
        var canonicallyFinalized = PolkamarktPendingMutation(
            id: UUID(),
            account: pending.account,
            action: "sell_no",
            marketIds: [2],
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10),
            extrinsicHash: nil,
            state: .preparing,
            finalizedBlock: nil,
            errorClass: nil
        )
        canonicallyFinalized = try await store.put(canonicallyFinalized)
        canonicallyFinalized.extrinsicHash = canonicalHash
        canonicallyFinalized.state = .signedBeforeTransport
        canonicallyFinalized.updatedAt = Date(timeIntervalSince1970: 11)
        canonicallyFinalized = try await store.put(canonicallyFinalized)
        canonicallyFinalized.state = .submissionUnknown
        canonicallyFinalized.updatedAt = Date(timeIntervalSince1970: 12)
        canonicallyFinalized = try await store.put(canonicallyFinalized)
        canonicallyFinalized.state = .finalized
        canonicallyFinalized.finalizedBlock = 42
        canonicallyFinalized.updatedAt = Date(timeIntervalSince1970: 13)
        canonicallyFinalized = try await store.put(canonicallyFinalized)
        let terminalSnapshot = try await store.all()
        XCTAssertEqual(
            terminalSnapshot.first(where: {
                $0.id == canonicallyFinalized.id
            })?.state,
            .finalized
        )
        try await store.acknowledgeDurableCanonicalTerminalWitnesses(
            account: pending.account
        )
        XCTAssertEqual(
            try sora2Store.all().first(where: {
                $0.extrinsicHash == canonicalHash
            })?.state,
            .submitted
        )

        // Reproduce the crash window where feature-terminal publication won,
        // but the retained SORA2 witness was not relaxed before journal
        // capacity was reached. Capacity pruning must keep that sole proof.
        let capacityDirectory = directory.appendingPathComponent(
            "capacity-crash-window",
            isDirectory: true
        )
        let capacityStore = try PolkamarktPendingStore(
            baseURL: capacityDirectory,
            journalMutationLimit: 2
        )
        let capacitySora2Store = try Sora2PendingSubmissionStore(
            baseURL: capacityDirectory
        )
        let protectedHash = String(repeating: "67", count: 32)
        let protectedWitness = try capacitySora2Store.stage(
            account: pending.account,
            hash: protectedHash,
            retainingTransportWitness: true
        )
        var protectedCrashWindowMutation = PolkamarktPendingMutation(
            id: UUID(),
            account: pending.account,
            action: "buy_no",
            marketIds: [3],
            createdAt: Date(timeIntervalSince1970: 20),
            updatedAt: Date(timeIntervalSince1970: 20),
            extrinsicHash: nil,
            state: .preparing,
            finalizedBlock: nil,
            errorClass: nil
        )
        protectedCrashWindowMutation = try await capacityStore.put(
            protectedCrashWindowMutation
        )
        protectedCrashWindowMutation.extrinsicHash = protectedHash
        protectedCrashWindowMutation.state = .signedBeforeTransport
        protectedCrashWindowMutation.updatedAt = Date(timeIntervalSince1970: 21)
        protectedCrashWindowMutation = try await capacityStore.put(
            protectedCrashWindowMutation
        )
        protectedCrashWindowMutation.state = .failedBeforeSubmission
        protectedCrashWindowMutation.errorClass =
            "interrupted_before_transport_admission"
        protectedCrashWindowMutation.updatedAt = Date(timeIntervalSince1970: 22)
        protectedCrashWindowMutation = try await capacityStore.put(
            protectedCrashWindowMutation
        )
        var safelyPrunableTerminal = PolkamarktPendingMutation(
            id: UUID(),
            account: pending.account,
            action: "claim_trader",
            marketIds: [4],
            createdAt: Date(timeIntervalSince1970: 30),
            updatedAt: Date(timeIntervalSince1970: 30),
            extrinsicHash: nil,
            state: .preparing,
            finalizedBlock: nil,
            errorClass: nil
        )
        safelyPrunableTerminal = try await capacityStore.put(
            safelyPrunableTerminal
        )
        safelyPrunableTerminal.state = .failedBeforeSubmission
        safelyPrunableTerminal.errorClass = "cancelled_before_signing"
        safelyPrunableTerminal.updatedAt = Date(timeIntervalSince1970: 31)
        safelyPrunableTerminal = try await capacityStore.put(
            safelyPrunableTerminal
        )
        let replacement = PolkamarktPendingMutation(
            id: UUID(),
            account: pending.account,
            action: "sell_yes",
            marketIds: [5],
            createdAt: Date(timeIntervalSince1970: 40),
            updatedAt: Date(timeIntervalSince1970: 40),
            extrinsicHash: nil,
            state: .preparing,
            finalizedBlock: nil,
            errorClass: nil
        )
        _ = try await capacityStore.put(replacement)
        let capacitySnapshot = try await capacityStore.all()
        XCTAssertTrue(
            capacitySnapshot.contains(where: {
                $0.id == protectedCrashWindowMutation.id
            }),
            "A protected companion witness was pruned at journal capacity"
        )
        XCTAssertFalse(
            capacitySnapshot.contains(where: {
                $0.id == safelyPrunableTerminal.id
            })
        )
        XCTAssertEqual(
            try capacitySora2Store.all().first(where: {
                $0.id == protectedWitness.id
            })?.state,
            .stagedBeforeTransport
        )
        do {
            _ = try await capacityStore.put(
                PolkamarktPendingMutation(
                    id: UUID(),
                    account: pending.account,
                    action: "sell_no",
                    marketIds: [6],
                    createdAt: Date(timeIntervalSince1970: 50),
                    updatedAt: Date(timeIntervalSince1970: 50),
                    extrinsicHash: nil,
                    state: .preparing,
                    finalizedBlock: nil,
                    errorClass: nil
                )
            )
            XCTFail("Capacity admission discarded protected recovery proof")
        } catch {
            guard case PolkamarktRuntimeError.unavailable = error else {
                return XCTFail("Unexpected capacity error: \(error)")
            }
        }

        let encoded = try XCTUnwrap(
            String(data: Data(contentsOf: journal), encoding: .utf8)
        )
        XCTAssertTrue(encoded.contains("\"state\":\"preparing\""))
        try Data(
            encoded.replacingOccurrences(
                of: "\"state\":\"preparing\"",
                with: "\"state\":\"futureTransportPhase\""
            ).utf8
        ).write(to: journal, options: .atomic)
        do {
            _ = try await store.all()
            XCTFail("A future Polkamarkt journal phase decoded permissively")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testPolkamarktPendingJournalRejectsSymbolicLink() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try PolkamarktPendingStore(baseURL: directory)
        let decoy = directory.appendingPathComponent("decoy.json")
        try Data("[]".utf8).write(to: decoy)
        let journal = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
            .appendingPathComponent("polkamarkt-v1.json")
        try FileManager.default.createSymbolicLink(
            at: journal,
            withDestinationURL: decoy
        )

        do {
            _ = try await store.all()
            XCTFail("A symlinked Polkamarkt pending journal was accepted")
        } catch {
            guard case PolkamarktRuntimeError.unavailable = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPolkamarktReconciliationMergesIntoLatestJournalWithoutRegression()
        throws
    {
        let account = "sora-account"
        let hash = String(repeating: "ab", count: 32)
        let createdAt = Date(timeIntervalSince1970: 1)
        let resolvedAt = Date(timeIntervalSince1970: 3)
        let captured = PolkamarktPendingMutation(
            id: UUID(),
            account: account,
            action: "buy_yes",
            marketIds: [1],
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 2),
            extrinsicHash: hash,
            state: .submitted,
            finalizedBlock: nil,
            errorClass: "retained-until-resolution"
        )
        let concurrentlyAppended = PolkamarktPendingMutation(
            id: UUID(),
            account: account,
            action: "sell_no",
            marketIds: [2],
            createdAt: resolvedAt,
            updatedAt: resolvedAt,
            extrinsicHash: nil,
            state: .preparing,
            finalizedBlock: nil,
            errorClass: nil
        )

        let merged = try PolkamarktPendingReconciliationPolicy.applying(
            [
                hash: PolkamarktPendingResolution(
                    finalizedBlock: 42,
                    succeeded: true
                )
            ],
            to: [captured, concurrentlyAppended],
            account: account,
            resolvedAt: resolvedAt
        )

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].state, .finalized)
        XCTAssertEqual(merged[0].finalizedBlock, 42)
        XCTAssertEqual(merged[0].updatedAt, resolvedAt)
        XCTAssertNil(merged[0].errorClass)
        XCTAssertEqual(merged[1], concurrentlyAppended)

        var alreadyRejected = captured
        alreadyRejected.state = .rejected
        alreadyRejected.finalizedBlock = 41
        alreadyRejected.updatedAt = resolvedAt
        alreadyRejected.errorClass = nil
        XCTAssertEqual(
            try PolkamarktPendingReconciliationPolicy.applying(
                [
                    hash: PolkamarktPendingResolution(
                        finalizedBlock: 42,
                        succeeded: true
                    )
                ],
                to: [alreadyRejected],
                account: account,
                resolvedAt: Date(timeIntervalSince1970: 4)
            ),
            [alreadyRejected]
        )
        XCTAssertTrue(
            PolkamarktPendingObservationPolicy.requiresObservation(
                [captured],
                account: account
            )
        )
        XCTAssertFalse(
            PolkamarktPendingObservationPolicy.requiresObservation(
                [alreadyRejected],
                account: account
            )
        )
        XCTAssertFalse(
            PolkamarktPendingObservationPolicy.requiresObservation(
                [captured],
                account: "different-account"
            )
        )
        XCTAssertEqual(
            PolkamarktPendingObservationPolicy.delayNanoseconds(
                afterAttempt: -1
            ),
            2_000_000_000
        )
        XCTAssertEqual(
            PolkamarktPendingObservationPolicy.delayNanoseconds(
                afterAttempt: 0
            ),
            2_000_000_000
        )
        XCTAssertEqual(
            PolkamarktPendingObservationPolicy.delayNanoseconds(
                afterAttempt: 6
            ),
            30_000_000_000
        )
        XCTAssertEqual(
            PolkamarktPendingObservationPolicy.delayNanoseconds(
                afterAttempt: .max
            ),
            30_000_000_000
        )

        var signedBeforeTransport = captured
        signedBeforeTransport.state = .signedBeforeTransport
        signedBeforeTransport.updatedAt = createdAt
        signedBeforeTransport.errorClass = nil
        func witness(
            _ state: Sora2PendingSubmissionState,
            account witnessAccount: String
        ) -> Sora2PendingSubmission {
            Sora2PendingSubmission(
                id: UUID(),
                account: witnessAccount,
                extrinsicHash: hash,
                createdAt: createdAt,
                updatedAt: createdAt,
                state: state
            )
        }
        XCTAssertEqual(
            try PolkamarktPreTransportRecoveryPolicy.decision(
                for: signedBeforeTransport,
                sora2Witness: nil
            ),
            .failedBeforeSubmission(
                errorClass: "interrupted_before_transport_staging"
            )
        )
        XCTAssertEqual(
            try PolkamarktPreTransportRecoveryPolicy.decision(
                for: signedBeforeTransport,
                sora2Witness: witness(
                    .stagedBeforeTransport,
                    account: account
                )
            ),
            .failedBeforeSubmission(
                errorClass: "interrupted_before_transport_admission"
            )
        )
        for state in [
            Sora2PendingSubmissionState.submitting,
            .submissionUnknown,
        ] {
            XCTAssertEqual(
                try PolkamarktPreTransportRecoveryPolicy.decision(
                    for: signedBeforeTransport,
                    sora2Witness: witness(state, account: account)
                ),
                .submissionUnknown(
                    errorClass: "interrupted_after_transport_admission"
                )
            )
        }
        for state in [
            Sora2PendingSubmissionState.submittedRetained,
            .submitted,
        ] {
            XCTAssertEqual(
                try PolkamarktPreTransportRecoveryPolicy.decision(
                    for: signedBeforeTransport,
                    sora2Witness: witness(state, account: account)
                ),
                .submitted
            )
        }
        XCTAssertThrowsError(
            try PolkamarktPreTransportRecoveryPolicy.decision(
                for: signedBeforeTransport,
                sora2Witness: witness(
                    .stagedBeforeTransport,
                    account: "different-account"
                )
            )
        )
        var legacySubmitting = signedBeforeTransport
        legacySubmitting.state = .submitting
        XCTAssertThrowsError(
            try PolkamarktPreTransportRecoveryPolicy.decision(
                for: legacySubmitting,
                sora2Witness: nil
            )
        )
    }

    func testPolkamarktPendingJournalRejectsDuplicateExtrinsicHash() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try PolkamarktPendingStore(baseURL: directory)
        let hash = String(repeating: "ab", count: 32)
        func mutation() -> PolkamarktPendingMutation {
            PolkamarktPendingMutation(
                id: UUID(),
                account: "sora-account",
                action: "buy",
                marketIds: [1],
                createdAt: Date(),
                updatedAt: Date(),
                extrinsicHash: nil,
                state: .preparing,
                finalizedBlock: nil,
                errorClass: nil
            )
        }

        var first: PolkamarktPendingMutation
        do {
            first = try await store.put(mutation())
        } catch {
            XCTFail("First preparing journal write failed: \(error)")
            throw error
        }
        first.extrinsicHash = hash
        first.state = .signedBeforeTransport
        first.updatedAt = Date()
        do {
            _ = try await store.put(first)
        } catch {
            XCTFail("First submitting journal write failed: \(error)")
            throw error
        }

        var duplicate: PolkamarktPendingMutation
        do {
            duplicate = try await store.put(mutation())
        } catch {
            XCTFail("Duplicate preparing journal write failed: \(error)")
            throw error
        }
        duplicate.extrinsicHash = hash
        duplicate.state = .signedBeforeTransport
        duplicate.updatedAt = Date()
        do {
            try await store.put(duplicate)
            XCTFail("Duplicate Polkamarkt extrinsic hash was accepted")
        } catch {
            guard
                case PolkamarktRuntimeError.invalidTransactionHash = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPolkamarktPendingJournalRejectsStateRegression() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try PolkamarktPendingStore(baseURL: directory)
        var pending = PolkamarktPendingMutation(
            id: UUID(),
            account: "sora-account",
            action: "sell",
            marketIds: [7],
            createdAt: Date(),
            updatedAt: Date(),
            extrinsicHash: nil,
            state: .preparing,
            finalizedBlock: nil,
            errorClass: nil
        )
        do {
            pending = try await store.put(pending)
        } catch {
            XCTFail("Regression preparing journal write failed: \(error)")
            throw error
        }
        pending.extrinsicHash = String(repeating: "cd", count: 32)
        pending.state = .signedBeforeTransport
        pending.updatedAt = Date()
        do {
            pending = try await store.put(pending)
        } catch {
            XCTFail("Regression submitting journal write failed: \(error)")
            throw error
        }
        pending.state = .submitted
        pending.updatedAt = Date()
        do {
            pending = try await store.put(pending)
        } catch {
            XCTFail("Submitted journal write failed: \(error)")
            throw error
        }

        pending.state = .signedBeforeTransport
        pending.updatedAt = Date()
        do {
            _ = try await store.put(pending)
            XCTFail("A submitted mutation regressed to submitting")
        } catch {
            guard case PolkamarktRuntimeError.unavailable = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPolkamarktPendingJournalKeepsTerminalStateAgainstLateCallback()
        async throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try PolkamarktPendingStore(baseURL: directory)
        var pending = PolkamarktPendingMutation(
            id: UUID(),
            account: "sora-account",
            action: "buy_yes",
            marketIds: [9],
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            extrinsicHash: nil,
            state: .preparing,
            finalizedBlock: nil,
            errorClass: nil
        )
        do {
            pending = try await store.put(pending)
        } catch {
            XCTFail("Terminal-race preparing journal write failed: \(error)")
            throw error
        }
        pending.extrinsicHash = String(repeating: "ef", count: 32)
        pending.state = .signedBeforeTransport
        pending.updatedAt = Date(timeIntervalSince1970: 2)
        do {
            pending = try await store.put(pending)
        } catch {
            XCTFail("Terminal-race signed journal write failed: \(error)")
            throw error
        }
        let staleCallback = pending

        pending.state = .submitted
        pending.updatedAt = Date(timeIntervalSince1970: 3)
        do {
            pending = try await store.put(pending)
        } catch {
            XCTFail("Terminal-race submitted journal write failed: \(error)")
            throw error
        }
        pending.state = .finalized
        pending.finalizedBlock = 42
        pending.updatedAt = Date(timeIntervalSince1970: 4)
        let finalized: PolkamarktPendingMutation
        do {
            finalized = try await store.put(pending)
        } catch {
            XCTFail("Authoritative finalized journal write failed: \(error)")
            throw error
        }

        var lateSubmitted = staleCallback
        lateSubmitted.state = .submitted
        lateSubmitted.updatedAt = Date(timeIntervalSince1970: 5)
        let retained: PolkamarktPendingMutation
        do {
            retained = try await store.put(lateSubmitted)
        } catch {
            XCTFail("Late callback journal merge failed: \(error)")
            throw error
        }

        XCTAssertEqual(retained, finalized)
        let reloaded = try await store.all()
        XCTAssertEqual(reloaded, [finalized])
    }

    func testPreparedExtrinsicSubmissionIsOneShot() throws {
        let bytes = Data([0x01, 0x02, 0x03])
        let prepared = PreparedExtrinsicSubmission(
            data: bytes,
            hash: try bytes.blake2b32().toHex(includePrefix: true)
        )

        let payload = try prepared.consumeForTransport()
        XCTAssertEqual(
            try payload.consumeHexForTransport(),
            bytes.toHex(includePrefix: true)
        )
        XCTAssertThrowsError(try prepared.consumeForTransport()) {
            error in
            guard
                case ExtrinsicServiceError
                    .preparedSubmissionAlreadyConsumed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testCancellableCallRelayClosesPublicationRaceExactlyOnce() {
        let cancelledBeforePublication = CancellableCallRelay()
        let lateCall = WalletTestCancellableCall()
        cancelledBeforePublication.cancel()
        cancelledBeforePublication.set(lateCall)
        cancelledBeforePublication.cancel()
        XCTAssertEqual(lateCall.cancelCount, 1)

        let publishedBeforeCancellation = CancellableCallRelay()
        let earlyCall = WalletTestCancellableCall()
        publishedBeforeCancellation.set(earlyCall)
        publishedBeforeCancellation.cancel()
        publishedBeforeCancellation.cancel()
        XCTAssertEqual(earlyCall.cancelCount, 1)
    }

    func testSora2ProducedSignatureIsVerifiedAgainstStoredPublicKey() throws {
        let seed = Data((0 ..< 32).map { UInt8($0) })
        let keypair = try Ed25519KeypairFactory()
            .createKeypairFromSeed(seed, chaincodeList: [])
        let publicKey = keypair.publicKey().rawData()
        let account = AccountItem(
            address: try SS58AddressFactory().address(
                fromAccountId: publicKey,
                type: Chain.sora.addressType()
            ),
            cryptoType: .ed25519,
            networkType: Chain.sora.addressType(),
            username: "Signing vector",
            publicKeyData: publicKey,
            settings: AccountSettings(
                visibleAssetIds: [],
                orderedAssetIds: []
            ),
            order: 0,
            isSelected: true
        )
        let payload = Data("signed-payload".utf8)
        let signature = try Sora2Ed25519SeedSigner.sign(
            payload,
            seed: seed
        )

        XCTAssertNoThrow(
            try Sora2SignatureVerifier.verify(
                signature: signature,
                originalData: payload,
                secretKey: seed,
                account: account
            )
        )
        XCTAssertThrowsError(
            try Sora2SignatureVerifier.verify(
                signature: signature,
                originalData: Data("tampered".utf8),
                secretKey: seed,
                account: account
            )
        )
    }

    func testEd25519SignerMatchesPinnedSora2Rfc8032Vector() throws {
        // Pinned source: sora2-network 411dcdb70c5c00b21482a44d02334840d5f338c6,
        // vendor/sp-core/src/ed25519.rs (RFC 8032 empty-message vector).
        let seed = try Data(
            hexStringSSF:
                "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
        )
        let expectedPublicKey = try Data(
            hexStringSSF:
                "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
        )
        let expectedSignature = try Data(
            hexStringSSF:
                "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
        )

        let factory = Ed25519KeypairFactory()
        let storedSecret = try factory.deriveChildSeedFromParent(
            seed,
            chaincodeList: []
        )
        let keypair = try factory.createKeypairFromSeed(
            storedSecret,
            chaincodeList: []
        )
        let firstSignedValue = try DummySigner(
            cryptoType: .ed25519,
            seed: storedSecret
        ).sign(Data())
        let secondSignedValue = try DummySigner(
            cryptoType: .ed25519,
            seed: storedSecret
        ).sign(Data())
        let firstSignature = firstSignedValue.rawData()
        let secondSignature = secondSignedValue.rawData()

        // The persisted SORA2 secret and wallet identity stay byte-for-byte
        // stable while production signing is deterministic RFC 8032.
        XCTAssertEqual(storedSecret, seed)
        XCTAssertEqual(keypair.publicKey().rawData(), expectedPublicKey)
        XCTAssertEqual(firstSignature, expectedSignature)
        XCTAssertEqual(secondSignature, firstSignature)
        XCTAssertTrue(
            EDSignatureVerifier().verify(
                firstSignedValue,
                forOriginalData: Data(),
                usingPublicKey: keypair.publicKey()
            )
        )
    }

    func testEd25519SeedSignerRejectsShortSeedBeforeExpansion() {
        XCTAssertThrowsError(
            try Sora2Ed25519SeedSigner.sign(
                Data(),
                seed: Data(repeating: 0x5a, count: 31)
            )
        )
    }

    func testSora2ConfirmedTransportSuccessSurvivesJournalFailure() throws {
        struct JournalFailure: Swift.Error {}
        let confirmed: Result<String, Swift.Error> = .success("confirmed-hash")

        let retained = Sora2TransportCompletionPolicy
            .preservingConfirmedSuccess(confirmed) {
                throw JournalFailure()
            }

        XCTAssertEqual(try retained.get(), "confirmed-hash")
    }

    func testSora2SubmissionUnknownCarriesAndProjectsExactStagedHash()
        throws
    {
        struct TransportTimeout: Swift.Error {}
        let localHash = String(repeating: "ab", count: 32)
        let ambiguity = PreparedExtrinsicTransportError.submissionUnknown(
            localHash: localHash,
            error: TransportTimeout()
        )

        XCTAssertEqual(
            ambiguity.submissionUnknownLocalHash,
            localHash
        )
        let stringResult: Result<String, Swift.Error> = .failure(ambiguity)
        XCTAssertEqual(
            try Sora2LegacySubmissionProjection.transactionHash(
                from: stringResult
            ),
            localHash
        )

        let dataResult: Result<Data, Swift.Error> = .failure(ambiguity)
        let projectedData = try Sora2LegacySubmissionProjection
            .transactionHash(from: dataResult)
        XCTAssertEqual(
            projectedData,
            try Data(hexStringSSF: localHash)
        )
        let confirmation = Sora2ConfirmSendingResultProjection.make(
            from: dataResult
        )
        XCTAssertEqual(confirmation.status, .pending)
        XCTAssertEqual(
            confirmation.transactionHash,
            "0x" + localHash
        )
    }

    func testSora2PostTransportCancellationAndHashMismatchUseStagedHash()
        throws
    {
        let localHash = String(repeating: "bc", count: 32)
        let failures: [Swift.Error] = [
            BaseOperationError.parentOperationCancelled,
            ExtrinsicServiceError.invalidLocalHash,
        ]

        for failure in failures {
            let result: Result<String, Swift.Error> = .failure(
                PreparedExtrinsicTransportError.submissionUnknown(
                    localHash: "0x" + localHash.uppercased(),
                    error: failure
                )
            )
            XCTAssertEqual(
                try Sora2LegacySubmissionProjection.transactionHash(
                    from: result
                ),
                localHash
            )
        }
    }

    func testSora2PendingProjectionRejectsEveryNonAmbiguousFailure() {
        struct UnrelatedFailure: Swift.Error {}
        let preTransport = PreparedExtrinsicTransportError
            .failedBeforeTransport(UnrelatedFailure())
        let preTransportResult: Result<Data, Swift.Error> =
            .failure(preTransport)
        XCTAssertThrowsError(
            try Sora2LegacySubmissionProjection.transactionHash(
                from: preTransportResult
            )
        )
        let preTransportConfirmation =
            Sora2ConfirmSendingResultProjection.make(
                from: preTransportResult
            )
        XCTAssertEqual(preTransportConfirmation.status, .failed)
        XCTAssertTrue(
            preTransportConfirmation.transactionHash.isEmpty
        )

        let unrelatedResult: Result<Data, Swift.Error> =
            .failure(UnrelatedFailure())
        XCTAssertThrowsError(
            try Sora2LegacySubmissionProjection.transactionHash(
                from: unrelatedResult
            )
        )
        let unrelatedConfirmation =
            Sora2ConfirmSendingResultProjection.make(
                from: unrelatedResult
            )
        XCTAssertEqual(unrelatedConfirmation.status, .failed)
        XCTAssertTrue(unrelatedConfirmation.transactionHash.isEmpty)
    }

    func testSora2PendingProjectionRejectsMalformedAmbiguityHash() {
        struct TransportTimeout: Swift.Error {}
        let malformed = PreparedExtrinsicTransportError.submissionUnknown(
            localHash: "not-a-transaction-hash",
            error: TransportTimeout()
        )
        XCTAssertNil(malformed.submissionUnknownLocalHash)

        let result: Result<Data, Swift.Error> = .failure(malformed)
        XCTAssertThrowsError(
            try Sora2LegacySubmissionProjection.transactionHash(
                from: result
            )
        )
        let confirmation = Sora2ConfirmSendingResultProjection.make(
            from: result
        )
        XCTAssertEqual(confirmation.status, .failed)
        XCTAssertTrue(confirmation.transactionHash.isEmpty)
    }

    func testSora2PendingProjectionKeepsConfirmedHashPendingForReconciliation()
        throws
    {
        let localHash = String(repeating: "cd", count: 32)
        let result: Result<Data, Swift.Error> = .success(
            try Data(hexStringSSF: localHash)
        )
        let confirmation = Sora2ConfirmSendingResultProjection.make(
            from: result
        )

        XCTAssertEqual(confirmation.status, .pending)
        XCTAssertEqual(
            confirmation.transactionHash,
            "0x" + localHash
        )
    }

    func testSora2PendingSubmissionStoreNeverRegressesTerminalState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let pending = try store.stage(
            account: "sora-account",
            hash: "0x" + String(repeating: "ef", count: 32)
        )
        try store.update(pending, state: .submitted)

        XCTAssertThrowsError(
            try store.update(
                pending,
                state: .submissionUnknown
            )
        )
        XCTAssertEqual(try store.all().first?.state, .submitted)
        XCTAssertTrue(try XCTUnwrap(store.all().first).isPrunable)

        let retainedHash = "0x" + String(repeating: "ab", count: 32)
        let retained = try store.stage(
            account: "sora-account",
            hash: retainedHash,
            retainingTransportWitness: true
        )
        XCTAssertEqual(retained.state, .stagedBeforeTransport)
        XCTAssertFalse(retained.isPrunable)
        XCTAssertThrowsError(
            try store.update(retained, state: .submittedRetained)
        )
        try store.update(retained, state: .submitting)
        try store.update(retained, state: .submittedRetained)
        XCTAssertEqual(
            try store.all().first(where: {
                $0.extrinsicHash == String(repeating: "ab", count: 32)
            })?.state,
            .submittedRetained
        )
        try store.acknowledgeRetainedSubmission(
            account: retained.account,
            hash: retained.extrinsicHash
        )
        XCTAssertEqual(
            try store.all().first(where: {
                $0.extrinsicHash == String(repeating: "ab", count: 32)
            })?.state,
            .submitted
        )

        let ambiguous = try store.stage(
            account: "sora-account",
            hash: "0x" + String(repeating: "12", count: 32)
        )
        try store.update(ambiguous, state: .submissionUnknown)
        XCTAssertThrowsError(
            try store.acknowledgeRetainedSubmission(
                account: ambiguous.account,
                hash: ambiguous.extrinsicHash
            )
        )
        try store.acknowledgeAuthoritativelyFinalizedSubmissions(
            account: ambiguous.account,
            hashes: [ambiguous.extrinsicHash]
        )
        XCTAssertEqual(
            try store.all().first(where: {
                $0.extrinsicHash == ambiguous.extrinsicHash
            })?.state,
            .submitted
        )

        let unadmitted = try store.stage(
            account: "sora-account",
            hash: "0x" + String(repeating: "34", count: 32),
            retainingTransportWitness: true
        )
        XCTAssertThrowsError(
            try store.acknowledgeAuthoritativelyFinalizedSubmissions(
                account: unadmitted.account,
                hashes: [unadmitted.extrinsicHash]
            )
        )
        try store.removeBeforeSubmission(unadmitted)

        let canonicalGenesis = try XCTUnwrap(
            Sora2PendingSubmissionStore.normalizedHash(
                PIIndexerClient.soraMainnetGenesis
            )
        )
        let accountId = String(repeating: "56", count: 32)
        let eraBirthHash = String(repeating: "78", count: 32)
        func recoveryContext(
            hash: String,
            schemaVersion: Int =
                Sora2SubmissionRecoveryContext.currentSchemaVersion
        ) -> Sora2SubmissionRecoveryContext {
            Sora2SubmissionRecoveryContext(
                schemaVersion: schemaVersion,
                walletId: "sora-account",
                accountId: accountId,
                publicKey: accountId,
                transactionHash: hash,
                genesisHash: canonicalGenesis,
                specVersion: PolkamarktRuntimeContract.specVersion,
                transactionVersion:
                    PolkamarktRuntimeContract.transactionVersion,
                metadataSHA256:
                    PolkamarktRuntimeContract.metadataFileSHA256,
                eraBirthBlock: 128,
                eraDeathBlockExclusive: 192,
                eraPeriod: 64,
                eraPhase: 0,
                eraBirthBlockHash: eraBirthHash
            )
        }

        let finalizedHash = String(repeating: "9a", count: 32)
        let finalizedContext = recoveryContext(hash: finalizedHash)
        let genericAmbiguous = try store.stage(
            account: "sora-account",
            hash: finalizedHash,
            recoveryContext: finalizedContext
        )
        try store.update(genericAmbiguous, state: .submissionUnknown)
        XCTAssertThrowsError(
            try store.resolveAuthoritatively(
                genericAmbiguous,
                proof: .mortalEraAbsence(
                    scannedBirthBlock: 128,
                    scannedDeathBlockExclusive: 192,
                    finalizedHeight: 191
                )
            )
        )
        XCTAssertEqual(
            try store.all().first(where: {
                $0.id == genericAmbiguous.id
            })?.state,
            .submissionUnknown
        )
        XCTAssertFalse(
            try XCTUnwrap(
                store.all().first(where: {
                    $0.id == genericAmbiguous.id
                })
            ).isPrunable
        )
        try store.resolveAuthoritatively(
            genericAmbiguous,
            proof: .finalizedInclusion(
                blockNumber: 130,
                blockHash: String(repeating: "bc", count: 32),
                succeeded: false,
                finalizedHeight: 192
            )
        )
        let finalizedResolution = try XCTUnwrap(
            try store.all().first(where: {
                $0.id == genericAmbiguous.id
            })
        )
        XCTAssertTrue(finalizedResolution.isPrunable)
        XCTAssertEqual(
            finalizedResolution.terminalResolution?.kind,
            .finalizedFailure
        )

        let confirmedHash = String(repeating: "ce", count: 32)
        let confirmed = try store.stage(
            account: "sora-account",
            hash: confirmedHash,
            recoveryContext: recoveryContext(hash: confirmedHash)
        )
        try store.update(confirmed, state: .submitted)
        let unresolvedConfirmed = try XCTUnwrap(
            store.all().first(where: { $0.id == confirmed.id })
        )
        XCTAssertFalse(unresolvedConfirmed.isPrunable)
        try store.resolveAuthoritatively(
            unresolvedConfirmed,
            proof: .finalizedInclusion(
                blockNumber: 131,
                blockHash: String(repeating: "cf", count: 32),
                succeeded: true,
                finalizedHeight: 192
            )
        )
        let resolvedConfirmed = try XCTUnwrap(
            store.all().first(where: { $0.id == confirmed.id })
        )
        XCTAssertTrue(resolvedConfirmed.isPrunable)
        XCTAssertEqual(
            resolvedConfirmed.terminalResolution?.kind,
            .finalizedSuccess
        )

        let expiredHash = String(repeating: "de", count: 32)
        let expired = try store.stage(
            account: "sora-account",
            hash: expiredHash,
            recoveryContext: recoveryContext(hash: expiredHash)
        )
        try store.update(expired, state: .submissionUnknown)
        try store.resolveAuthoritatively(
            expired,
            proof: .mortalEraAbsence(
                scannedBirthBlock: 128,
                scannedDeathBlockExclusive: 192,
                finalizedHeight: 192
            )
        )
        XCTAssertEqual(
            try store.all().first(where: { $0.id == expired.id })?
                .terminalResolution?.kind,
            .expiredNotIncluded
        )

        let corruptVersionHash = String(repeating: "f0", count: 32)
        XCTAssertThrowsError(
            try store.stage(
                account: "sora-account",
                hash: corruptVersionHash,
                recoveryContext: recoveryContext(
                    hash: corruptVersionHash,
                    schemaVersion: 2
                )
            )
        )
    }

    func testSora2PendingSubmissionStoreRetainsExactAmbiguousHash() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let localHash = String(repeating: "ef", count: 32)
        let pending = try store.stage(
            account: "sora-account",
            hash: "0x" + localHash.uppercased()
        )

        try store.update(pending, state: .submissionUnknown)

        let retained = try XCTUnwrap(store.all().first)
        XCTAssertEqual(retained.extrinsicHash, localHash)
        XCTAssertEqual(retained.state, .submissionUnknown)
        XCTAssertEqual(retained.purpose, .generic)

        let migration = try store.stage(
            account: "sora-account",
            hash: String(repeating: "cd", count: 32),
            purpose: .legacyMigration
        )
        XCTAssertEqual(
            try store.all().first(where: { $0.id == migration.id })?
                .purpose,
            .legacyMigration
        )

        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(retained)
            ) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "purpose")
        let legacyEntry = try JSONDecoder().decode(
            Sora2PendingSubmission.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )
        XCTAssertNil(legacyEntry.purpose)

        var recoveryResult: String?
        let recovery = MigrationFinalityRecoveryHandle(
            accountAddress: "sora-account",
            transactionHash: localHash,
            completion: { result in
                if case let .success(value) = result {
                    recoveryResult = value
                }
            }
        )
        XCTAssertTrue(
            recovery.matches(
                accountAddress: "sora-account",
                transactionHash: localHash
            )
        )
        XCTAssertFalse(
            recovery.matches(
                accountAddress: "another-account",
                transactionHash: localHash
            )
        )
        XCTAssertFalse(recovery.attach { _ in
            XCTFail("A second claim observer must not replace the first")
        })
        let attachedCompletion = try XCTUnwrap(recovery.finish())
        attachedCompletion(.success("finalized"))
        XCTAssertEqual(recoveryResult, "finalized")
        XCTAssertNil(recovery.finish())
        XCTAssertFalse(recovery.attach { _ in
            XCTFail("A completed recovery must stay terminal")
        })

        let eligibility = MigrationEligibilityCheckGate()
        let firstEligibility = try XCTUnwrap(
            eligibility.begin(accountAddress: "sora-account")
        )
        XCTAssertFalse(
            eligibility.validateSigningAuthorization(
                token: firstEligibility,
                accountAddress: "sora-account"
            )
        )
        XCTAssertTrue(
            eligibility.authorizeForSigning(
                token: firstEligibility,
                accountAddress: "sora-account"
            )
        )
        XCTAssertFalse(
            eligibility.authorizeForSigning(
                token: firstEligibility,
                accountAddress: "sora-account"
            ),
            "One eligibility response may authorize signing only once"
        )
        XCTAssertTrue(
            eligibility.validateSigningAuthorization(
                token: firstEligibility,
                accountAddress: "sora-account"
            )
        )
        XCTAssertNil(
            eligibility.begin(accountAddress: "sora-account")
        )
        let replacementEligibility = try XCTUnwrap(
            eligibility.begin(accountAddress: "another-account")
        )
        XCTAssertFalse(
            eligibility.consume(
                token: firstEligibility,
                accountAddress: "sora-account"
            )
        )
        XCTAssertFalse(
            eligibility.validateSigningAuthorization(
                token: firstEligibility,
                accountAddress: "sora-account"
            )
        )
        XCTAssertTrue(
            eligibility.consumeAwaitingEligibility(
                token: replacementEligibility,
                accountAddress: "another-account"
            )
        )
        let invalidatedEligibility = try XCTUnwrap(
            eligibility.begin(accountAddress: "sora-account")
        )
        eligibility.invalidate()
        XCTAssertFalse(
            eligibility.consume(
                token: invalidatedEligibility,
                accountAddress: "sora-account"
            )
        )

        let migrationSettings = InMemorySettingsManager()
        migrationSettings.hasMigrated = true
        XCTAssertFalse(
            try MigrationAccountCompletionStore.contains(
                accountAddress: "sora-account",
                settings: migrationSettings
            ),
            "The legacy global flag is not account-level authority"
        )
        try MigrationAccountCompletionStore.record(
            accountAddress: "sora-account",
            settings: migrationSettings
        )
        XCTAssertTrue(
            try MigrationAccountCompletionStore.contains(
                accountAddress: "sora-account",
                settings: migrationSettings
            )
        )
        XCTAssertFalse(
            try MigrationAccountCompletionStore.contains(
                accountAddress: "another-account",
                settings: migrationSettings
            )
        )
        try MigrationAccountCompletionStore.record(
            accountAddress: "another-account",
            settings: migrationSettings
        )
        XCTAssertTrue(
            try MigrationAccountCompletionStore.contains(
                accountAddress: "another-account",
                settings: migrationSettings
            )
        )
        try MigrationAccountCompletionStore.remove(
            accountAddress: "sora-account",
            settings: migrationSettings
        )
        XCTAssertFalse(
            try MigrationAccountCompletionStore.contains(
                accountAddress: "sora-account",
                settings: migrationSettings
            )
        )
        XCTAssertTrue(
            try MigrationAccountCompletionStore.contains(
                accountAddress: "another-account",
                settings: migrationSettings
            )
        )
        try MigrationAccountCompletionStore.remove(
            accountAddress: "another-account",
            settings: migrationSettings
        )
        XCTAssertNil(
            migrationSettings.anyValue(
                for: SettingsKey.migratedAccountsV1.rawValue
            )
        )
        XCTAssertThrowsError(
            try MigrationAccountCompletionStore.contains(
                accountAddress: " sora-account",
                settings: migrationSettings
            )
        )
        migrationSettings.set(
            value: Data("{\"schemaVersion\":2}".utf8),
            for: SettingsKey.migratedAccountsV1.rawValue
        )
        XCTAssertThrowsError(
            try MigrationAccountCompletionStore.contains(
                accountAddress: "sora-account",
                settings: migrationSettings
            )
        )
        migrationSettings.set(
            value: Data(repeating: 0x20, count: 300 * 1_024 + 1),
            for: SettingsKey.migratedAccountsV1.rawValue
        )
        XCTAssertThrowsError(
            try MigrationAccountCompletionStore.contains(
                accountAddress: "sora-account",
                settings: migrationSettings
            )
        )
    }

    func testSora2PendingSubmissionStorePreservesDuplicateHashForReconciliation()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let hash = "0x" + String(repeating: "ab", count: 32)
        let original = try store.stage(
            account: "sora-account",
            hash: hash
        )

        XCTAssertThrowsError(
            try store.stage(account: "sora-account", hash: hash)
        ) { error in
            guard
                case ExtrinsicServiceError
                    .duplicatePreparedSubmission = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let retainedValues = try store.all()
        let retained = try XCTUnwrap(retainedValues.first)
        XCTAssertEqual(retainedValues.count, 1)
        XCTAssertEqual(retained.id, original.id)
        XCTAssertEqual(retained.account, original.account)
        XCTAssertEqual(retained.extrinsicHash, original.extrinsicHash)
        XCTAssertEqual(retained.state, .submitting)
    }

    func testSora2PendingJournalRejectsSymbolicLink() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let decoy = directory.appendingPathComponent("decoy.json")
        try Data("[]".utf8).write(to: decoy)
        let journal = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
            .appendingPathComponent("sora2-signed-v1.json")
        try FileManager.default.createSymbolicLink(
            at: journal,
            withDestinationURL: decoy
        )

        XCTAssertThrowsError(try store.all())
        XCTAssertEqual(try Data(contentsOf: decoy), Data("[]".utf8))

        let corruptBase = directory.appendingPathComponent(
            "corrupt-context",
            isDirectory: true
        )
        let corruptContextStore = try Sora2PendingSubmissionStore(
            baseURL: corruptBase
        )
        let hash = String(repeating: "45", count: 32)
        let corruptContext = Sora2SubmissionRecoveryContext(
            schemaVersion: 2,
            walletId: "sora-account",
            accountId: String(repeating: "67", count: 32),
            publicKey: String(repeating: "67", count: 32),
            transactionHash: hash,
            genesisHash: try XCTUnwrap(
                Sora2PendingSubmissionStore.normalizedHash(
                    PIIndexerClient.soraMainnetGenesis
                )
            ),
            specVersion: PolkamarktRuntimeContract.specVersion,
            transactionVersion:
                PolkamarktRuntimeContract.transactionVersion,
            metadataSHA256: PolkamarktRuntimeContract.metadataFileSHA256,
            eraBirthBlock: 128,
            eraDeathBlockExclusive: 192,
            eraPeriod: 64,
            eraPhase: 0,
            eraBirthBlockHash: String(repeating: "89", count: 32)
        )
        let corruptEntry = Sora2PendingSubmission(
            id: UUID(),
            account: "sora-account",
            extrinsicHash: hash,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2),
            state: .submissionUnknown,
            recoveryContext: corruptContext
        )
        let corruptEncoder = JSONEncoder()
        corruptEncoder.dateEncodingStrategy = .iso8601
        let corruptJournal = corruptBase
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(
                "PendingTransactions",
                isDirectory: true
            )
            .appendingPathComponent("sora2-signed-v1.json")
        try corruptEncoder.encode([corruptEntry]).write(
            to: corruptJournal,
            options: .atomic
        )
        XCTAssertThrowsError(try corruptContextStore.all())
    }

    func testPendingHistoryRequiresExactRemoteHashBeforeRemoval() throws {
        let pendingHash = "0x" + String(repeating: "11", count: 32)
        let pending = TransactionHistoryItem(
            sender: "sender",
            receiver: "receiver",
            status: .pending,
            txHash: pendingHash,
            timestamp: 1,
            fee: "1",
            blockNumber: nil,
            txIndex: nil,
            callPath: .transfer,
            call: Data()
        )

        XCTAssertTrue(
            TransactionHistoryMergeManager.identifiersToRemove(
                remoteHashes: [
                    try Data(
                        hexStringSSF:
                            "0x" + String(repeating: "22", count: 32)
                    )
                ],
                oldestRemoteTimestamp: 10,
                localItems: [pending]
            ).isEmpty
        )
        XCTAssertEqual(
            TransactionHistoryMergeManager.identifiersToRemove(
                remoteHashes: [try Data(hexStringSSF: pendingHash)],
                oldestRemoteTimestamp: 10,
                localItems: [pending]
            ),
            [pendingHash]
        )

        let journalHash = String(repeating: "33", count: 32)
        let journal = Sora2PendingSubmission(
            id: UUID(),
            account: "sender",
            extrinsicHash: journalHash,
            createdAt: Date(timeIntervalSince1970: 2),
            updatedAt: Date(timeIntervalSince1970: 3),
            state: .submissionUnknown
        )
        let journalOverlay = TransactionHistoryMergeManager
            .pendingJournalOverlay(
                address: "sender",
                submissions: [journal, journal],
                visibleLocalItems: [],
                remoteHashes: []
            )
        XCTAssertEqual(journalOverlay.count, 1)
        XCTAssertEqual(journalOverlay.first?.txHash, "0x\(journalHash)")
        XCTAssertEqual(journalOverlay.first?.status, .pending)
        XCTAssertEqual(journalOverlay.first?.callPath.moduleName, "SORA2")
        XCTAssertEqual(
            journalOverlay.first?.callPath.callName,
            "pending_submission"
        )
        XCTAssertTrue(
            TransactionHistoryMergeManager.pendingJournalOverlay(
                address: "sender",
                submissions: [journal],
                visibleLocalItems: [pending],
                remoteHashes: [try Data(hexStringSSF: journalHash)]
            ).isEmpty
        )
        XCTAssertTrue(
            TransactionHistoryMergeManager.pendingJournalOverlay(
                address: "another-account",
                submissions: [journal],
                visibleLocalItems: [],
                remoteHashes: []
            ).isEmpty
        )
    }

    func testNexusToriiHealthNegotiatesPlainTextWhileAPIRoutesRemainJSON()
        throws
    {
        let base = try XCTUnwrap(
            URL(string: "https://public-01.taira.example.org")
        )
        XCTAssertEqual(
            NexusToriiClient.responseAcceptHeader(
                for: base.appendingPathComponent("health")
            ),
            "text/plain"
        )
        XCTAssertEqual(
            NexusToriiClient.responseAcceptHeader(
                for: base.appendingPathComponent("v1/accounts")
            ),
            "application/json"
        )
        let healthURL = base.appendingPathComponent("health")
        let accountURL = base.appendingPathComponent("v1/accounts")
        let mcpURL = base.appendingPathComponent("v1/mcp")
        let submissionURL = base.appendingPathComponent(
            "v1/pipeline/transactions"
        )
        XCTAssertNil(
            try NexusToriiClient.requestContentType(
                method: "GET",
                for: healthURL
            )
        )
        XCTAssertEqual(
            try NexusToriiClient.requestContentType(
                method: "POST",
                for: mcpURL
            ),
            "application/json"
        )
        XCTAssertEqual(
            try NexusToriiClient.requestContentType(
                method: "POST",
                for: submissionURL
            ),
            "application/x-norito"
        )
        XCTAssertThrowsError(
            try NexusToriiClient.requestContentType(
                method: "POST",
                for: healthURL
            )
        )
        XCTAssertTrue(
            NexusToriiClient.isExpectedResponseContentType(
                "text/plain; charset=UTF-8",
                for: healthURL
            )
        )
        XCTAssertFalse(
            NexusToriiClient.isExpectedResponseContentType(
                "application/json",
                for: healthURL
            )
        )
        XCTAssertTrue(
            NexusToriiClient.isExpectedResponseContentType(
                "application/json",
                for: accountURL
            )
        )
        let invalidContentTypes: [String?] = [
            nil,
            "text/plain",
            "application/json, text/plain",
            "application/json; profile=unexpected",
            " application/json"
        ]
        for invalid in invalidContentTypes {
            XCTAssertFalse(
                NexusToriiClient.isExpectedResponseContentType(
                    invalid,
                    for: accountURL
                )
            )
        }
        let xorDefinitionURL = NexusToriiClient.xorAssetDefinitionURL(
            configuration: try Self.admittedTairaConfiguration()
        )
        XCTAssertEqual(
            xorDefinitionURL.absoluteString,
            "https://public-01.taira.example.org/v1/assets/definitions/xor%23universal"
        )
        XCTAssertNil(URLComponents(
            url: xorDefinitionURL,
            resolvingAgainstBaseURL: false
        )?.fragment)
        let minamotoAccount =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let accountTransactionsURL = try NexusToriiClient.accountTransactionsURL(
            account: minamotoAccount,
            configuration: .minamoto,
            assetDefinitionID: Self.nexusXorAssetDefinitionID,
            limit: 25,
            offset: 50
        )
        let accountTransactionsComponents = try XCTUnwrap(
            URLComponents(
                url: accountTransactionsURL,
                resolvingAgainstBaseURL: false
            )
        )
        XCTAssertTrue(
            accountTransactionsComponents.path.hasSuffix("/transactions")
        )
        XCTAssertEqual(
            Dictionary(
                uniqueKeysWithValues:
                    (accountTransactionsComponents.queryItems ?? []).map {
                        ($0.name, $0.value)
                    }
            ),
            [
                "limit": "25",
                "offset": "50",
                "asset_id": Self.nexusXorAssetDefinitionID,
                "count_mode": "exact",
            ]
        )
        XCTAssertThrowsError(
            try NexusToriiClient.accountTransactionsURL(
                account: minamotoAccount,
                configuration: .minamoto,
                assetDefinitionID: NexusAssetDefinitionIdentity.xorAlias
            )
        )
        XCTAssertNoThrow(
            try NexusToriiClient.validateHealthPayload(Data("Healthy".utf8))
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateHealthPayload(Data("Healthy\n".utf8))
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateHealthPayload(Data("healthy".utf8))
        )
        XCTAssertNoThrow(
            try NexusToriiClient.validateResponseLength(-1, maximumBytes: 2)
        )
        XCTAssertNoThrow(
            try NexusToriiClient.validateResponseLength(2, maximumBytes: 2)
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateResponseLength(3, maximumBytes: 2)
        )
        var boundedResponse = Data()
        try NexusToriiClient.appendResponseByte(
            0x01,
            to: &boundedResponse,
            maximumBytes: 2
        )
        try NexusToriiClient.appendResponseByte(
            0x02,
            to: &boundedResponse,
            maximumBytes: 2
        )
        XCTAssertEqual(boundedResponse, Data([0x01, 0x02]))
        XCTAssertThrowsError(
            try NexusToriiClient.appendResponseByte(
                0x03,
                to: &boundedResponse,
                maximumBytes: 2
            )
        )
    }

    func testNexusToriiRejectsPartialFanoutSuccess() throws {
        let endpoint = try XCTUnwrap(
            URL(
                string:
                    "https://public-01.taira.example.org/v1/accounts/example/assets"
            )
        )
        let completeHeaders = [
            "x-iroha-routed-by": "proxy",
            "x-iroha-fanout-routes-attempted": "4",
            "x-iroha-fanout-routes-succeeded": "4",
            "x-iroha-fanout-routes-failed": "0",
            "x-iroha-fanout-routes-unavailable": "0",
            "x-iroha-fanout-routes-denied": "0",
            "x-iroha-fanout-routes-not-found": "0"
        ]
        let direct = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )
        )
        XCTAssertNoThrow(try NexusToriiClient.validateFanoutHeaders(direct))
        let routedSubmission = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 202,
                httpVersion: "HTTP/1.1",
                headerFields: ["x-iroha-routed-by": "proxy"]
            )
        )
        XCTAssertNoThrow(
            try NexusToriiClient.validateFanoutHeaders(routedSubmission)
        )
        let localRoute = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["x-iroha-routed-by": "local"]
            )
        )
        XCTAssertNoThrow(
            try NexusToriiClient.validateFanoutHeaders(localRoute)
        )
        XCTAssertNoThrow(
            try NexusToriiClient.validateFanoutHeaderValues(
                {
                    [
                        "x-iroha-routed-by": "proxy",
                        "x-iroha-route-lane-id": "4294967295",
                        "x-iroha-route-dataspace-id": "18446744073709551615"
                    ][$0]
                }
            )
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateFanoutHeaderValues(
                { ["x-iroha-route-lane-id": "1"][$0] }
            )
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateFanoutHeaderValues(
                {
                    [
                        "x-iroha-route-lane-id": "1",
                        "x-iroha-route-dataspace-id": "2"
                    ][$0]
                }
            )
        )
        for invalidRoute in [
            [
                "x-iroha-routed-by": "proxy",
                "x-iroha-route-lane-id": "01",
                "x-iroha-route-dataspace-id": "2"
            ],
            [
                "x-iroha-routed-by": "proxy",
                "x-iroha-route-lane-id": "4294967296",
                "x-iroha-route-dataspace-id": "2"
            ],
            [
                "x-iroha-routed-by": "proxy",
                "x-iroha-route-lane-id": "1",
                "x-iroha-route-dataspace-id": "18446744073709551616"
            ]
        ] {
            XCTAssertThrowsError(
                try NexusToriiClient.validateFanoutHeaderValues(
                    { invalidRoute[$0] }
                )
            )
        }
        let invalidRouteProvenance = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 202,
                httpVersion: "HTTP/1.1",
                headerFields: ["x-iroha-routed-by": "Proxy"]
            )
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateFanoutHeaders(
                invalidRouteProvenance
            )
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateFanoutHeaders(
                direct,
                requiresFanout: true
            )
        ) { error in
            guard case NexusToriiError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let complete = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: completeHeaders
            )
        )
        XCTAssertNoThrow(try NexusToriiClient.validateFanoutHeaders(complete))
        XCTAssertThrowsError(
            try NexusToriiClient.validateFanoutHeaderValues(
                {
                    (completeHeaders.merging([
                        "x-iroha-routed-by": "local",
                        "x-iroha-route-lane-id": "1",
                        "x-iroha-route-dataspace-id": "2"
                    ]) { _, new in new })[$0]
                },
                requiresFanout: true
            )
        )

        var partialHeaders = completeHeaders
        partialHeaders["x-iroha-fanout-first-failure"] = "route_unavailable"
        partialHeaders["x-iroha-fanout-routes-succeeded"] = "2"
        partialHeaders["x-iroha-fanout-routes-failed"] = "2"
        partialHeaders["x-iroha-fanout-routes-unavailable"] = "2"
        let partial = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: partialHeaders
            )
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateFanoutHeaders(partial)
        ) { error in
            guard case NexusToriiError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let incomplete = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["x-iroha-fanout-routes-attempted": "4"]
            )
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateFanoutHeaders(incomplete)
        ) { error in
            guard case NexusToriiError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        var malformedHeaders = completeHeaders
        malformedHeaders["x-iroha-fanout-routes-attempted"] = "04"
        let malformed = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: malformedHeaders
            )
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateFanoutHeaders(malformed)
        ) { error in
            guard case NexusToriiError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        var oversizedHeaders = completeHeaders
        oversizedHeaders["x-iroha-fanout-routes-attempted"] = "1025"
        oversizedHeaders["x-iroha-fanout-routes-succeeded"] = "1025"
        let oversized = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: oversizedHeaders
            )
        )
        XCTAssertThrowsError(
            try NexusToriiClient.validateFanoutHeaders(oversized)
        ) { error in
            guard case NexusToriiError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        func embeddedMCPResult(
            headers: [String: NexusJSONValue] = [:],
            status: NexusJSONValue = .number("200"),
            isError: NexusJSONValue = .bool(false),
            contentType: NexusJSONValue = .string("application/json"),
            body: NexusJSONValue = .object(["items": .array([])]),
            includesShadowBody: Bool = false,
            includesStructuredShadowItems: Bool = false
        ) -> NexusJSONValue {
            var structured: [String: NexusJSONValue] = [
                "status": status,
                "headers": .object(headers),
                "content_type": contentType,
                "body": body
            ]
            if includesStructuredShadowItems {
                structured["items"] = .array([])
            }
            var direct: [String: NexusJSONValue] = [
                "isError": isError,
                "structuredContent": .object(structured)
            ]
            if includesShadowBody {
                direct["body"] = .object(["items": .array([])])
            }
            return .object(direct)
        }
        XCTAssertNoThrow(
            try NexusMCPResultContract.validateEmbeddedRoute(
                embeddedMCPResult()
            )
        )
        XCTAssertThrowsError(
            try NexusMCPResultContract.validateEmbeddedRoute(
                embeddedMCPResult(),
                requiresFanout: true
            )
        )
        XCTAssertNoThrow(
            try NexusMCPResultContract.validateEmbeddedRoute(
                embeddedMCPResult(
                    contentType: .string("application/json; charset=UTF-8")
                )
            )
        )
        XCTAssertNoThrow(
            try NexusMCPEnvelopeContract.validate(
                jsonrpc: "2.0",
                responseID: "history-1",
                expectedID: "history-1",
                hasError: false
            )
        )
        XCTAssertThrowsError(
            try NexusMCPEnvelopeContract.validate(
                jsonrpc: "2.0",
                responseID: "history-2",
                expectedID: "history-1",
                hasError: false
            )
        )
        XCTAssertThrowsError(
            try NexusMCPEnvelopeContract.validate(
                jsonrpc: "2.0",
                responseID: "history-1",
                expectedID: "history-1",
                hasError: true
            )
        )
        XCTAssertNoThrow(
            try NexusMCPResultContract.validateEmbeddedRoute(
                embeddedMCPResult(
                    headers: completeHeaders.mapValues { .string($0) }
                ),
                requiresFanout: true
            )
        )
        XCTAssertThrowsError(
            try NexusMCPResultContract.validateEmbeddedRoute(
                embeddedMCPResult(
                    headers: [
                        "x-iroha-routed-by": .string("proxy")
                    ]
                ),
                requiresFanout: true
            )
        )
        for invalidMCPResult in [
            embeddedMCPResult(
                headers: [
                    "x-iroha-fanout-routes-attempted": .string("4")
                ]
            ),
            embeddedMCPResult(
                headers: ["x-iroha-routed-by": .string("Proxy")]
            ),
            embeddedMCPResult(
                headers: [
                    "x-iroha-routed-by": .string("proxy"),
                    "X-Iroha-Routed-By": .string("proxy")
                ]
            ),
            embeddedMCPResult(
                headers: ["x-iroha-routed-by": .number("1")]
            ),
            embeddedMCPResult(status: .number("500")),
            embeddedMCPResult(status: .string("200")),
            embeddedMCPResult(isError: .bool(true)),
            embeddedMCPResult(contentType: .string("text/plain")),
            embeddedMCPResult(
                contentType: .string("application/json; profile=unexpected")
            ),
            embeddedMCPResult(contentType: .string("application/json;")),
            embeddedMCPResult(
                contentType: .string("application/json, text/plain")
            ),
            embeddedMCPResult(body: .null),
            embeddedMCPResult(body: .string("not-an-object")),
            embeddedMCPResult(includesShadowBody: true),
            embeddedMCPResult(includesStructuredShadowItems: true),
            embeddedMCPResult(
                body: .null,
                includesStructuredShadowItems: true
            )
        ] {
            XCTAssertThrowsError(
                try NexusMCPResultContract.validateEmbeddedRoute(
                    invalidMCPResult
                )
            )
        }

        let account =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let otherAuthority =
            "sorauﾛ1NﾍﾖﾁﾘﾗoEuKﾗﾁK2ｴA9ｸxmxBﾈｴDﾋﾐﾐﾅｴjuXvｾﾍｵn5FAXTS3"
        let targetHash = String(repeating: "aa", count: 32)
        let otherHash = String(repeating: "bb", count: 32)
        let thirdHash = String(repeating: "cc", count: 32)
        let fourthHash = String(repeating: "dd", count: 32)
        func item(
            _ hash: String,
            authority: String? = account,
            succeeded: Bool = true
        ) -> NexusAccountTransactionList.Item {
            NexusAccountTransactionList.Item(
                authority: authority,
                timestampMilliseconds: 1,
                entrypointHash: hash,
                succeeded: succeeded
            )
        }
        func page(
            total: UInt64,
            _ items: [NexusAccountTransactionList.Item]
        ) -> NexusAccountTransactionList {
            NexusAccountTransactionList(
                items: items,
                total: total,
                hasMore: UInt64(items.count) < total,
                countMode: "exact"
            )
        }
        func proof(
            pageSize: Int = 100,
            maximumPages: Int = 20
        ) throws -> NexusAccountTransactionProof {
            try NexusAccountTransactionProof(
                account: account,
                configuration: .minamoto,
                transactionHash: targetHash,
                pageSize: pageSize,
                maximumPages: maximumPages
            )
        }

        var found = try proof()
        XCTAssertEqual(
            try found.accept(page(total: 1, [item(targetHash)])),
            .found
        )
        var absent = try proof()
        XCTAssertEqual(
            try absent.accept(page(total: 1, [item(otherHash)])),
            .absent
        )
        for invalid in [
            item(targetHash, succeeded: false),
            item(targetHash, authority: otherAuthority),
            item(targetHash, authority: nil),
        ] {
            var invalidProof = try proof()
            XCTAssertThrowsError(
                try invalidProof.accept(page(total: 1, [invalid]))
            )
        }

        var drift = try proof()
        XCTAssertEqual(
            try drift.accept(page(total: 2, [item(otherHash)])),
            .continueScanning
        )
        XCTAssertThrowsError(
            try drift.accept(page(total: 3, [item(thirdHash)]))
        )
        for invalidMetadata in [
            NexusAccountTransactionList(
                items: [item(targetHash)],
                total: 1,
                hasMore: false,
                countMode: "bounded"
            ),
            NexusAccountTransactionList(
                items: [item(targetHash)],
                total: 1,
                hasMore: true,
                countMode: "exact"
            )
        ] {
            var metadataProof = try proof()
            XCTAssertThrowsError(try metadataProof.accept(invalidMetadata))
        }

        var repeated = try proof()
        let repeatedPage = page(total: 3, [item(otherHash)])
        XCTAssertEqual(try repeated.accept(repeatedPage), .continueScanning)
        XCTAssertThrowsError(try repeated.accept(repeatedPage))

        var duplicate = try proof(pageSize: 2)
        XCTAssertEqual(
            try duplicate.accept(
                page(total: 4, [item(otherHash), item(thirdHash)])
            ),
            .continueScanning
        )
        XCTAssertThrowsError(
            try duplicate.accept(
                NexusAccountTransactionList(
                    items: [item(otherHash), item(fourthHash)],
                    total: 4,
                    hasMore: false,
                    countMode: "exact"
                )
            )
        )

        var emptyContinuation = try proof()
        XCTAssertThrowsError(
            try emptyContinuation.accept(page(total: 1, []))
        )
        var exhausted = try proof(maximumPages: 1)
        XCTAssertThrowsError(
            try exhausted.accept(page(total: 2, [item(otherHash)]))
        )

    }

    func testPIPaginationRejectsRepeatedNonEmptyPage() async throws {
        let client = PIIndexerClient()
        var requestedCursors: [String?] = []

        do {
            _ = try await client.collectPages(
                pageSize: 1,
                maximumPages: 3
            ) { cursor in
                requestedCursors.append(cursor)
                return PIConnection<String>(
                    nodes: ["same-node"],
                    edges: nil,
                    pageInfo: PIPageInfo(
                        hasNextPage: cursor == nil,
                        hasPreviousPage: cursor != nil,
                        startCursor: cursor,
                        endCursor: cursor == nil ? "next" : nil
                    ),
                    totalCount: 2
                )
            }
            XCTFail("Repeated pages must fail closed")
        } catch {
            guard case PIIndexerError.repeatedPage = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(requestedCursors.count, 2)
        XCTAssertNil(requestedCursors[0])
        XCTAssertEqual(requestedCursors[1], "next")

        do {
            _ = try await client.collectPages(
                pageSize: 1,
                maximumPages: 2
            ) { _ in
                PIConnection<String>(
                    nodes: ["node"],
                    edges: nil,
                    pageInfo: PIPageInfo(
                        hasNextPage: true,
                        hasPreviousPage: false,
                        startCursor: nil,
                        endCursor: String(
                            repeating: "x",
                            count: PIIndexerClient.maximumCursorBytes + 1
                        )
                    ),
                    totalCount: 2
                )
            }
            XCTFail("An unbounded PI cursor was accepted")
        } catch {
            guard case PIIndexerError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertThrowsError(
            try PIIndexerClient.validateCursor(
                String(
                    repeating: "x",
                    count: PIIndexerClient.maximumCursorBytes + 1
                )
            )
        ) { error in
            guard case PIIndexerError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertThrowsError(
            try PIIndexerClient.validateHistoryPage(
                PIIndexerClient.maximumHistoryPages + 1
            )
        ) { error in
            guard case PIIndexerError.paginationLimit = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertThrowsError(
            try PIIndexerClient.validateHistoryPage(
                0
            )
        ) { error in
            guard case PIIndexerError.paginationLimit = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPIHTTPResponseRejectsRedirectedOrNonJSONEndpoints() throws {
        let endpoint = try XCTUnwrap(
            URL(string: "https://pi.soramitsu.io/graphql")
        )
        let valid = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "application/json; charset=utf-8"
                ]
            )
        )
        XCTAssertNoThrow(
            try PIIndexerClient.validateHTTPResponse(
                valid,
                endpoint: endpoint
            )
        )

        let redirected = try XCTUnwrap(
            HTTPURLResponse(
                url: URL(string: "https://redirect.example/graphql")!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateHTTPResponse(
                redirected,
                endpoint: endpoint
            )
        )

        let equivalentAlias = try XCTUnwrap(
            HTTPURLResponse(
                url: URL(
                    string: "https://pi.soramitsu.io:443/graphql"
                )!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateHTTPResponse(
                equivalentAlias,
                endpoint: endpoint
            )
        )

        let nonJSON = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html"]
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateHTTPResponse(
                nonJSON,
                endpoint: endpoint
            )
        )

        let compressed = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "application/json",
                    "Content-Encoding": "gzip",
                ]
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateHTTPResponse(
                compressed,
                endpoint: endpoint
            )
        )

        let partial = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 206,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateHTTPResponse(
                partial,
                endpoint: endpoint
            )
        ) { error in
            guard case PIIndexerError.httpStatus(206) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPIExecutionEndpointIsPinnedToConsolidatedProductionOrigin() throws {
        XCTAssertNoThrow(
            try PIIndexerClient.validateProductionEndpoint(
                PIIndexerClient.endpoint
            )
        )
        for unreviewed in [
            "https://pi.soramitsu.io/graphql/",
            "https://PI.soramitsu.io/graphql",
            "https://pi.soramitsu.io:443/graphql",
            "https://pi.soramitsu.io/%67raphql",
            "https://pi.example/graphql",
            "http://pi.soramitsu.io/graphql",
        ] {
            XCTAssertThrowsError(
                try PIIndexerClient.validateProductionEndpoint(
                    XCTUnwrap(URL(string: unreviewed))
                )
            )
        }
    }

    func testPIRequestBodyIsBoundedBeforeTransport() {
        XCTAssertNoThrow(
            try PIIndexerClient.validateRequestBody(
                Data(repeating: 0, count: 256 * 1024)
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateRequestBody(
                Data(repeating: 0, count: 256 * 1024 + 1)
            )
        ) { error in
            guard case PIIndexerError.requestTooLarge = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertNoThrow(
            try PIIndexerClient.validateExpectedResponseLength(-1)
        )
        XCTAssertNoThrow(
            try PIIndexerClient.validateExpectedResponseLength(
                Int64(PIIndexerClient.maximumResponseBytes)
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateExpectedResponseLength(
                Int64(PIIndexerClient.maximumResponseBytes + 1)
            )
        ) { error in
            guard case PIIndexerError.responseTooLarge = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPIStrictJSONAdmissionRejectsDuplicateDecodedObjectNames() throws {
        try PIStrictJSONAdmission.validate(
            Data(
                #"{"data":{"emoji":"\uD83D\uDE00","value":-0.01e+2},"errors":null}"#.utf8
            )
        )
        let invalidDocuments = [
            #"{"data":1,"data":2}"#,
            #"{"data":{"id":"1","id":"2"}}"#,
            #"{"a":1,"\u0061":2}"#,
            #"{"\u00E9":1,"e\u0301":2}"#,
        ]
        for document in invalidDocuments {
            XCTAssertThrowsError(
                try PIStrictJSONAdmission.validate(Data(document.utf8))
            ) { error in
                guard case PIIndexerError.invalidResponse = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }
        let cachePayload = Data(
            #"{"data":{"id":"1"},"errors":null}"#.utf8
        )
        XCTAssertNoThrow(
            try PIResponseCacheAdmission.validatePayload(cachePayload)
        )
        XCTAssertThrowsError(
            try PIResponseCacheAdmission.validatePayload(
                Data(#"{"data":1,"data":2}"#.utf8)
            )
        )
        XCTAssertThrowsError(
            try PIResponseCacheAdmission.validateEnvelope(
                Data(#"{"payload":"e30=","payload":"e30="}"#.utf8)
            )
        )
    }

    func testPIStrictJSONAdmissionRejectsMalformedAndTrailingDocuments() {
        let invalidDocuments = [
            #"{'data':1}"#,
            #"{"data":NaN}"#,
            #"{"data":1,}"#,
            #"{"data":1} {"data":2}"#,
            #"/*comment*/{"data":1}"#,
            #"{"data":"\uD800"}"#,
            #"{"data":"\uDC00"}"#,
            #"{"data":"\uD800\u0041"}"#,
            #"{"data":01}"#,
            #"{"data":1.}"#,
            #"{"data":1e}"#,
        ]
        for document in invalidDocuments {
            XCTAssertThrowsError(
                try PIStrictJSONAdmission.validate(Data(document.utf8))
            ) { error in
                guard case PIIndexerError.invalidResponse = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }
        let invalidUTF8 = Data([
            0x7B, 0x22, 0x64, 0x61, 0x74, 0x61, 0x22, 0x3A,
            0x22, 0xFF, 0x22, 0x7D,
        ])
        XCTAssertThrowsError(
            try PIStrictJSONAdmission.validate(invalidUTF8)
        ) { error in
            guard case PIIndexerError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPIStrictJSONAdmissionBoundsBytesDepthAndTokenWork() {
        let cases: [(Data, Int, Int, Int)] = [
            (Data("1234".utf8), 3, 8, 8),
            (Data("[[[0]]]".utf8), 64, 3, 100),
            (Data("[0,1,2]".utf8), 64, 3, 3),
        ]
        for (data, bytes, depth, tokens) in cases {
            XCTAssertThrowsError(
                try PIStrictJSONAdmission.validate(
                    data,
                    maximumBytes: bytes,
                    maximumDepth: depth,
                    maximumTokens: tokens
                )
            ) { error in
                guard case PIIndexerError.invalidResponse = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }

    func testPIConnectionPageIsValidatedBeforeCacheEligibility() throws {
        let valid = PIConnection<String>(
            nodes: ["one"],
            edges: nil,
            pageInfo: PIPageInfo(
                hasNextPage: false,
                hasPreviousPage: false,
                startCursor: nil,
                endCursor: nil
            ),
            totalCount: 1
        )
        XCTAssertNoThrow(
            try PIIndexerClient.validateConnectionPage(
                valid,
                requestedSize: 1,
                hasPriorPage: false,
                itemIdentity: { $0 }
            )
        )

        let oversized = PIConnection<String>(
            nodes: ["one", "two"],
            edges: nil,
            pageInfo: PIPageInfo(
                hasNextPage: false,
                hasPreviousPage: false,
                startCursor: nil,
                endCursor: nil
            ),
            totalCount: 2
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateConnectionPage(
                oversized,
                requestedSize: 1,
                hasPriorPage: false,
                itemIdentity: { $0 }
            )
        )

        let oversizedCursor = PIConnection<String>(
            nodes: ["one"],
            edges: nil,
            pageInfo: PIPageInfo(
                hasNextPage: true,
                hasPreviousPage: false,
                startCursor: nil,
                endCursor: String(
                    repeating: "x",
                    count: PIIndexerClient.maximumCursorBytes + 1
                )
            ),
            totalCount: 2
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateConnectionPage(
                oversizedCursor,
                requestedSize: 1,
                hasPriorPage: false,
                itemIdentity: { $0 }
            )
        )
    }

    func testPIPaginationRejectsOverlappingItemIdentities() async throws {
        let client = PIIndexerClient()
        let qualification = makePIQualification(indexedBlock: 100)
        var page = 0

        do {
            _ = try await client.collectQualifiedPages(
                pageSize: 2,
                maximumPages: 2,
                itemIdentity: { $0 }
            ) { cursor in
                defer { page += 1 }
                return PIQualifiedRead(
                    value: PIConnection<String>(
                        nodes: page == 0
                            ? ["overlap", "first"]
                            : ["overlap", "second"],
                        edges: nil,
                        pageInfo: PIPageInfo(
                            hasNextPage: page == 0,
                            hasPreviousPage: cursor != nil,
                            startCursor: cursor,
                            endCursor: page == 0 ? "next" : nil
                        ),
                        totalCount: 4
                    ),
                    qualification: qualification
                )
            }
            XCTFail("PI accepted an item repeated across cursor pages")
        } catch {
            guard case PIIndexerError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPIPaginationRejectsMixedCacheSourceOrCheckpoint() async throws {
        let client = PIIndexerClient()
        let now = 2_000_000
        func health(_ height: Int) -> PIHealth {
            PIHealth(
                ok: true,
                repositoryReady: true,
                service: "polkaswap-indexer",
                serviceId: "pi.soramitsu.io",
                schemaVersion: 1,
                ecosystem: "sora2",
                chainId: "sora:mainnet",
                network: "mainnet",
                publicBaseUrl: PIIndexerClient.endpoint,
                readOnly: true,
                genesisHash: PIIndexerClient.soraMainnetGenesis,
                latestIndexedBlock: height,
                latestIndexedBlockHash:
                    "0x1111111111111111111111111111111111111111111111111111111111111111",
                latestIndexedAt: now,
                workerAvailable: true,
                workerReady: true,
                workerReadinessReason: nil,
                workerLifecycle: "running",
                workerStartupComplete: true,
                workerLatestFinalizedBlock: height,
                workerLatestIndexedBlock: height,
                workerLag: 0,
                workerLastSuccessfulIndexTimestamp: now,
                workerLastError: nil,
                workerLastErrorTimestamp: nil
            )
        }

        let first = PIReadQualification(
            health: health(100),
            source: .live
        )
        let incompatible = [
            PIReadQualification(health: health(100), source: .cache),
            PIReadQualification(health: health(101), source: .live),
        ]
        for second in incompatible {
            var page = 0
            do {
                _ = try await client.collectQualifiedPages(
                    pageSize: 1,
                    maximumPages: 2
                ) { cursor in
                    defer { page += 1 }
                    return PIQualifiedRead(
                        value: PIConnection<String>(
                            nodes: [page == 0 ? "first" : "second"],
                            edges: nil,
                            pageInfo: PIPageInfo(
                                hasNextPage: page == 0,
                                hasPreviousPage: cursor != nil,
                                startCursor: cursor,
                                endCursor: page == 0 ? "next" : nil
                            ),
                            totalCount: 2
                        ),
                        qualification: page == 0 ? first : second
                    )
                }
                XCTFail("PI composed pages from incompatible qualifications")
            } catch {
                guard case PIIndexerError.staleCheckpoint = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }

        let qualified = try await client.collectQualifiedPagesRead(
            pageSize: 1,
            maximumPages: 1
        ) { cursor in
            XCTAssertNil(cursor)
            return PIQualifiedRead(
                value: PIConnection<String>(
                    nodes: ["only"],
                    edges: nil,
                    pageInfo: PIPageInfo(
                        hasNextPage: false,
                        hasPreviousPage: false,
                        startCursor: nil,
                        endCursor: nil
                    ),
                    totalCount: 1
                ),
                qualification: first
            )
        }
        XCTAssertEqual(qualified.value, ["only"])
        XCTAssertEqual(qualified.qualification, first)
    }

    func testPIPaginationRejectsServerOverDelivery() async throws {
        let client = PIIndexerClient()
        do {
            _ = try await client.collectPages(
                pageSize: 1,
                maximumPages: 1
            ) { _ in
                PIConnection<String>(
                    nodes: ["one", "two"],
                    edges: nil,
                    pageInfo: PIPageInfo(
                        hasNextPage: false,
                        hasPreviousPage: false,
                        startCursor: nil,
                        endCursor: nil
                    ),
                    totalCount: 2
                )
            }
            XCTFail("An oversized PI page was accepted")
        } catch {
            guard case PIIndexerError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPIPaginationRequiresExactlyOneConnectionRepresentation()
        async throws
    {
        let client = PIIndexerClient()
        do {
            _ = try await client.collectPages(
                pageSize: 1,
                maximumPages: 1
            ) { _ in
                PIConnection<String>(
                    nodes: nil,
                    edges: nil,
                    pageInfo: PIPageInfo(
                        hasNextPage: false,
                        hasPreviousPage: false,
                        startCursor: nil,
                        endCursor: nil
                    ),
                    totalCount: 0
                )
            }
            XCTFail("A PI page without nodes or edges was accepted")
        } catch {
            guard case PIIndexerError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPICacheFallbackAllowsOnlyTransientTransportErrors() {
        XCTAssertTrue(
            PIIndexerClient.allowsOfflineTransportFallback(
                URLError(.notConnectedToInternet)
            )
        )
        XCTAssertTrue(
            PIIndexerClient.allowsOfflineTransportFallback(
                URLError(.timedOut)
            )
        )
        XCTAssertFalse(
            PIIndexerClient.allowsOfflineTransportFallback(
                URLError(.cancelled)
            )
        )
        XCTAssertFalse(
            PIIndexerClient.allowsOfflineTransportFallback(
                URLError(.serverCertificateUntrusted)
            )
        )
        XCTAssertTrue(PIIndexerError.httpStatus(408).allowsOfflineFallback)
        XCTAssertTrue(PIIndexerError.httpStatus(429).allowsOfflineFallback)
        XCTAssertTrue(PIIndexerError.httpStatus(503).allowsOfflineFallback)
        XCTAssertFalse(PIIndexerError.httpStatus(404).allowsOfflineFallback)
        XCTAssertFalse(PIIndexerError.invalidResponse.allowsOfflineFallback)
        XCTAssertFalse(PIIndexerError.responseTooLarge.allowsOfflineFallback)
    }

    func testValidatedPIHistoryCacheSurvivesRestartAndExpires()
        async throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let address = "cnTestAccount"
        let blockHash = "0x" + String(repeating: "ab", count: 32)
        let transactionHash = "0x" +
            String(repeating: "cd", count: 32)
        let element = try JSONDecoder().decode(
            PIHistoryElement.self,
            from: JSONSerialization.data(
                withJSONObject: [
                    "id": transactionHash,
                    "timestamp": 1,
                    "address": address,
                    "blockHash": blockHash,
                    "blockHeight": 7,
                    "networkFee": "0",
                    "execution": ["success": true],
                ]
            )
        )
        let first = PIValidatedHistoryCache(baseURL: directory)
        await first.save(
            address: address,
            count: 10,
            page: 1,
            finalizedCheckpoint: 7,
            indexedCheckpointHash: blockHash,
            endCursor: nil,
            endReached: true,
            elements: [element]
        )

        let reopened = PIValidatedHistoryCache(baseURL: directory)
        let restored = await reopened.load(
            address: address,
            count: 10,
            page: 1
        )
        XCTAssertEqual(restored?.elements, [element])
        let crossAccount = await reopened.load(
            address: "cnOtherAccount",
            count: 10,
            page: 1
        )
        XCTAssertNil(crossAccount)

        await reopened.save(
            address: address,
            count: 10,
            page: 1,
            finalizedCheckpoint: 7,
            indexedCheckpointHash: blockHash,
            endCursor: nil,
            endReached: true,
            elements: [element],
            savedAt: Date(timeIntervalSinceNow: -(25 * 60 * 60))
        )
        let expired = await reopened.load(
            address: address,
            count: 10,
            page: 1
        )
        XCTAssertNil(expired)
    }

    func testValidatedPIHistoryCacheRejectsSymbolicLinkEntry()
        async throws
    {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? fileManager.removeItem(at: directory)
        }
        let address = "cnTestAccount"
        let blockHash = "0x" + String(repeating: "ab", count: 32)
        let transactionHash = "0x" + String(repeating: "cd", count: 32)
        let element = try JSONDecoder().decode(
            PIHistoryElement.self,
            from: JSONSerialization.data(
                withJSONObject: [
                    "id": transactionHash,
                    "timestamp": 1,
                    "address": address,
                    "blockHash": blockHash,
                    "blockHeight": 7,
                    "networkFee": "0",
                    "execution": ["success": true],
                ]
            )
        )
        let cache = PIValidatedHistoryCache(
            baseURL: directory,
            fileManager: fileManager
        )
        await cache.save(
            address: address,
            count: 10,
            page: 1,
            finalizedCheckpoint: 7,
            indexedCheckpointHash: blockHash,
            endCursor: nil,
            endReached: true,
            elements: [element]
        )

        let cacheDirectory = directory.appendingPathComponent(
            "PIValidatedHistoryV1",
            isDirectory: true
        )
        let cacheFiles = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        XCTAssertEqual(cacheFiles.count, 1)
        let cacheFile = try XCTUnwrap(cacheFiles.first)
        let outsideFile = directory.appendingPathComponent("outside.json")
        try fileManager.copyItem(at: cacheFile, to: outsideFile)
        try fileManager.removeItem(at: cacheFile)
        try fileManager.createSymbolicLink(
            at: cacheFile,
            withDestinationURL: outsideFile
        )

        let restored = await cache.load(
            address: address,
            count: 10,
            page: 1
        )
        XCTAssertNil(restored)
        XCTAssertTrue(fileManager.fileExists(atPath: outsideFile.path))
    }

    func testLegacyHistoryPaginationRoundTripsNumericAndStringContexts() {
        let numeric = TransactionHistoryContext(
            cursor: 7,
            isComplete: true
        )
        let numericRoundTrip = TransactionHistoryContext(
            context: numeric.toContext()
        )
        XCTAssertEqual(numericRoundTrip.cursor, 7)
        XCTAssertTrue(numericRoundTrip.isComplete)

        let stringRoundTrip = TransactionHistoryContext(
            context: [
                TransactionHistoryContext.cursor: "9",
                TransactionHistoryContext.isComplete: "false"
            ]
        )
        XCTAssertEqual(stringRoundTrip.cursor, 9)
        XCTAssertFalse(stringRoundTrip.isComplete)
    }

    func testScaleCallEncodingUsesNonContiguousMetadataV14Discriminants() throws {
        let calls: [RuntimeFunctionMetadata] = [
            IndexedRuntimeFunction(name: "buy", index: 2),
            IndexedRuntimeFunction(name: "sell", index: 3),
            IndexedRuntimeFunction(name: "claim_market", index: 22),
            IndexedRuntimeFunction(name: "claim_creator_fees", index: 23),
            IndexedRuntimeFunction(name: "claim_markets", index: 32)
        ]

        // These values are the second byte GenericCallNode writes after the
        // live metadata pallet index. Array offsets 2, 3 and 4 would construct
        // different calls and must never be used for metadata v14.
        XCTAssertEqual(
            RuntimeMetadata.resolveCallIndex(in: calls, callName: "claim_market"),
            22
        )
        XCTAssertEqual(
            RuntimeMetadata.resolveCallIndex(in: calls, callName: "claim_markets"),
            32
        )
        XCTAssertNotEqual(
            RuntimeMetadata.resolveCallIndex(in: calls, callName: "claim_markets"),
            UInt8(calls.count - 1)
        )
    }

    func testScaleCallEncodingKeepsLegacyPositionalFallback() {
        let calls: [RuntimeFunctionMetadata] = [
            IndexedRuntimeFunction(name: "first", index: nil),
            IndexedRuntimeFunction(name: "second", index: nil)
        ]

        XCTAssertEqual(
            RuntimeMetadata.resolveCallIndex(in: calls, callName: "second"),
            1
        )
    }

    func testPolkamarktOutcomeUsesScaleUnitVariantShape() throws {
        let call = RuntimeCall.polkamarktBuy(
            PolkamarktBuyCall(
                marketId: 7,
                outcome: .yes,
                collateralIn: 1_000,
                minSharesOut: 900
            )
        )
        let data = try JSONEncoder.scaleCompatible().encode(call)
        let outer = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [Any]
        )
        let namedCall = try XCTUnwrap(outer[1] as? [Any])
        let arguments = try XCTUnwrap(namedCall[1] as? [String: Any])
        let encodedOutcome = try XCTUnwrap(arguments["outcome"] as? [Any])

        XCTAssertEqual(Set(arguments.keys), [
            "market_id",
            "outcome",
            "collateral_in",
            "min_shares_out"
        ])
        XCTAssertEqual(
            (arguments["market_id"] as? NSNumber)?.uint32Value,
            7
        )
        XCTAssertEqual(arguments["collateral_in"] as? String, "1000")
        XCTAssertEqual(arguments["min_shares_out"] as? String, "900")
        XCTAssertEqual(encodedOutcome[0] as? String, "Yes")
        XCTAssertTrue(encodedOutcome[1] is NSNull)

        let sell = RuntimeCall.polkamarktSell(
            PolkamarktSellCall(
                marketId: 8,
                outcome: .no,
                sharesIn: 700,
                minCollateralOut: 600
            )
        )
        let sellData = try JSONEncoder.scaleCompatible().encode(sell)
        let sellOuter = try XCTUnwrap(
            JSONSerialization.jsonObject(with: sellData) as? [Any]
        )
        let sellCall = try XCTUnwrap(sellOuter[1] as? [Any])
        let sellArguments = try XCTUnwrap(sellCall[1] as? [String: Any])
        XCTAssertEqual(Set(sellArguments.keys), [
            "market_id",
            "outcome",
            "shares_in",
            "min_collateral_out"
        ])

        let batch = RuntimeCall.polkamarktBatchClaim(
            PolkamarktBatchClaimCall(marketIds: [1, 2])
        )
        let batchData = try JSONEncoder.scaleCompatible().encode(batch)
        let batchOuter = try XCTUnwrap(
            JSONSerialization.jsonObject(with: batchData) as? [Any]
        )
        let batchCall = try XCTUnwrap(batchOuter[1] as? [Any])
        let batchArguments = try XCTUnwrap(batchCall[1] as? [String: Any])
        XCTAssertEqual(Set(batchArguments.keys), ["market_ids"])
    }

    func testPolkamarktScaleUnitVariantsRejectTrailingOrNonNullPayloads() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PolkamarktOutcome.self,
                from: Data(#"["Yes","unexpected"]"#.utf8)
            )
        )
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PolkamarktOutcome.self,
                from: Data(#"["Yes",null,"unexpected"]"#.utf8)
            )
        )
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PolkamarktMarketStatus.self,
                from: Data(#"["Open","unexpected"]"#.utf8)
            )
        )
    }

    func testPinnedPolkamarktRuntimeContract() throws {
        XCTAssertEqual(
            PolkamarktRuntimeContract.sora2NetworkRevision,
            "411dcdb70c5c00b21482a44d02334840d5f338c6"
        )
        XCTAssertEqual(PolkamarktRuntimeContract.specVersion, 130)
        XCTAssertEqual(PolkamarktRuntimeContract.transactionVersion, 130)
        XCTAssertEqual(
            PolkamarktRuntimeContract.metadataFileSHA256,
            "2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf"
        )
        XCTAssertEqual(
            PolkamarktRuntimeContract.webContractCommitTree,
            "e391982c0921dea5278e919a7558b7a6a2afc0d4"
        )
        XCTAssertEqual(
            PolkamarktRuntimeContract.webContractSourceTree,
            "57f0fe7623f2b93b34faecfc66d6c5da96d54e1b"
        )
        XCTAssertEqual(
            PolkamarktRuntimeContract.webContractSourceFileCount,
            22
        )
        XCTAssertEqual(PolkamarktRuntimeContract.maximumBatchClaims, 24)
        XCTAssertEqual(
            PolkamarktRuntimeContract.maximumMarketId,
            4_294_967_295
        )
        XCTAssertEqual(
            PolkamarktRuntimeContract.maximumCloseBlock,
            4_294_967_295
        )
        XCTAssertEqual(
            Set(PolkamarktRuntimeContract.Call.required),
            Set([
                "buy",
                "sell",
                "claim_market",
                "claim_markets",
                "claim_creator_fees"
            ])
        )

        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Fixtures/Modernization/polkamarkt-runtime-v130.json"
            )
        let fixture = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: fixtureURL)
            ) as? [String: Any]
        )
        let claimConfirmation = try XCTUnwrap(
            fixture["mobileClaimConfirmation"] as? [String: Any]
        )
        XCTAssertEqual(
            PolkamarktRuntimeContract.ClaimConfirmation
                .requiresExplicitConfirmation,
            true
        )
        XCTAssertEqual(
            claimConfirmation["requiresExplicitConfirmation"] as? Bool,
            PolkamarktRuntimeContract.ClaimConfirmation
                .requiresExplicitConfirmation
        )
        XCTAssertEqual(
            claimConfirmation["requiredReviewedFields"] as? [String],
            PolkamarktRuntimeContract.ClaimConfirmation
                .requiredReviewedFields
        )
        XCTAssertEqual(
            claimConfirmation["freshChecksBeforeSigning"] as? [String],
            PolkamarktRuntimeContract.ClaimConfirmation
                .freshChecksBeforeSigning
        )
        let claimConfirmationCopy = try XCTUnwrap(
            claimConfirmation["copy"] as? [String: String]
        )
        XCTAssertEqual(
            claimConfirmationCopy["title"],
            PolkamarktRuntimeContract.ClaimConfirmation.title
        )
        XCTAssertEqual(
            claimConfirmationCopy["batchTitle"],
            PolkamarktRuntimeContract.ClaimConfirmation.batchTitle
        )
        XCTAssertEqual(
            claimConfirmationCopy["body"],
            PolkamarktRuntimeContract.ClaimConfirmation.body
        )
        XCTAssertEqual(
            claimConfirmationCopy["feeNotice"],
            PolkamarktRuntimeContract.ClaimConfirmation.feeNotice
        )
        let canonicalVectors = try XCTUnwrap(
            fixture["canonicalVectors"] as? [String: Any]
        )
        let minimumOutputVectors = try XCTUnwrap(
            canonicalVectors["minimumOutput"] as? [[String: Any]]
        )
        XCTAssertFalse(minimumOutputVectors.isEmpty)
        for vector in minimumOutputVectors {
            let quoteOutput = try XCTUnwrap(
                BigUInt(try XCTUnwrap(vector["quotedOutput"] as? String))
            )
            let expectedMinimum = try XCTUnwrap(
                BigUInt(try XCTUnwrap(vector["expectedMinimum"] as? String))
            )
            let slippage = try XCTUnwrap(
                (vector["slippageBps"] as? NSNumber)?.uint16Value
            )
            XCTAssertEqual(
                try PolkamarktQuoteValidator.minimumOutput(
                    quoteOutput: quoteOutput,
                    slippageBasisPoints: slippage
                ),
                expectedMinimum
            )
        }

        let qualification = try XCTUnwrap(
            canonicalVectors["fullExtrinsicQualification"] as? [String: Any]
        )
        XCTAssertEqual(
            qualification["receiptSchema"] as? String,
            "sora-mobile-polkamarkt-full-extrinsic-receipt-v1"
        )
        XCTAssertEqual(
            qualification["requiredMetadataSha256"] as? String,
            PolkamarktRuntimeContract.metadataFileSHA256
        )
        XCTAssertEqual(
            qualification["requiredGenesisHash"] as? String,
            PIIndexerClient.soraMainnetGenesis
        )
        XCTAssertEqual(
            (qualification["requiredSpecVersion"] as? NSNumber)?.uint32Value,
            PolkamarktRuntimeContract.specVersion
        )
        XCTAssertEqual(
            (qualification["requiredTransactionVersion"] as? NSNumber)?
                .uint32Value,
            PolkamarktRuntimeContract.transactionVersion
        )
        XCTAssertEqual(
            qualification["metadataIndicesMustBeResolvedDynamically"] as? Bool,
            true
        )
        XCTAssertEqual(
            qualification["requiredVectorOrder"] as? [String],
            PolkamarktRuntimeContract.Call.required
        )
        let generation = try XCTUnwrap(
            qualification["generationContract"] as? [String: Any]
        )
        XCTAssertEqual(
            generation["candidateReceiptSchema"] as? String,
            "sora-mobile-polkamarkt-platform-extrinsic-receipt-v1"
        )
        XCTAssertEqual(
            generation["independentReviewSchema"] as? String,
            "sora-mobile-polkamarkt-extrinsic-review-v1"
        )
        XCTAssertEqual(
            generation["merger"] as? String,
            "scripts/qualify-polkamarkt-extrinsic-receipts.mjs"
        )
        let reference = try XCTUnwrap(
            generation["referenceImplementation"] as? [String: Any]
        )
        XCTAssertEqual(
            reference["revision"] as? String,
            PolkamarktRuntimeContract.webContractRevision
        )
        XCTAssertEqual(reference["package"] as? String, "polkadotApi")
        XCTAssertEqual(reference["packageVersion"] as? String, "11.2.1")
        let metadata = try XCTUnwrap(
            generation["runtimeMetadata"] as? [String: Any]
        )
        XCTAssertEqual(
            metadata["sha256"] as? String,
            PolkamarktRuntimeContract.metadataFileSHA256
        )
        XCTAssertEqual(
            metadata["palletAndCallIndices"] as? String,
            "resolve-from-this-metadata-never-hardcode"
        )
        let signing = try XCTUnwrap(
            generation["signingContext"] as? [String: Any]
        )
        XCTAssertEqual(signing["cryptoType"] as? String, "sr25519")
        XCTAssertEqual(
            (signing["signaturePayloadHashingThresholdBytes"] as? NSNumber)?
                .intValue,
            ExtrinsicBuilder.payloadHashingTreshold
        )
        XCTAssertEqual(
            signing["privateSigningMaterialPermittedInFixture"] as? Bool,
            false
        )
        XCTAssertEqual(
            generation["cryptographicProofSchema"] as? String,
            "sora-mobile-polkamarkt-native-cryptographic-proof-v1"
        )
        XCTAssertEqual(
            generation["requiredCryptographicProofClaims"] as? [String],
            [
                "candidate-identity-bound",
                "sr25519-signatures-verified-over-reconstructed-signing-prehashes",
                "signed-extrinsics-decoded-through-pinned-live-metadata",
                "decoded-projections-match-canonical-runtime-call-vectors",
                "signed-extrinsic-hashes-recomputed",
                "non-production-qualification-account-used",
                "private-signing-material-absent-from-receipts"
            ]
        )
        XCTAssertEqual(
            generation["requiredSharedVectorFields"] as? [String],
            [
                "id",
                "call",
                "arguments",
                "metadataPalletIndex",
                "metadataCallIndex",
                "scaleArgumentsHex",
                "fullCallHex",
                "rawSigningPayloadHex",
                "signingPrehashHex",
                "signingPrehashRule",
                "decodedProjection",
                "decodedProjectionSha256"
            ]
        )
        XCTAssertEqual(
            generation["requiredPlatformVectorFields"] as? [String],
            [
                "id",
                "signerPublicKeyHex",
                "signatureHex",
                "signedExtrinsicHex",
                "extrinsicHashHex",
                "signingPrehashHex",
                "decodedProjection",
                "decodedProjectionSha256"
            ]
        )
        XCTAssertEqual(
            generation["parityRules"] as? [String],
            [
                "reference-android-ios-full-call-bytes-equal",
                "reference-android-ios-signing-prehash-equal",
                "reference-android-ios-decoded-projection-sha256-equal",
                "each-platform-reviewed-cryptographic-proof-signature-verifies",
                "each-proof-binds-source-metadata-context-vectors-and-signed-extrinsics",
                "each-proof-attests-sr25519-verification-and-live-metadata-round-trip",
                "sr25519-signature-bytes-may-differ-but-must-verify"
            ]
        )
        let hasReviewedExtrinsicReceipt = try XCTUnwrap(
            qualification["reviewedWebAndRuntimeReceiptQualified"] as? Bool
        )
        if hasReviewedExtrinsicReceipt {
            XCTAssertTrue(qualification["blocker"] is NSNull)
            let receipt = try XCTUnwrap(
                qualification["reviewedReceipt"] as? [String: Any]
            )
            XCTAssertEqual(
                receipt["format"] as? String,
                qualification["receiptSchema"] as? String
            )
            XCTAssertEqual(
                receipt["metadataSha256"] as? String,
                qualification["requiredMetadataSha256"] as? String
            )
            XCTAssertEqual(
                receipt["genesisHash"] as? String,
                qualification["requiredGenesisHash"] as? String
            )
            XCTAssertEqual(
                (receipt["sharedVectors"] as? [[String: Any]])?.count,
                PolkamarktRuntimeContract.Call.required.count
            )
            let platforms = try XCTUnwrap(
                receipt["platforms"] as? [String: Any]
            )
            for platform in ["reference", "android", "ios"] {
                let platformReceipt = try XCTUnwrap(
                    platforms[platform] as? [String: Any]
                )
                XCTAssertEqual(
                    (platformReceipt["vectors"] as? [[String: Any]])?.count,
                    PolkamarktRuntimeContract.Call.required.count
                )
                XCTAssertTrue(
                    try XCTUnwrap(
                        platformReceipt["candidateReceiptSha256"] as? String
                    ).range(
                        of: "^[0-9a-f]{64}$",
                        options: .regularExpression
                    ) != nil
                )
                let cryptographicProof = platformReceipt[
                    "cryptographicProof"
                ] as? [String: Any]
                XCTAssertEqual(
                    cryptographicProof?["format"] as? String,
                    "sora-mobile-polkamarkt-native-cryptographic-proof-v1"
                )
            }
            let review = try XCTUnwrap(receipt["review"] as? [String: Any])
            let reviewKeySha256 = try XCTUnwrap(
                review["publicKeySha256"] as? String
            )
            XCTAssertTrue(
                reviewKeySha256.range(
                    of: "^[0-9a-f]{64}$",
                    options: .regularExpression
                ) != nil
            )
            XCTAssertNotEqual(
                reviewKeySha256,
                String(repeating: "0", count: 64)
            )
            XCTAssertEqual(receipt["parityQualified"] as? Bool, true)
        } else {
            XCTAssertTrue(qualification["reviewedReceipt"] is NSNull)
            XCTAssertEqual(
                qualification["blocker"] as? String,
                "Generate independent reference, Android, and iOS receipts from the pinned web revision and exact runtime metadata; independently sign the composite receipt; then prove full call bytes, signing prehashes, signatures, signed extrinsics, and decoded projections before enabling mutations."
            )
        }

        let releaseVerifierURL = fixtureURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "SoraPassport/Scripts/verify-modernization-dependencies.sh"
            )
        let releaseVerifier = try XCTUnwrap(
            String(
                data: Data(contentsOf: releaseVerifierURL),
                encoding: .utf8
            )
        )
        for requiredParityGate in [
            "POLKAMARKT_ANDROID_SOURCE_ROOT",
            "POLKAMARKT_ANDROID_SOURCE_REVISION",
            "POLKAMARKT_ANDROID_FIXTURE_PATH",
            "POLKAMARKT_NODE_BINARY",
            "POLKAMARKT_NODE_BINARY_SHA256",
            "--validate-qualified",
            "POLKAMARKT_QUALIFIED_FIXTURE_VALID",
            "/usr/bin/git -C",
            "/usr/bin/cmp -s"
        ] {
            XCTAssertTrue(
                releaseVerifier.contains(requiredParityGate),
                "missing iOS Release parity gate: \(requiredParityGate)"
            )
        }

        let translationKeys = try XCTUnwrap(
            fixture["translationKeys"] as? [String: String]
        )
        let expectedTranslationKeys: Set<String> = [
            "pageTitle.Polkamarkt",
            "polkamarkt.outcomes.yes",
            "polkamarkt.outcomes.no",
            "polkamarkt.actions.buy",
            "polkamarkt.actions.sell",
            "polkamarkt.actions.claimTraderPayout",
            "polkamarkt.actions.claimCreatorFees",
            "polkamarkt.ticket.sharesOut",
            "polkamarkt.ticket.collateralOut",
            "polkamarkt.ticket.slippage",
            "polkamarkt.ticket.takerFee",
            "networkFeeText"
        ]
        XCTAssertEqual(Set(translationKeys.values), expectedTranslationKeys)

        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let localizableRoot = sourceRoot.appendingPathComponent(
            "SoraPassport/SoraLocalizable",
            isDirectory: true
        )
        let localeDirectories = try FileManager.default
            .contentsOfDirectory(
                at: localizableRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension == "lproj" }
        XCTAssertEqual(localeDirectories.count, 31)
        for localeDirectory in localeDirectories {
            let strings = try String(
                contentsOf: localeDirectory.appendingPathComponent(
                    "Localizable.strings"
                ),
                encoding: .utf8
            )
            for key in expectedTranslationKeys {
                let marker = "\"\(key)\" = \""
                let parts = strings.components(separatedBy: marker)
                XCTAssertEqual(
                    parts.count,
                    2,
                    "\(key) must occur exactly once in \(localeDirectory.lastPathComponent)"
                )
                guard
                    parts.count == 2,
                    let end = parts[1].range(of: "\";")
                else {
                    continue
                }
                let localizedValue = String(parts[1][..<end.lowerBound])
                XCTAssertFalse(localizedValue.isEmpty)
                XCTAssertNotEqual(localizedValue, key)
            }
        }
    }

    func testSora2SigningIdentityRejectsVersionOrMetadataSubstitution()
        throws
    {
        let reviewedHash = PolkamarktRuntimeContract.metadataFileSHA256
        let reviewedGenesis = PIIndexerClient.soraMainnetGenesis
        XCTAssertEqual(
            try? Sora2BoundedHTTPJSONRPCEngine.httpEndpoint(
                for: URL(string: "wss://mof2.sora.org")
            ).absoluteString,
            "https://mof2.sora.org/"
        )
        XCTAssertThrowsError(
            try Sora2BoundedHTTPJSONRPCEngine.httpEndpoint(
                for: URL(string: "ws://mof2.sora.org")
            )
        )
        XCTAssertThrowsError(
            try Sora2BoundedHTTPJSONRPCEngine.httpEndpoint(
                for: URL(string: "wss://user@mof2.sora.org")
            )
        )
        XCTAssertTrue(
            Sora2BoundedHTTPJSONRPCEngine.acceptsJSONContentType(
                "application/json; charset=utf-8"
            )
        )
        XCTAssertFalse(
            Sora2BoundedHTTPJSONRPCEngine.acceptsJSONContentType(
                "application/json; charset=utf-8; profile=unsafe"
            )
        )
        XCTAssertTrue(
            Sora2BoundedHTTPJSONRPCEngine.isAllowedMethod(
                SoraPassport.RPCMethod.submitExtrinsic
            )
        )
        XCTAssertTrue(
            Sora2BoundedHTTPJSONRPCEngine.isAllowedMethod(
                RPCMethod.needsMigration
            )
        )
        XCTAssertFalse(
            Sora2BoundedHTTPJSONRPCEngine.isAllowedMethod(
                RPCMethod.submitExtrinsicAndWatch
            )
        )
        XCTAssertTrue(
            Sora2BoundedHTTPJSONRPCEngine.isCanonicalSignedExtrinsic(
                "0x2801"
            )
        )
        XCTAssertFalse(
            Sora2BoundedHTTPJSONRPCEngine.isCanonicalSignedExtrinsic(
                "0x28AF"
            )
        )
        XCTAssertNoThrow(
            try Sora2BoundedHTTPJSONRPCEngine
                .validateExpectedResponseLength(-1)
        )
        XCTAssertThrowsError(
            try Sora2BoundedHTTPJSONRPCEngine
                .validateExpectedResponseLength(
                    Int64(
                        Sora2BoundedHTTPJSONRPCEngine
                            .maximumResponseBytes + 1
                    )
                )
        )
        XCTAssertNoThrow(
            try Sora2BoundedHTTPJSONRPCEngine.validateEnvelope(
                Data(
                    #"{"jsonrpc":"2.0","id":7,"result":"0x01"}"#.utf8
                ),
                identifier: 7
            )
        )
        XCTAssertThrowsError(
            try Sora2BoundedHTTPJSONRPCEngine.validateEnvelope(
                Data(
                    #"{"jsonrpc":"2.0","id":8,"result":"0x01"}"#.utf8
                ),
                identifier: 7
            )
        )
        XCTAssertThrowsError(
            try Sora2BoundedHTTPJSONRPCEngine.validateEnvelope(
                Data(
                    #"{"jsonrpc":"2.0","id":7,"result":"0x01","error":{"code":-1,"message":"bad"}}"#.utf8
                ),
                identifier: 7
            )
        )
        XCTAssertTrue(
            PolkamarktRuntimeContract.matchesReviewedGenesisHash(
                reviewedGenesis
            )
        )
        XCTAssertFalse(
            PolkamarktRuntimeContract.matchesReviewedGenesisHash(
                "0x" + String(repeating: "0", count: 64)
            )
        )
        XCTAssertFalse(
            PolkamarktRuntimeContract.matchesReviewedGenesisHash(
                String(reviewedGenesis.dropFirst(2))
            )
        )
        XCTAssertFalse(
            PolkamarktRuntimeContract.matchesReviewedGenesisHash(
                reviewedGenesis.uppercased()
            )
        )
        let sampleMetadata = Data([0x00, 0x01, 0xff])
        XCTAssertEqual(
            PolkamarktRuntimeContract.wireMetadataSHA256("0x0001ff"),
            PolkamarktRuntimeContract.rawMetadataSHA256(sampleMetadata)
        )
        XCTAssertNil(
            PolkamarktRuntimeContract.wireMetadataSHA256("0x0001FF")
        )
        XCTAssertTrue(
            ReviewedSoraRuntimeSnapshotAdmission.isReviewedSoraChain(
                reviewedGenesis
            )
        )
        XCTAssertFalse(
            ReviewedSoraRuntimeSnapshotAdmission.isReviewedSoraChain(
                "not-a-chain-hash"
            )
        )
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let commonTypes = try Data(
            contentsOf: sourceRoot.appendingPathComponent(
                "SoraPassport/Resources/runtime-default.json"
            )
        )
        let chainTypes = try Data(
            contentsOf: sourceRoot.appendingPathComponent(
                "SoraPassport/Resources/runtime-sora.json"
            )
        )
        XCTAssertEqual(
            commonTypes.count,
            ReviewedSoraRuntimeSnapshotAdmission.reviewedCommonTypesBytes
        )
        XCTAssertEqual(
            chainTypes.count,
            ReviewedSoraRuntimeSnapshotAdmission.reviewedChainTypesBytes
        )
        XCTAssertEqual(
            ReviewedSoraRuntimeSnapshotAdmission
                .typeRegistrySHA256(commonTypes),
            ReviewedSoraRuntimeSnapshotAdmission
                .reviewedCommonTypesSHA256
        )
        XCTAssertEqual(
            ReviewedSoraRuntimeSnapshotAdmission
                .typeRegistrySHA256(chainTypes),
            ReviewedSoraRuntimeSnapshotAdmission
                .reviewedChainTypesSHA256
        )
        XCTAssertNoThrow(
            try ReviewedSoraRuntimeSnapshotAdmission.validateCommonTypes(
                chainId: reviewedGenesis,
                data: commonTypes
            )
        )
        XCTAssertNoThrow(
            try ReviewedSoraRuntimeSnapshotAdmission.validateChainTypes(
                chainId: reviewedGenesis,
                data: chainTypes
            )
        )
        XCTAssertNoThrow(
            try ReviewedSoraRuntimeSnapshotAdmission
                .validateTypeRegistryUsage(
                    chainId: reviewedGenesis,
                    typesUsage: .onlyOwn
                )
        )
        XCTAssertThrowsError(
            try ReviewedSoraRuntimeSnapshotAdmission
                .validateTypeRegistryUsage(
                    chainId: reviewedGenesis,
                    typesUsage: .both
                )
        )
        var tamperedChainTypes = chainTypes
        tamperedChainTypes[0] ^= 0x01
        XCTAssertThrowsError(
            try ReviewedSoraRuntimeSnapshotAdmission.validateChainTypes(
                chainId: reviewedGenesis,
                data: tamperedChainTypes
            )
        )
        XCTAssertThrowsError(
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: reviewedGenesis,
                item: RuntimeMetadataItem(
                    chain: reviewedGenesis,
                    version: PolkamarktRuntimeContract.specVersion,
                    txVersion:
                        PolkamarktRuntimeContract.transactionVersion,
                    metadata: sampleMetadata,
                    resolver: nil
                )
            )
        )
        XCTAssertThrowsError(
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: reviewedGenesis,
                item: RuntimeMetadataItem(
                    chain: String(repeating: "12", count: 32),
                    version: PolkamarktRuntimeContract.specVersion,
                    txVersion:
                        PolkamarktRuntimeContract.transactionVersion,
                    metadata: sampleMetadata,
                    resolver: nil
                )
            )
        )
        XCTAssertTrue(
            PolkamarktRuntimeContract.matchesReviewedSigningIdentity(
                specVersion: 130,
                transactionVersion: 130,
                metadataSHA256: reviewedHash
            )
        )
        XCTAssertFalse(
            PolkamarktRuntimeContract.matchesReviewedSigningIdentity(
                specVersion: 131,
                transactionVersion: 130,
                metadataSHA256: reviewedHash
            )
        )
        XCTAssertFalse(
            PolkamarktRuntimeContract.matchesReviewedSigningIdentity(
                specVersion: 130,
                transactionVersion: 129,
                metadataSHA256: reviewedHash
            )
        )
        XCTAssertFalse(
            PolkamarktRuntimeContract.matchesReviewedSigningIdentity(
                specVersion: 130,
                transactionVersion: 130,
                metadataSHA256: String(repeating: "0", count: 64)
            )
        )
    }

    /// Runs the production legacy-upgrade orchestration through the real
    /// asynchronous AccountImportInteractor, in-memory Core Data repository,
    /// account-commit journal, and copy-on-write wallet-network store. All
    /// process-global persistence and recovery dependencies are replaced by
    /// isolated instances rooted in this test's temporary directory.
    private func exerciseFullLegacyWalletUpgrade(
        wordCount: Int,
        entropyBytes: Int,
        corruptCommitJournal: Bool
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let entropy = Data(
            (0 ..< entropyBytes).map {
                UInt8(($0 + wordCount) & 0xff)
            }
        )
        let mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: entropy)
        XCTAssertEqual(mnemonic.allWords().count, wordCount)
        var expectedSeed = try SeedFactory()
            .deriveSeed(from: mnemonic.toString(), password: "")
            .seed
            .miniSeed
        defer {
            expectedSeed.resetBytes(
                in: expectedSeed.startIndex ..< expectedSeed.endIndex
            )
        }
        let expectedKeypair = try SR25519KeypairFactory()
            .createKeypairFromSeed(expectedSeed, chaincodeList: [])
        let expectedPublicKey = expectedKeypair.publicKey().rawData()
        let expectedAddress = try SS58AddressFactory().address(
            fromAccountId: expectedPublicKey,
            type: Chain.sora.addressType()
        )
        var expectedSecret = expectedKeypair.privateKey().rawData()
        let expectedSecretDigest = Data(SHA256.hash(data: expectedSecret))
        expectedSecret.resetBytes(
            in: expectedSecret.startIndex ..< expectedSecret.endIndex
        )

        let displayName = "Retained \(wordCount)-word wallet"
        let keychain = InMemoryKeychain()
        try keychain.addKey(
            entropy,
            with: KeystoreTag.legacyEntropy.rawValue
        )
        try keychain.addKey(
            Data(displayName.utf8),
            with: KeystoreTag.legacyUsername.rawValue
        )
        let originalIdentifiers = Set(try keychain.allKeyIdentifiers())
        var originalValues: [String: Data] = [:]
        for identifier in originalIdentifiers {
            originalValues[identifier] = try keychain.fetchKey(
                for: identifier
            )
        }

        let legacySettings = InMemorySettingsManager()
        let journalProbe = LegacyUpgradeJournalProbe()
        let recoveryGate = WalletRecoveryCapabilityGate(
            settings: legacySettings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: {
                try journalProbe.hasUnresolvedCommit()
            }
        )
        let lifecycleCoordinator = WalletLifecycleCoordinator(
            recoveryGate: recoveryGate
        )
        let journalStore = try WalletAccountCommitJournalStore(
            baseURL: directory,
            recoveryGate: recoveryGate
        )
        journalProbe.install(journalStore)
        let walletStore = try WalletNetworkStore(
            baseURL: directory,
            recoveryGate: recoveryGate
        )

        let storageFacade = UserDataStorageTestFacade()
        let selectedWalletQueue = OperationQueue()
        selectedWalletQueue.name =
            "wallet-modernization-retained-\(wordCount)-selection"
        let accountRepository:
            CoreDataRepository<AccountItem, CDAccountItem> =
            storageFacade.createRepository(
                mapper: AnyCoreDataMapper(AccountItemMapper())
            )
        let selectedWalletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: selectedWalletQueue,
            legacySettings: legacySettings,
            walletNetworkSynchronizer: {
                accounts,
                selectedAddress,
                lifecycleLease in
                if corruptCommitJournal {
                    let journalDirectory = directory
                        .appendingPathComponent(
                            "SORA",
                            isDirectory: true
                        )
                        .appendingPathComponent(
                            "WalletAccountCommits",
                            isDirectory: true
                        )
                    try Data("interrupted legacy upgrade".utf8).write(
                        to: journalDirectory.appendingPathComponent(
                            ".interrupted-upgrade"
                        ),
                        options: .atomic
                    )
                    throw WalletNetworkMigrationError
                        .snapshotVerificationFailed
                }
                try WalletNetworkModelMigrator(
                    keystore: keychain,
                    store: walletStore,
                    settings: legacySettings,
                    lifecycleCoordinator: lifecycleCoordinator,
                    recoveryGate: recoveryGate
                ).migrate(
                    accounts: accounts,
                    selectedAddress: selectedAddress,
                    lifecycleLease: lifecycleLease
                )
            },
            walletAccountCommitJournalStoreFactory: {
                journalStore
            },
            lifecycleCoordinator: lifecycleCoordinator,
            recoveryGate: recoveryGate
        )
        let eventCenter = EventCenter(
            syncQueue: DispatchQueue(
                label: "wallet-modernization-retained-\(wordCount)-events"
            )
        )
        let importQueue = OperationQueue()
        importQueue.name =
            "wallet-modernization-retained-\(wordCount)-import"
        let operationManager = OperationManager(
            operationQueue: importQueue
        )
        let importFactoryCalled = LockedInvocationFlag()

        let root = RootInteractor(
            settings: legacySettings,
            keystore: keychain,
            migrators: [],
            securityLayerInteractor:
                LegacyUpgradeSecurityLayerInteractorStub(),
            networkAvailabilityLayerInteractor: nil,
            legacyUpgradeSelectedAccount: {
                selectedWalletSettings.currentAccount
            },
            legacyUpgradeSnapshotLoader: {
                try walletStore.load()
            },
            legacyUpgradeUnresolvedCommitLoader: {
                try journalStore.unresolved()
            },
            legacyUpgradeInteractorFactory: {
                retainedKeystore,
                retainedSettings,
                expectedEntropyDigest,
                expectedDisplayName in
                importFactoryCalled.markCalled()
                return AccountImportInteractor(
                    accountOperationFactory: AccountOperationFactory(
                        keystore: retainedKeystore,
                        recoveryGate: recoveryGate
                    ),
                    accountRepository: AnyDataProviderRepository(
                        accountRepository
                    ),
                    operationManager: operationManager,
                    settings: selectedWalletSettings,
                    keystoreImportService: KeystoreImportService(
                        logger: Logger.shared
                    ),
                    eventCenter: eventCenter,
                    allowedMnemonicWordCounts:
                        WalletMnemonicWordPolicy.retainedSoraWordCounts,
                    preparedAccountPersistence: { prepared in
                        try LegacyWalletUpgradeSecretRetention
                            .consumeWithoutPersisting(
                                prepared,
                                keystore: retainedKeystore,
                                settings: retainedSettings,
                                expectedEntropyDigest:
                                    expectedEntropyDigest,
                                expectedDisplayName:
                                    expectedDisplayName,
                                recoveryGate: recoveryGate
                            )
                    },
                    lifecycleCoordinator: lifecycleCoordinator
                )
            }
        )
        let presenter = LegacyUpgradeRootPresenterSpy()
        let terminalDecision = expectation(
            description:
                "retained \(wordCount)-word async upgrade terminal decision"
        )
        presenter.onDecision = { decision in
            if decision == .pincodeSetup || decision == .broken {
                terminalDecision.fulfill()
            }
        }
        root.presenter = presenter

        root.decideModuleSynchroniously()
        XCTAssertEqual(presenter.decisions, [.legacyWalletUpgrade])
        root.performLegacyWalletUpgrade()
        wait(for: [terminalDecision], timeout: 5)
        XCTAssertTrue(importFactoryCalled.value)

        let storedAccounts = try fetchAll(
            from: AnyDataProviderRepository(accountRepository),
            operationQueue: selectedWalletQueue,
            expectationHandler: self
        )
        if corruptCommitJournal {
            XCTAssertEqual(
                presenter.decisions,
                [.legacyWalletUpgrade, .broken]
            )
            XCTAssertTrue(legacySettings.walletMigrationRecoveryRequired)
            XCTAssertNil(selectedWalletSettings.currentAccount)
            XCTAssertEqual(storedAccounts.count, 1)
            XCTAssertEqual(storedAccounts.first?.address, expectedAddress)
            XCTAssertEqual(
                storedAccounts.first?.publicKeyData,
                expectedPublicKey
            )
            XCTAssertNil(try walletStore.load())
            XCTAssertThrowsError(try journalStore.unresolved())
            let journalDirectory = directory
                .appendingPathComponent("SORA", isDirectory: true)
                .appendingPathComponent(
                    "WalletAccountCommits",
                    isDirectory: true
                )
            let canonicalJournal = try XCTUnwrap(
                FileManager.default.contentsOfDirectory(
                    at: journalDirectory,
                    includingPropertiesForKeys: nil,
                    options: []
                ).first(where: {
                    $0.lastPathComponent.hasPrefix("wallet-account-")
                })
            )
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            XCTAssertEqual(
                try decoder.decode(
                    WalletAccountCommitJournal.self,
                    from: Data(contentsOf: canonicalJournal)
                ).stage,
                .coreDataCommitted
            )
        } else {
            XCTAssertEqual(
                presenter.decisions,
                [.legacyWalletUpgrade, .pincodeSetup]
            )
            XCTAssertFalse(legacySettings.walletMigrationRecoveryRequired)
            XCTAssertEqual(storedAccounts.count, 1)
            let storedAccount = try XCTUnwrap(storedAccounts.first)
            XCTAssertEqual(storedAccount.address, expectedAddress)
            XCTAssertEqual(storedAccount.publicKeyData, expectedPublicKey)
            XCTAssertEqual(storedAccount.username, displayName)
            XCTAssertTrue(storedAccount.isSelected)
            XCTAssertEqual(
                selectedWalletSettings.currentAccount,
                storedAccount
            )

            let snapshot = try XCTUnwrap(walletStore.load())
            let expectedSource = try XCTUnwrap(
                WalletMnemonicWordPolicy.retainedSecretSource(
                    forWordCount: wordCount
                )
            )
            let expectedNetworks: Set<NetworkId> =
                expectedSource == .legacyMnemonicEntropy
                    ? [.sora2]
                    : Set(NetworkId.allCases)
            XCTAssertEqual(snapshot.selectedWalletId, expectedAddress)
            XCTAssertEqual(snapshot.wallets.count, 1)
            XCTAssertEqual(snapshot.wallets.first?.id, expectedAddress)
            XCTAssertEqual(
                snapshot.wallets.first?.existingSoraAddress,
                expectedAddress
            )
            XCTAssertEqual(
                snapshot.wallets.first?.secretSource,
                expectedSource
            )
            XCTAssertEqual(
                Set(snapshot.accounts.map(\.networkId)),
                expectedNetworks
            )
            let storedSora2 = try XCTUnwrap(
                snapshot.accounts.first(where: {
                    $0.networkId == .sora2
                })
            )
            XCTAssertEqual(storedSora2.address, expectedAddress)
            XCTAssertEqual(storedSora2.publicKey, expectedPublicKey)
            XCTAssertTrue(try journalStore.unresolved().isEmpty)

            let journalDirectory = directory
                .appendingPathComponent("SORA", isDirectory: true)
                .appendingPathComponent(
                    "WalletAccountCommits",
                    isDirectory: true
                )
            let journalURLs = try FileManager.default.contentsOfDirectory(
                at: journalDirectory,
                includingPropertiesForKeys: nil,
                options: []
            )
            XCTAssertEqual(journalURLs.count, 1)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let terminalJournal = try decoder.decode(
                WalletAccountCommitJournal.self,
                from: Data(contentsOf: try XCTUnwrap(journalURLs.first))
            )
            XCTAssertEqual(terminalJournal.walletId, expectedAddress)
            XCTAssertEqual(terminalJournal.stage, .activated)

            XCTAssertTrue(
                try WalletExplicitRemovalIdentityPolicy.verify(
                    accounts: storedAccounts,
                    expectedAccount: storedAccount,
                    walletId: expectedAddress,
                    snapshot: snapshot,
                    keystore: keychain,
                    settings: legacySettings,
                    recoveryGate: recoveryGate
                )
            )

            var postUpgradeEntropy = try keychain.fetchKey(
                for: KeystoreTag.legacyEntropy.rawValue
            )
            defer {
                postUpgradeEntropy.resetBytes(
                    in: postUpgradeEntropy.startIndex ..<
                        postUpgradeEntropy.endIndex
                )
            }
            let postUpgradeMnemonic = try IRMnemonicCreator(
                language: .english
            ).mnemonic(fromEntropy: postUpgradeEntropy)
            var postUpgradeSeed = try SeedFactory()
                .deriveSeed(
                    from: postUpgradeMnemonic.toString(),
                    password: ""
                )
                .seed
                .miniSeed
            defer {
                postUpgradeSeed.resetBytes(
                    in: postUpgradeSeed.startIndex ..<
                        postUpgradeSeed.endIndex
                )
            }
            let postUpgradeKeypair = try SR25519KeypairFactory()
                .createKeypairFromSeed(
                    postUpgradeSeed,
                    chaincodeList: []
                )
            var postUpgradeSecret = postUpgradeKeypair.privateKey()
                .rawData()
            XCTAssertEqual(
                Data(SHA256.hash(data: postUpgradeSecret)),
                expectedSecretDigest
            )
            postUpgradeSecret.resetBytes(
                in: postUpgradeSecret.startIndex ..<
                    postUpgradeSecret.endIndex
            )
        }

        XCTAssertEqual(
            Set(try keychain.allKeyIdentifiers()),
            originalIdentifiers
        )
        for (identifier, expectedValue) in originalValues {
            XCTAssertEqual(
                try keychain.fetchKey(for: identifier),
                expectedValue
            )
        }
        for scopedTag in [
            KeystoreTag.secretKeyTagForAddress(expectedAddress),
            KeystoreTag.entropyTagForAddress(expectedAddress),
            KeystoreTag.deriviationTagForAddress(expectedAddress),
            KeystoreTag.seedTagForAddress(expectedAddress),
        ] {
            XCTAssertFalse(try keychain.checkKey(for: scopedTag))
        }
    }

    private func makeLegacyAccount(address label: String) -> AccountItem {
        let marker = label.utf8.reduce(0) {
            ($0 + Int($1)) & 0xff
        }
        let publicKey = Data(
            (0..<32).map { UInt8((marker + $0) & 0xff) }
        )
        let address = try! SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: Chain.sora.addressType()
        )
        return AccountItem(
            address: address,
            cryptoType: .sr25519,
            networkType: Chain.sora.addressType(),
            username: "Existing wallet",
            publicKeyData: publicKey,
            settings: AccountSettings(
                visibleAssetIds: [],
                orderedAssetIds: []
            ),
            order: 0,
            isSelected: true
        )
    }

    private func userStorageModel(named name: String) throws -> NSManagedObjectModel {
        let modelURL =
            Bundle.main.url(
                forResource: name,
                withExtension: "omo",
                subdirectory: UserStorageParams.modelDirectory
            ) ??
            Bundle.main.url(
                forResource: name,
                withExtension: "mom",
                subdirectory: UserStorageParams.modelDirectory
            )
        let unwrappedURL = try XCTUnwrap(modelURL)
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: unwrappedURL))
    }

    private func writeAccount(
        _ account: AccountItem,
        to storeURL: URL,
        model: NSManagedObjectModel,
        includesSelection: Bool
    ) throws {
        try writeAccounts(
            [account],
            to: storeURL,
            model: model,
            includesSelection: includesSelection
        )
    }

    private func writeAccounts(
        _ accounts: [AccountItem],
        to storeURL: URL,
        model: NSManagedObjectModel,
        includesSelection: Bool
    ) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for account in accounts {
                let stored = NSEntityDescription.insertNewObject(
                    forEntityName: "CDAccountItem",
                    into: context
                )
                stored.setValue(account.address, forKey: "identifier")
                stored.setValue(account.username, forKey: "username")
                stored.setValue(account.publicKeyData, forKey: "publicKey")
                stored.setValue(
                    account.cryptoType.rawValue,
                    forKey: "cryptoType"
                )
                stored.setValue(
                    account.networkType,
                    forKey: "networkType"
                )
                stored.setValue(account.order, forKey: "order")
                if includesSelection {
                    stored.setValue(
                        account.isSelected,
                        forKey: "isSelected"
                    )
                }
            }
            try context.save()
        }
        try coordinator.remove(store)
    }

    private func assertStoredAccount(
        _ account: AccountItem,
        at storeURL: URL,
        model: NSManagedObjectModel,
        expectedSelection: Bool?
    ) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDAccountItem")
            let rows = try context.fetch(request)
            let row = try XCTUnwrap(rows.first)
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(row.value(forKey: "identifier") as? String, account.address)
            XCTAssertEqual(row.value(forKey: "username") as? String, account.username)
            XCTAssertEqual(row.value(forKey: "publicKey") as? Data, account.publicKeyData)
            if let expectedSelection {
                XCTAssertEqual(
                    (row.value(forKey: "isSelected") as? NSNumber)?.boolValue,
                    expectedSelection
                )
            }
        }
    }

    private func assertStoredAccounts(
        _ accounts: [AccountItem],
        at storeURL: URL,
        model: NSManagedObjectModel,
        includesSelection: Bool = true
    ) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            let rows = try context.fetch(
                NSFetchRequest<NSManagedObject>(entityName: "CDAccountItem")
            )
            XCTAssertEqual(rows.count, accounts.count)
            let rowsByAddress = Dictionary(
                uniqueKeysWithValues: rows.compactMap { row in
                    (row.value(forKey: "identifier") as? String).map {
                        ($0, row)
                    }
                }
            )
            XCTAssertEqual(rowsByAddress.count, accounts.count)
            for account in accounts {
                let row = try XCTUnwrap(rowsByAddress[account.address])
                XCTAssertEqual(
                    row.value(forKey: "username") as? String,
                    account.username
                )
                XCTAssertEqual(
                    row.value(forKey: "publicKey") as? Data,
                    account.publicKeyData
                )
                XCTAssertEqual(
                    (row.value(forKey: "order") as? NSNumber)?.intValue,
                    Int(account.order)
                )
                if includesSelection {
                    XCTAssertEqual(
                        (row.value(forKey: "isSelected") as? NSNumber)?.boolValue,
                        account.isSelected
                    )
                }
            }
        }
    }
}

private final class AccountSelectionDeliveryObserver: EventVisitorProtocol {
    private let onSelection: () -> Void

    init(onSelection: @escaping () -> Void) {
        self.onSelection = onSelection
    }

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        onSelection()
    }
}

private final class LegacyUpgradeSecurityLayerInteractorStub:
    SecurityLayerInteractorInputProtocol
{
    func setup() {}
}

private final class LegacyUpgradeJournalProbe: @unchecked Sendable {
    private let lock = NSLock()
    private weak var store: WalletAccountCommitJournalStore?

    func install(_ store: WalletAccountCommitJournalStore) {
        lock.lock()
        self.store = store
        lock.unlock()
    }

    func hasUnresolvedCommit() throws -> Bool {
        lock.lock()
        let retainedStore = store
        lock.unlock()
        guard let retainedStore else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        return try !retainedStore.unresolved().isEmpty
    }
}

private final class LegacyUpgradeRootPresenterSpy:
    RootInteractorOutputProtocol
{
    enum Decision: Equatable {
        case onboarding
        case legacyWalletUpgrade
        case localAuthentication
        case broken
        case pincodeSetup
    }

    private let lock = NSLock()
    private var storedDecisions: [Decision] = []
    var onDecision: ((Decision) -> Void)?

    var decisions: [Decision] {
        lock.lock()
        defer { lock.unlock() }
        return storedDecisions
    }

    func didDecideOnboarding() {
        record(.onboarding)
    }

    func didDecideLegacyWalletUpgrade() {
        record(.legacyWalletUpgrade)
    }

    func didDecideLocalAuthentication() {
        record(.localAuthentication)
    }

    func didDecideBroken() {
        record(.broken)
    }

    func didDecidePincodeSetup() {
        record(.pincodeSetup)
    }

    private func record(_ decision: Decision) {
        lock.lock()
        storedDecisions.append(decision)
        let callback = onDecision
        lock.unlock()
        callback?(decision)
    }
}

private final class WalletJournalRemovalFailingFileManager: FileManager {
    var failWalletJournalRemoval = false

    override func removeItem(at URL: URL) throws {
        if
            failWalletJournalRemoval,
            URL.lastPathComponent.hasPrefix("wallet-account-")
        {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteNoPermissionError
            )
        }
        try super.removeItem(at: URL)
    }
}

private final class WalletTestCancellableCall: CancellableCall {
    private(set) var cancelCount = 0

    func cancel() {
        cancelCount += 1
    }
}

private struct IndexedRuntimeFunction: RuntimeFunctionMetadata {
    let name: String
    let index: UInt8?
    let arguments: [RuntimeFunctionArgumentMetadata] = []
    let documentation: [String] = []
}

private extension Data {
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
