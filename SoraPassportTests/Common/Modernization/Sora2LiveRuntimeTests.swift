// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import SoraPassport

/// SORA2 signing is validated against the live chain runtime instead of a
/// pinned runtime 130. These tests use real mainnet metadata for runtime 133
/// (transaction version 131), captured from wss://ws.mof.sora.org on
/// 2026-10-10: `Fixtures/Modernization/sora2-metadata-spec133.scale`.
final class Sora2LiveRuntimeTests: XCTestCase {
    private static let fixtureRawSHA256 =
        "e7b2459c35f0c0d1273216bb965a36168e1ca3bd94592608b40c1eaa3b682e17"
    private static let fixtureHexLineSHA256 =
        "ab22a2d4e7d9b95197966ce7c59385bb2b569f5709eebcb9aad104f014b9c732"
    private static let xorAssetId =
        "0x0200000000000000000000000000000000000000000000000000000000000000"

    private var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func fixtureMetadata() throws -> Data {
        try Data(
            contentsOf: sourceRoot.appendingPathComponent(
                "Fixtures/Modernization/sora2-metadata-spec133.scale"
            )
        )
    }

    private func chainTypes() throws -> Data {
        try Data(
            contentsOf: sourceRoot.appendingPathComponent(
                "SoraPassport/Resources/runtime-sora.json"
            )
        )
    }

    private func item(
        spec: UInt32 = 133,
        tx: UInt32 = 131,
        metadata: Data? = nil,
        chain: String = PIIndexerClient.soraMainnetGenesis
    ) throws -> SoraPassport.RuntimeMetadataItem {
        SoraPassport.RuntimeMetadataItem(
            chain: chain,
            version: spec,
            txVersion: tx,
            metadata: try metadata ?? fixtureMetadata(),
            resolver: nil
        )
    }

    private func factory(
        spec: UInt32 = 133,
        tx: UInt32 = 131
    ) throws -> RuntimeCoderFactory {
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(
            chainId: PIIndexerClient.soraMainnetGenesis,
            runtimeMetadataItem: try item(),
            ownTypes: try chainTypes(),
            dataHasher: .twox256
        )
        return RuntimeCoderFactory(
            catalog: snapshot.typeRegistryCatalog,
            specVersion: spec,
            txVersion: tx,
            metadata: snapshot.metadata
        )
    }

    private func runtimeVersion(
        spec: UInt32,
        tx: UInt32
    ) throws -> RuntimeVersion {
        try JSONDecoder().decode(
            RuntimeVersion.self,
            from: Data(
                #"{"specVersion":\#(spec),"transactionVersion":\#(tx)}"#.utf8
            )
        )
    }

    private func live(
        spec: UInt32 = 133,
        tx: UInt32 = 131,
        sha: String = Sora2LiveRuntimeTests.fixtureHexLineSHA256
    ) -> Sora2LiveRuntime {
        Sora2LiveRuntime(
            specVersion: spec,
            transactionVersion: tx,
            metadataSHA256: sha
        )
    }

    func testFixtureIsTheLiveMainnetRuntime133Metadata() throws {
        let metadata = try fixtureMetadata()
        XCTAssertEqual(
            ReviewedSoraRuntimeSnapshotAdmission.typeRegistrySHA256(metadata),
            Self.fixtureRawSHA256
        )
        XCTAssertEqual(
            PolkamarktRuntimeContract.rawMetadataSHA256(metadata),
            Self.fixtureHexLineSHA256
        )
        XCTAssertEqual(
            PolkamarktRuntimeContract.wireMetadataSHA256(
                metadata.toHex(includePrefix: true)
            ),
            Self.fixtureHexLineSHA256
        )
    }

    func testMetadataDeclaresItsRuntimeVersion() throws {
        let decoded = try RuntimeMetadata(
            scaleDecoder: try ScaleDecoder(data: try fixtureMetadata())
        )
        XCTAssertEqual(
            try Sora2RuntimeIdentity.declared(by: decoded),
            Sora2RuntimeIdentity(
                specName: "sora-substrate",
                specVersion: 133,
                transactionVersion: 131
            )
        )
    }

    func testAdmissionAcceptsNewerLiveRuntimeAndRejectsMismatches() throws {
        let chain = PIIndexerClient.soraMainnetGenesis
        XCTAssertNoThrow(
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: chain,
                item: try item()
            )
        )
        // The bytes must declare exactly the versions they are stored under.
        for (spec, tx) in [(132, 131), (134, 131), (133, 130), (133, 132)] {
            XCTAssertThrowsError(
                try ReviewedSoraRuntimeSnapshotAdmission.validate(
                    chainId: chain,
                    item: try item(spec: UInt32(spec), tx: UInt32(tx))
                ),
                "\(spec)/\(tx)"
            )
        }
        // Below the reviewed floor, garbage bytes, empty bytes, other chain.
        XCTAssertThrowsError(
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: chain,
                item: try item(spec: 129, tx: 129)
            )
        )
        XCTAssertThrowsError(
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: chain,
                item: try item(metadata: Data([0x00, 0x01, 0xff]))
            )
        )
        XCTAssertThrowsError(
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: chain,
                item: try item(metadata: Data())
            )
        )
        var truncated = try fixtureMetadata()
        truncated.removeLast(1_024)
        XCTAssertThrowsError(
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: chain,
                item: try item(metadata: truncated)
            )
        )
        XCTAssertThrowsError(
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: chain,
                item: try item(chain: String(repeating: "12", count: 32))
            )
        )
    }

    func testSnapshotBuildsWithBundledTypesAndRoundTripsMetadata() throws {
        let factory = try factory()
        XCTAssertNotNil(
            try factory.metadata.getCallIndex(
                in: "Assets",
                callName: "transfer"
            )
        )
        // The signing identity re-encodes the decoded metadata. It must be
        // byte-identical to what the node serves, or live validation would
        // reject every runtime.
        XCTAssertEqual(
            try PolkamarktRuntimeContract.signingMetadataSHA256(for: factory),
            Self.fixtureHexLineSHA256
        )
    }

    func testLiveValidatorAcceptsTheExactLiveRuntime() throws {
        XCTAssertNoThrow(
            try Sora2LiveRuntimeValidator.validate(
                factory: try factory(),
                live: live()
            )
        )
    }

    func testLiveValidatorRejectsStaleOrForeignRuntimeBeforeSigning() throws {
        // Local metadata is behind a runtime upgrade.
        assertError(
            try Sora2LiveRuntimeValidator.validate(
                factory: try factory(),
                live: live(spec: 134, tx: 131)
            ),
            isUpgrade: true
        )
        assertError(
            try Sora2LiveRuntimeValidator.validate(
                factory: try factory(spec: 132, tx: 131),
                live: live()
            ),
            isUpgrade: true
        )
        // Same versions, different metadata bytes on the node.
        assertError(
            try Sora2LiveRuntimeValidator.validate(
                factory: try factory(),
                live: live(sha: String(repeating: "0", count: 64))
            ),
            isUpgrade: false
        )
        // A factory whose metadata declares another runtime than it claims.
        assertError(
            try Sora2LiveRuntimeValidator.validate(
                factory: try factory(spec: 134, tx: 131),
                live: live(spec: 134, tx: 131)
            ),
            isUpgrade: false
        )
        // A live runtime below the reviewed floor is never accepted.
        XCTAssertThrowsError(
            try Sora2LiveRuntimeValidator.validate(
                factory: try factory(),
                live: live(spec: 129, tx: 129)
            )
        ) { error in
            guard case ExtrinsicServiceError.unsupportedRuntime = error else {
                return XCTFail("\(error)")
            }
        }
    }

    func testLiveRuntimeBindsMetadataDownloadToReportedVersion() throws {
        let hex = try fixtureMetadata().toHex(includePrefix: true)
        let accepted = try Sora2LiveRuntimeValidator.liveRuntime(
            version: try runtimeVersion(spec: 133, tx: 131),
            metadataHex: hex
        )
        XCTAssertEqual(accepted, live())
        // The node upgraded between the version read and the metadata read.
        assertError(
            try Sora2LiveRuntimeValidator.liveRuntime(
                version: try runtimeVersion(spec: 132, tx: 131),
                metadataHex: hex
            ),
            isUpgrade: true
        )
        XCTAssertThrowsError(
            try Sora2LiveRuntimeValidator.liveRuntime(
                version: try runtimeVersion(spec: 133, tx: 131),
                metadataHex: hex.uppercased()
            )
        )
    }

    func testLiveRuntimeCacheIsKeyedByRuntimeVersion() {
        let cache = Sora2LiveRuntimeIdentityCache()
        cache.store(
            metadataSHA256: Self.fixtureHexLineSHA256,
            specVersion: 133,
            transactionVersion: 131
        )
        XCTAssertEqual(
            cache.metadataSHA256(specVersion: 133, transactionVersion: 131),
            Self.fixtureHexLineSHA256
        )
        XCTAssertNil(
            cache.metadataSHA256(specVersion: 134, transactionVersion: 131)
        )
        XCTAssertNil(
            cache.metadataSHA256(specVersion: 133, transactionVersion: 132)
        )
    }

    func testRecoveryContextAcceptsAnyRuntimeFromTheReviewedFloor() throws {
        for (spec, tx, valid) in [
            (UInt32(130), UInt32(130), true),
            (133, 131, true),
            (140, 135, true),
            (129, 129, false),
            (133, 0, false)
        ] {
            let attempt = Result {
                try Sora2SubmissionRecoveryContext.make(
                    walletId: "cnTestWallet",
                    accountId: Data(repeating: 0x11, count: 32),
                    publicKey: Data(repeating: 0x11, count: 32),
                    transactionHash: "0x" + String(repeating: "ab", count: 32),
                    genesisHash: PIIndexerClient.soraMainnetGenesis,
                    specVersion: spec,
                    transactionVersion: tx,
                    metadataSHA256: Self.fixtureHexLineSHA256,
                    era: .mortal(period: 64, phase: 1_000 % 64),
                    eraBirthBlock: 1_000,
                    eraBirthBlockHash: "0x" + String(repeating: "cd", count: 32)
                )
            }
            switch attempt {
            case .success:
                XCTAssertTrue(valid, "\(spec)/\(tx)")
            case .failure:
                XCTAssertFalse(valid, "\(spec)/\(tx)")
            }
        }
        XCTAssertThrowsError(
            try Sora2SubmissionRecoveryContext.make(
                walletId: "cnTestWallet",
                accountId: Data(repeating: 0x11, count: 32),
                publicKey: Data(repeating: 0x11, count: 32),
                transactionHash: "0x" + String(repeating: "ab", count: 32),
                genesisHash: PIIndexerClient.soraMainnetGenesis,
                specVersion: 133,
                transactionVersion: 131,
                metadataSHA256: Self.fixtureHexLineSHA256.uppercased(),
                era: .mortal(period: 64, phase: 1_000 % 64),
                eraBirthBlock: 1_000,
                eraBirthBlockHash: "0x" + String(repeating: "cd", count: 32)
            )
        )
    }

    /// Encodes an XOR transfer with runtime 133 through the app's own
    /// assembly code and checks the call bytes against the metadata.
    func testTransferEncodesWithRuntime133() throws {
        let factory = try factory()
        let accountId = Data(repeating: 0x42, count: 32)
        var signedPayloads: [Data] = []
        let (data, _) = try ExtrinsicService.assembleSignedExtrinsic(
            codingFactory: factory,
            genesisHash: PIIndexerClient.soraMainnetGenesis,
            accountId: accountId,
            nonce: 7,
            era: .mortal(period: 64, phase: 5),
            eraBlockHash: "0x" + String(repeating: "ee", count: 32),
            cryptoType: .sr25519,
            customClosure: { builder in
                try builder.adding(
                    call: try SubstrateCallFactory().transfer(
                        to: accountId.toHex(includePrefix: true),
                        asset: Self.xorAssetId,
                        amount: BigUInt(1)
                    )
                )
            },
            signingClosure: { payload in
                signedPayloads.append(payload)
                return Data(repeating: 0x01, count: 64)
            }
        )
        XCTAssertEqual(signedPayloads.count, 1)
        let palletIndex = try XCTUnwrap(
            factory.metadata.getModuleIndex("Assets")
        )
        let callIndex = try XCTUnwrap(
            try factory.metadata.getCallIndex(
                in: "Assets",
                callName: "transfer"
            )
        )
        let callPrefix = Data([palletIndex, callIndex])
        XCTAssertNotNil(data.range(of: callPrefix))
        // The signed payload carries spec 133 and transaction version 131
        // (little-endian u32) right after the call and the extensions.
        let versions = Data([0x85, 0x00, 0x00, 0x00, 0x83, 0x00, 0x00, 0x00])
        XCTAssertNotNil(signedPayloads.first?.range(of: versions))
    }

    // MARK: - Balances layout (runtime 132 and later)

    /// SCALE bytes of a runtime 133 `System.Account` value: nonce, consumers,
    /// providers, sufficients (u32 each), then `free, reserved, frozen,
    /// flags` (u128 each, little endian).
    private func systemAccountBytes(
        nonce: UInt32,
        free: BigUInt,
        reserved: BigUInt,
        frozen: BigUInt,
        flags: BigUInt
    ) -> Data {
        var data = Data()
        for value in [nonce, 1, 1, 0] {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        for value in [free, reserved, frozen, flags] {
            var bytes = [UInt8](value.serialize().reversed())
            bytes += [UInt8](repeating: 0, count: 16 - bytes.count)
            data.append(contentsOf: bytes)
        }
        return data
    }

    /// Runtime 132 replaced `misc_frozen, fee_frozen` with `frozen, flags` in
    /// the balances pallet. Decoding `System.Account` into the app's model
    /// failed for every account on runtime 133, so XOR balances read as zero
    /// and the send flow could not read the recipient's account. Both layouts
    /// must decode, and the spendable amount must never exceed what the
    /// chain allows.
    func testSystemAccountDecodesTheRuntime133BalancesLayout() throws {
        let factory = try factory()
        let xor = BigUInt(10).power(18)
        let newLogic = BigUInt(1) << 127
        let values: [Data?] = [
            // Ordinary account: nothing frozen.
            systemAccountBytes(nonce: 7, free: 5 * xor, reserved: 0, frozen: 0, flags: newLogic),
            // Frozen 1.5 XOR, of which 1 XOR is covered by the reserve.
            systemAccountBytes(nonce: 1, free: 2 * xor, reserved: xor, frozen: 3 * xor / 2, flags: newLogic),
            // Frozen above free (seen on mainnet): nothing can be moved.
            systemAccountBytes(nonce: 2, free: xor, reserved: 0, frozen: 100 * xor, flags: newLogic + 100 * xor),
            // No account yet: the storage default.
            nil
        ]

        let operation = StorageFallbackDecodingListOperation<AccountInfo>(
            path: .account,
            dataList: values
        )
        operation.codingFactory = factory
        operation.start()
        let infos = try XCTUnwrap(operation.result).get()
        XCTAssertEqual(infos.count, 4)

        let plain = try XCTUnwrap(infos[0])
        XCTAssertEqual(plain.nonce, 7)
        XCTAssertEqual(plain.data.free, 5 * xor)
        XCTAssertEqual(plain.data.locked, 0)
        XCTAssertEqual(plain.data.available, 5 * xor)

        let partlyReserved = try XCTUnwrap(infos[1]).data
        XCTAssertEqual(partlyReserved.reserved, xor)
        XCTAssertEqual(partlyReserved.locked, xor / 2)
        XCTAssertEqual(partlyReserved.available, 3 * xor / 2)
        XCTAssertEqual(partlyReserved.total, 3 * xor)

        let frozenAboveFree = try XCTUnwrap(infos[2]).data
        XCTAssertEqual(frozenAboveFree.free, xor)
        XCTAssertEqual(frozenAboveFree.locked, xor)
        XCTAssertEqual(frozenAboveFree.available, 0)

        let missing = try XCTUnwrap(infos[3]).data
        XCTAssertEqual(missing.free, 0)
        XCTAssertEqual(missing.available, 0)

        // The subscription model reads the same layout.
        let subscription = StorageFallbackDecodingListOperation<DyAccountInfo>(
            path: .account,
            dataList: [values[1]]
        )
        subscription.codingFactory = factory
        subscription.start()
        let dynamic = try XCTUnwrap(try XCTUnwrap(subscription.result).get().first ?? nil)
        XCTAssertEqual(dynamic.data.free, 2 * xor)
        XCTAssertEqual(dynamic.data.locked, xor / 2)
        XCTAssertEqual(dynamic.data.available, 3 * xor / 2)
    }

    /// The layout of runtime 130 and earlier still decodes as before, and the
    /// model keeps encoding it, so nothing that reads stored values changes.
    func testAccountDataKeepsTheEarlierBalancesLayout() throws {
        let legacy = Data(
            #"{"free":"10","reserved":"2","miscFrozen":"3","feeFrozen":"4"}"#.utf8
        )
        let data = try JSONDecoder().decode(AccountData.self, from: legacy)
        XCTAssertEqual(data.miscFrozen, 3)
        XCTAssertEqual(data.feeFrozen, 4)
        XCTAssertEqual(data.locked, 4)
        XCTAssertEqual(data.available, 6)
        let roundTrip = try JSONDecoder().decode(
            AccountData.self,
            from: JSONEncoder().encode(data)
        )
        XCTAssertEqual(roundTrip, data)
        let dynamic = try JSONDecoder().decode(DyAccountData.self, from: legacy)
        XCTAssertEqual(dynamic.locked, 4)

        // A lock above the free balance in the old layout no longer traps.
        let overLocked = AccountData(free: 1, reserved: 0, miscFrozen: 5, feeFrozen: 0)
        XCTAssertEqual(overLocked.available, 0)
    }

    func testRuntimeUpgradeMessageIsCalmAndTranslated() throws {
        XCTAssertNotNil(
            ExtrinsicServiceError.runtimeUpgradeInProgress(
                spec: 134,
                transaction: 131
            ).errorDescription
        )
        let keys = [
            "The SORA network was just upgraded. The app is updating its network data. Please try again in a few seconds.",
            "The app could not confirm the SORA network version, so nothing was signed. Please try again in a moment."
        ]
        for key in keys {
            XCTAssertEqual(WalletUX.text(key, language: "en"), key)
            XCTAssertNotEqual(WalletUX.text(key, language: "ja"), key)
        }
        XCTAssertNotNil(
            ExtrinsicServiceError.runtimeUserMessage(
                for: ExtrinsicServiceError.unsupportedRuntimeMetadata
            )
        )
        XCTAssertNil(
            ExtrinsicServiceError.runtimeUserMessage(
                for: ExtrinsicServiceError.invalidLocalHash
            )
        )
    }

    func testSigningMessagesSeparateAccountAndNodeProblemsFromUpgrades() {
        let upgrade = ExtrinsicServiceError.runtimeUserMessage(
            for: ExtrinsicServiceError.runtimeUpgradeInProgress(spec: 134, transaction: 131)
        )
        let account = ExtrinsicServiceError.runtimeUserMessage(
            for: ExtrinsicServiceError.signingAccountUnavailable
        )
        let node = ExtrinsicServiceError.runtimeUserMessage(
            for: ExtrinsicServiceError.unexpectedNetwork
        )
        let foreignRuntime = ExtrinsicServiceError.runtimeUserMessage(
            for: ExtrinsicServiceError.unsupportedRuntime(spec: 1, transaction: 1)
        )
        XCTAssertNotNil(account)
        XCTAssertNotNil(node)
        XCTAssertEqual(node, foreignRuntime)
        XCTAssertNotEqual(account, upgrade)
        XCTAssertNotEqual(node, upgrade)
        let nodeKey = "The connected node does not match the SORA network this app uses, so nothing was signed. Choose another node and try again."
        let accountKey = "This account can't sign on this device right now, so nothing was signed. Your funds are not affected. Try again, or restore this account with its recovery phrase to send from it."
        XCTAssertEqual(node, WalletUX.text(nodeKey))
        XCTAssertEqual(account, WalletUX.text(accountKey))
        for key in [nodeKey, accountKey] {
            XCTAssertEqual(WalletUX.text(key, language: "en"), key)
            XCTAssertNotEqual(WalletUX.text(key, language: "ja"), key)
        }
    }

    // MARK: - Live runtime proofs

    func testLiveRuntimeProofsPersistAcrossLaunches() throws {
        let suite = "Sora2LiveRuntimeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = Sora2LiveRuntimeIdentityCache(defaults: defaults)
        first.recordAdmittedMetadata(
            try fixtureMetadata(),
            specVersion: 133,
            transactionVersion: 131
        )
        let relaunched = Sora2LiveRuntimeIdentityCache(defaults: defaults)
        XCTAssertEqual(
            relaunched.metadataSHA256(specVersion: 133, transactionVersion: 131),
            Self.fixtureHexLineSHA256
        )
        // A proof for a runtime below the reviewed floor, or a malformed
        // value, is never stored or loaded.
        relaunched.store(metadataSHA256: Self.fixtureHexLineSHA256, specVersion: 129, transactionVersion: 129)
        relaunched.store(metadataSHA256: "not-a-hash", specVersion: 134, transactionVersion: 131)
        var persisted = defaults.dictionary(forKey: Sora2LiveRuntimeIdentityCache.persistenceKey) ?? [:]
        XCTAssertEqual(Array(persisted.keys), ["133:131"])
        persisted["135:131"] = "XYZ"
        persisted["garbage"] = Self.fixtureHexLineSHA256
        defaults.set(persisted, forKey: Sora2LiveRuntimeIdentityCache.persistenceKey)
        let reloaded = Sora2LiveRuntimeIdentityCache(defaults: defaults)
        XCTAssertNil(reloaded.metadataSHA256(specVersion: 135, transactionVersion: 131))
        XCTAssertEqual(
            reloaded.metadataSHA256(specVersion: 133, transactionVersion: 131),
            Self.fixtureHexLineSHA256
        )
        // In-memory caches never write.
        let memoryOnly = Sora2LiveRuntimeIdentityCache()
        memoryOnly.store(metadataSHA256: Self.fixtureHexLineSHA256, specVersion: 140, transactionVersion: 131)
        XCTAssertNil(Sora2LiveRuntimeIdentityCache(defaults: defaults)
            .metadataSHA256(specVersion: 140, transactionVersion: 131))
    }

    func testConcurrentLiveRuntimeProofsShareOneDownload() throws {
        let cache = Sora2LiveRuntimeIdentityCache()
        let hex = try fixtureMetadata().toHex(includePrefix: true)
        let version = try runtimeVersion(spec: 133, tx: 131)
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var downloads = 0
        let fetch: () throws -> String = {
            lock.lock()
            downloads += 1
            lock.unlock()
            started.signal()
            _ = release.wait(timeout: .now() + 10)
            return hex
        }
        let group = DispatchGroup()
        var results: [Result<Sora2LiveRuntime, Error>] = []
        func prove() {
            group.enter()
            DispatchQueue.global().async {
                let result = Result { try cache.liveRuntime(for: version, fetchMetadataHex: fetch) }
                lock.lock()
                results.append(result)
                lock.unlock()
                group.leave()
            }
        }
        prove()
        XCTAssertEqual(started.wait(timeout: .now() + 5), .success)
        prove()
        prove()
        // Let the later callers reach the shared download before it ends.
        Thread.sleep(forTimeInterval: 0.3)
        release.signal()
        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
        XCTAssertEqual(downloads, 1)
        XCTAssertEqual(results.count, 3)
        for result in results {
            XCTAssertEqual(try result.get(), live())
        }
        // Afterwards the stored proof answers without any download.
        XCTAssertEqual(
            try cache.liveRuntime(for: version) {
                XCTFail("No download expected")
                return ""
            },
            live()
        )
    }

    func testFailedLiveProofIsNotStoredAndIsRetried() throws {
        let cache = Sora2LiveRuntimeIdentityCache()
        let version = try runtimeVersion(spec: 133, tx: 131)
        XCTAssertThrowsError(
            try cache.liveRuntime(for: version) { throw URLError(.notConnectedToInternet) }
        )
        XCTAssertNil(cache.metadataSHA256(specVersion: 133, transactionVersion: 131))
        let hex = try fixtureMetadata().toHex(includePrefix: true)
        XCTAssertEqual(try cache.liveRuntime(for: version) { hex }, live())
    }

    // MARK: - Runtime sync replacement

    /// Signing found that the stored metadata for the live runtime differs
    /// from the node's. The replacement download must never delete the stored
    /// copy before new bytes pass admission, must keep replacing on automatic
    /// retries, and must not restart while it is already running.
    func testMetadataReplacementKeepsStoredCopyRetriesAndIsNotRestarted() throws {
        let genesis = PIIndexerClient.soraMainnetGenesis
        let stored = try item()
        let repository = RuntimeTestRepository(items: [stored])
        let engine = MetadataTestEngine()
        // First answer: bytes that do not declare runtime 133/131.
        engine.respond(with: "0x" + String(repeating: "00", count: 64))
        engine.hold()
        let proofs = Sora2LiveRuntimeIdentityCache()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let service = RuntimeSyncService(
            repository: AnyDataProviderRepository(repository),
            filesOperationFactory: RuntimeFilesOperationFactory(
                repository: FileRepository(),
                directoryPath: directory.path
            ),
            dataOperationFactory: DataOperationFactory(),
            eventCenter: EventCenter(),
            retryStrategy: QuickRetry(),
            liveRuntimeIdentityCache: proofs,
            metadataEngine: { _ in engine }
        )
        let chain = ChainModel(
            chainId: genesis, name: "SORA", nodes: [], addressPrefix: 69,
            icon: nil, selectedNode: nil, customNodes: nil, iosMinAppVersion: nil
        )
        service.register(chain: chain, with: RuntimeTestConnection())
        let version = try runtimeVersion(spec: 133, tx: 131)

        service.applyReplacingCachedMetadata(version: version, for: genesis)
        XCTAssertTrue(engine.waitForCalls(1))
        // Signing keeps asking while the download runs: no restart.
        for _ in 0 ..< 3 {
            service.applyReplacingCachedMetadata(version: version, for: genesis)
        }
        // A restart would cancel the running download and start a new one.
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(engine.callCount, 1)
        XCTAssertTrue(service.isChainSyncing(genesis))
        engine.release()
        // The failed download is retried, and the retry downloads again even
        // though a copy for spec 133 is stored (a plain sync would skip it).
        XCTAssertTrue(engine.waitForCalls(2))
        XCTAssertEqual(repository.items, [stored])
        XCTAssertNil(proofs.metadataSHA256(specVersion: 133, transactionVersion: 131))

        // The node now serves its real metadata: it replaces the stored copy
        // and becomes the proof for this runtime.
        engine.respond(with: try fixtureMetadata().toHex(includePrefix: true))
        let deadline = Date().addingTimeInterval(20)
        while proofs.metadataSHA256(specVersion: 133, transactionVersion: 131) == nil,
              Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertEqual(
            proofs.metadataSHA256(specVersion: 133, transactionVersion: 131),
            Self.fixtureHexLineSHA256
        )
        XCTAssertEqual(repository.items, [stored])
        let settled = Date().addingTimeInterval(5)
        while service.isChainSyncing(genesis), Date() < settled {
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertFalse(service.isChainSyncing(genesis))
        // Once replaced, a plain sync for the same runtime does not download.
        let calls = engine.callCount
        service.apply(version: version, for: genesis)
        let plainDeadline = Date().addingTimeInterval(5)
        while service.isChainSyncing(genesis), Date() < plainDeadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertEqual(engine.callCount, calls)
        service.unregister(chainId: genesis)
    }

    // MARK: - Pending recovery decoding

    private func reconciler(
        runtimeService: SoraPassport.RuntimeCodingServiceProtocol,
        proofs: Sora2LiveRuntimeIdentityCache,
        directory: URL,
        walletNetworkSnapshot: @escaping () throws -> WalletNetworkSnapshot? = { nil }
    ) throws -> Sora2PendingSubmissionReconciler {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RPCStubProtocol.self]
        configuration.urlCache = nil
        return Sora2PendingSubmissionReconciler(
            store: try Sora2PendingSubmissionStore(baseURL: directory),
            engine: Sora2BoundedHTTPJSONRPCEngine(
                sourceEngine: MetadataTestEngine(),
                session: URLSession(configuration: configuration)
            ),
            runtimeService: runtimeService,
            liveRuntimeIdentityCache: proofs,
            walletNetworkSnapshot: walletNetworkSnapshot
        )
    }

    private func stubBlockRuntime(spec: UInt32, tx: UInt32) throws {
        let hex = try fixtureMetadata().toHex(includePrefix: true)
        RPCStubProtocol.reset { method, _ in
            switch method {
            case "chain_getRuntimeVersion":
                return #"{"specVersion":\#(spec),"transactionVersion":\#(tx)}"#
            case "state_getMetadata":
                return "\"\(hex)\""
            default:
                return nil
            }
        }
    }

    /// A transfer signed at one runtime and included after an upgrade is
    /// decoded with the inclusion block's own runtime, fetched for that
    /// block and bound to its declared `System.Version`.
    func testPendingRecoveryDecodesWithTheInclusionBlockRuntime() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try stubBlockRuntime(spec: 133, tx: 131)
        // The app's current runtime is older (132) and unproven.
        let reconciler = try reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory
        )
        let block = String(repeating: "ab", count: 32)
        let factory = try await reconciler.decodingFactory(atBlock: block)
        XCTAssertEqual(factory.specVersion, 133)
        XCTAssertEqual(factory.txVersion, 131)
        XCTAssertEqual(RPCStubProtocol.calls("state_getMetadata"), ["0x" + block])
        XCTAssertNotNil(factory.metadata.getModuleIndex("System"))
        // A second block of the same runtime reuses that decoder.
        _ = try await reconciler.decodingFactory(atBlock: String(repeating: "cd", count: 32))
        XCTAssertEqual(RPCStubProtocol.calls("state_getMetadata").count, 1)

        // Metadata that declares another runtime than the block reports is
        // never used to decode.
        try stubBlockRuntime(spec: 134, tx: 131)
        let mismatched = try self.reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory
        )
        do {
            _ = try await mismatched.decodingFactory(atBlock: block)
            XCTFail("Metadata for runtime 133 must not decode a runtime 134 block")
        } catch {
            guard case ExtrinsicServiceError.runtimeUpgradeInProgress = error else {
                return XCTFail("\(error)")
            }
        }
    }

    /// The current runtime snapshot is reused only when it is the block's
    /// runtime and matches the stored proof for that version.
    func testPendingRecoveryReusesOnlyAProvenCurrentRuntime() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(
            chainId: PIIndexerClient.soraMainnetGenesis,
            runtimeMetadataItem: try item(),
            ownTypes: try chainTypes(),
            dataHasher: .twox256
        )
        let block = String(repeating: "ef", count: 32)

        try stubBlockRuntime(spec: 133, tx: 131)
        let proven = Sora2LiveRuntimeIdentityCache()
        proven.store(metadataSHA256: Self.fixtureHexLineSHA256, specVersion: 133, transactionVersion: 131)
        let reused = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: snapshot),
            proofs: proven,
            directory: directory
        ).decodingFactory(atBlock: block)
        XCTAssertEqual(reused.specVersion, 133)
        XCTAssertTrue(RPCStubProtocol.calls("state_getMetadata").isEmpty)

        // A proof that does not match the snapshot: the block's metadata is
        // fetched instead.
        try stubBlockRuntime(spec: 133, tx: 131)
        let otherProof = Sora2LiveRuntimeIdentityCache()
        otherProof.store(metadataSHA256: String(repeating: "0", count: 64), specVersion: 133, transactionVersion: 131)
        _ = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: snapshot),
            proofs: otherProof,
            directory: directory
        ).decodingFactory(atBlock: block)
        XCTAssertEqual(RPCStubProtocol.calls("state_getMetadata").count, 1)

        // No proof yet: also fetched.
        try stubBlockRuntime(spec: 133, tx: 131)
        _ = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: snapshot),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory
        ).decodingFactory(atBlock: block)
        XCTAssertEqual(RPCStubProtocol.calls("state_getMetadata").count, 1)
    }

    // MARK: - Pending recovery pass

    /// A pending transfer whose account is no longer in the wallet store (for
    /// example, removed while the transfer was pending) cannot be bound to a
    /// wallet. It stays pending and protected, and the other accounts'
    /// pending transfers are still resolved from the chain.
    func testPendingRecoveryPassResolvesOtherAccountsWhenOneEntryHasNoWallet()
        async throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let genesis = try XCTUnwrap(
            Sora2PendingSubmissionStore.normalizedHash(
                PIIndexerClient.soraMainnetGenesis
            )
        )
        func blockHash(_ number: Int) -> String {
            number == 0 ? genesis : String(format: "%064x", number)
        }
        func blockNumber(ofHash hash: String) -> Int? {
            guard let normalized = Sora2PendingSubmissionStore.normalizedHash(hash) else {
                return nil
            }
            return normalized == genesis ? 0 : Int(normalized, radix: 16)
        }
        // Era 128 ..< 192 (64 blocks); the chain is finalized well past it,
        // and no block contains either transfer.
        let birthBlock = 128
        let period = Sora2SubmissionRecoveryContext.reviewedEraPeriod
        let finalizedHeight = 300
        let zeroRoot = "0x" + String(repeating: "0", count: 64)
        func header(_ number: Int) -> String {
            #"{"parentHash":"0x\#(blockHash(max(number - 1, 0)))","number":"0x\#(String(number, radix: 16))","stateRoot":"\#(zeroRoot)","extrinsicsRoot":"\#(zeroRoot)","digest":{"logs":[]}}"#
        }
        RPCStubProtocol.reset { method, params in
            switch method {
            case "chain_getFinalizedHead":
                return "\"0x\(blockHash(finalizedHeight))\""
            case "chain_getHeader":
                return header(finalizedHeight)
            case "chain_getBlockHash":
                guard let number = params.first as? Int else { return nil }
                return "\"0x\(blockHash(number))\""
            case "chain_getBlock":
                guard
                    let hash = params.first as? String,
                    let number = blockNumber(ofHash: hash)
                else {
                    return nil
                }
                return #"{"block":{"header":\#(header(number)),"extrinsics":[]}}"#
            default:
                return nil
            }
        }

        let addressFactory = SS58AddressFactory()
        let keptKey = Data(repeating: 0x21, count: 32)
        let removedKey = Data(repeating: 0x43, count: 32)
        let kept = try addressFactory.address(
            fromAccountId: keptKey,
            type: Chain.sora.addressType()
        )
        let removed = try addressFactory.address(
            fromAccountId: removedKey,
            type: Chain.sora.addressType()
        )
        func context(
            account: String,
            key: Data,
            hash: String
        ) -> Sora2SubmissionRecoveryContext {
            Sora2SubmissionRecoveryContext(
                schemaVersion: Sora2SubmissionRecoveryContext.currentSchemaVersion,
                walletId: account,
                accountId: key.toHex(includePrefix: false).lowercased(),
                publicKey: key.toHex(includePrefix: false).lowercased(),
                transactionHash: hash,
                genesisHash: genesis,
                specVersion: 133,
                transactionVersion: 131,
                metadataSHA256: Self.fixtureHexLineSHA256,
                eraBirthBlock: birthBlock,
                eraDeathBlockExclusive: birthBlock + period,
                eraPeriod: period,
                eraPhase: birthBlock % period,
                eraBirthBlockHash: blockHash(birthBlock)
            )
        }
        let keptHash = String(repeating: "a1", count: 32)
        let removedHash = String(repeating: "b2", count: 32)
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        // The entry that cannot be bound is the older one, so it would be
        // looked at first.
        let removedPending = try store.stage(
            account: removed,
            hash: removedHash,
            recoveryContext: context(account: removed, key: removedKey, hash: removedHash)
        )
        try store.update(removedPending, state: .submissionUnknown)
        let keptPending = try store.stage(
            account: kept,
            hash: keptHash,
            recoveryContext: context(account: kept, key: keptKey, hash: keptHash)
        )
        try store.update(keptPending, state: .submissionUnknown)

        // Only the kept account is in the wallet store.
        let snapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: kept,
            wallets: [
                WalletIdentity(
                    id: kept,
                    displayName: "Kept",
                    existingSoraAddress: kept,
                    secretSource: .rawSeed
                )
            ],
            accounts: [
                NetworkAccount(
                    walletId: kept,
                    networkId: .sora2,
                    derivationVersion: 0,
                    publicKey: keptKey,
                    address: kept
                )
            ],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let reconciler = try reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory,
            walletNetworkSnapshot: { snapshot }
        )

        do {
            try await reconciler.reconcileStatusOnly()
            XCTFail("The pass must report the entry it could not resolve")
        } catch {
            guard case Sora2PendingRecoveryError.unavailable = error else {
                return XCTFail("\(error)")
            }
        }

        let entries = try store.all()
        let keptEntry = try XCTUnwrap(entries.first { $0.id == keptPending.id })
        XCTAssertEqual(keptEntry.terminalResolution?.kind, .expiredNotIncluded)
        XCTAssertEqual(keptEntry.terminalResolution?.finalizedHeight, finalizedHeight)
        let removedEntry = try XCTUnwrap(entries.first { $0.id == removedPending.id })
        XCTAssertNil(removedEntry.terminalResolution)
        XCTAssertEqual(removedEntry.state, .submissionUnknown)
        XCTAssertFalse(removedEntry.isPrunable)
        // The whole era was scanned once for the bound entry.
        XCTAssertEqual(
            Set(RPCStubProtocol.calls("chain_getBlock")).count,
            period + 1
        )

        // With no entry that can be bound, nothing is read from the chain.
        let unbound = try self.reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory,
            walletNetworkSnapshot: {
                WalletNetworkSnapshot(
                    schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
                    selectedWalletId: nil,
                    wallets: [],
                    accounts: [],
                    createdAt: Date(timeIntervalSince1970: 1)
                )
            }
        )
        RPCStubProtocol.reset { _, _ in nil }
        do {
            try await unbound.reconcileStatusOnly()
            XCTFail("An entry without a wallet must stay unresolved")
        } catch {
            guard case Sora2PendingRecoveryError.unavailable = error else {
                return XCTFail("\(error)")
            }
        }
        XCTAssertTrue(RPCStubProtocol.calls("chain_getFinalizedHead").isEmpty)
        XCTAssertNil(
            try XCTUnwrap(store.all().first { $0.id == removedPending.id })
                .terminalResolution
        )
    }

    private func assertError<T>(
        _ expression: @autoclosure () throws -> T,
        isUpgrade: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            switch error {
            case ExtrinsicServiceError.runtimeUpgradeInProgress:
                XCTAssertTrue(isUpgrade, "\(error)", file: file, line: line)
            case ExtrinsicServiceError.unsupportedRuntimeMetadata:
                XCTAssertFalse(isUpgrade, "\(error)", file: file, line: line)
            default:
                XCTFail("Unexpected \(error)", file: file, line: line)
            }
        }
    }
}


// MARK: - Runtime sync test doubles

private struct QuickRetry: SoraPassport.ReconnectionStrategyProtocol {
    func reconnectAfter(attempt: Int) -> TimeInterval? {
        attempt <= 20 ? 0.1 : nil
    }
}

/// Answers `state_getMetadata` with a configurable result; can hold the
/// answer until released.
private final class MetadataTestEngine: JSONRPCEngine {
    var url: URL? = URL(string: "wss://metadata.test")
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    private let lock = NSCondition()
    private var answer = ""
    private var held = false
    private var calls = 0

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func respond(with hex: String) {
        lock.lock()
        answer = hex
        lock.unlock()
    }

    func hold() {
        lock.lock()
        held = true
        lock.unlock()
    }

    func release() {
        lock.lock()
        held = false
        lock.broadcast()
        lock.unlock()
    }

    func waitForCalls(_ count: Int, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        lock.lock()
        defer { lock.unlock() }
        while calls < count {
            guard lock.wait(until: deadline) else {
                return calls >= count
            }
        }
        return true
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        guard method == SoraPassport.RPCMethod.getRuntimeMetadata else {
            throw JSONRPCEngineError.unknownError
        }
        lock.lock()
        calls += 1
        lock.broadcast()
        lock.unlock()
        DispatchQueue.global().async {
            self.lock.lock()
            while self.held {
                self.lock.wait()
            }
            let hex = self.answer
            self.lock.unlock()
            if let value = hex as? T {
                closure?(.success(value))
            } else {
                closure?(.failure(JSONRPCEngineError.unknownError))
            }
        }
        return 1
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String, params _: P?, updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 { 0 }
    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url _: URL) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

private final class RuntimeTestConnection: ChainConnection {
    var url: URL? = URL(string: "wss://metadata.test")
    var state: WebSocketEngine.State = .notConnected
    var ranking: [ConnectionRank] = []
    var pendingEngineRequests: [JSONRPCRequest] = []
    func set(ranking: [ConnectionRank]) { self.ranking = ranking }
    func disconnectIfNeeded() {}
    func reconnect(url: URL) { self.url = url }
    func connectIfNeeded() {}
    func callMethod<P: Codable, T: Decodable>(
        _: String, params _: P?, options _: JSONRPCOptions,
        completion _: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        throw JSONRPCEngineError.unknownError
    }
    func subscribe<P: Codable, T: Decodable>(
        _: String, params _: P?, updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 { 0 }
    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 0 }
    func addSubscription(_: JSONRPCSubscribing) {}
    func unsubsribe(_: UInt16) throws {}
}

private final class RuntimeTestRepository: DataProviderRepositoryProtocol {
    typealias Model = SoraPassport.RuntimeMetadataItem

    private let lock = NSLock()
    private var stored: [Model]

    init(items: [Model]) {
        stored = items
    }

    var items: [Model] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { self.items }
    }

    func saveOperation(
        _ updates: @escaping () throws -> [Model],
        _ deletions: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation {
            let changed = try updates()
            let removed = try deletions()
            self.lock.lock()
            defer { self.lock.unlock() }
            self.stored.removeAll { old in
                removed.contains(old.chain) || changed.contains { $0.chain == old.chain }
            }
            self.stored.append(contentsOf: changed)
        }
    }

    func saveBatchOperation(
        _ updates: @escaping () throws -> [Model],
        _ deletions: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        saveOperation(updates, deletions)
    }

    func fetchOperation(
        by ids: @escaping () throws -> [String],
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        ClosureOperation {
            let selected = try ids()
            return self.items.filter { selected.contains($0.chain) }
        }
    }

    func fetchOperation(
        by id: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<Model?> {
        ClosureOperation {
            let selected = try id()
            return self.items.first { $0.chain == selected }
        }
    }

    func fetchOperation(
        by _: RepositorySliceRequest,
        options: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        fetchAllOperation(with: options)
    }

    func replaceOperation(_ models: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        saveOperation(models, { self.items.map(\.chain) })
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        replaceOperation { [] }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { self.items.count }
    }
}


// MARK: - Recovery test doubles

private final class RuntimeTestProvider: RuntimeProviderProtocol {
    let chainId: SoraPassport.ChainModel.Id = PIIndexerClient.soraMainnetGenesis
    let snapshot: RuntimeSnapshot?

    init(snapshot: RuntimeSnapshot?) {
        self.snapshot = snapshot
    }

    func setup() {}
    func setupHot() {}
    func replaceTypesUsage(_: SoraPassport.ChainModel.TypesUsage) {}
    func cleanup() {}

    func fetchCoderFactoryOperation(
        with _: TimeInterval,
        closure _: SoraPassport.RuntimeMetadataClosure?
    ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { throw BaseOperationError.parentOperationCancelled }
    }
}

/// JSON-RPC over HTTPS, answered in process for the bounded transport.
private final class RPCStubProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var responder: ((String, [Any]) -> String?)?
    private static var recorded: [(method: String, params: [Any])] = []

    static func reset(_ responder: @escaping (String, [Any]) -> String?) {
        lock.lock()
        self.responder = responder
        recorded = []
        lock.unlock()
    }

    static func calls(_ method: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded.filter { $0.method == method }.map {
            ($0.params.first as? String) ?? ""
        }
    }

    override class func canInit(with _: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(buffer, count: count)
            }
            stream.close()
        }
        let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        let method = object["method"] as? String ?? ""
        let params = object["params"] as? [Any] ?? []
        let identifier = object["id"] as? Int ?? 0
        Self.lock.lock()
        Self.recorded.append((method, params))
        let result = Self.responder?(method, params)
        Self.lock.unlock()
        let text = result.map {
            #"{"jsonrpc":"2.0","id":\#(identifier),"result":\#($0)}"#
        } ?? #"{"jsonrpc":"2.0","id":\#(identifier),"error":{"code":-32601,"message":"Method not found"}}"#
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
