// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
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
    /// The proof identity of the test engines' node, `wss://metadata.test`.
    private static let node = "https://metadata.test/"
    private static let otherNode = "https://other.test/"

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

    func testLiveRuntimeCacheIsKeyedByNodeAndRuntimeVersion() {
        let cache = Sora2LiveRuntimeIdentityCache()
        cache.store(
            metadataSHA256: Self.fixtureHexLineSHA256,
            node: Self.node,
            specVersion: 133,
            transactionVersion: 131
        )
        XCTAssertEqual(
            cache.metadataSHA256(node: Self.node, specVersion: 133, transactionVersion: 131),
            Self.fixtureHexLineSHA256
        )
        XCTAssertNil(
            cache.metadataSHA256(node: Self.node, specVersion: 134, transactionVersion: 131)
        )
        XCTAssertNil(
            cache.metadataSHA256(node: Self.node, specVersion: 133, transactionVersion: 132)
        )
        // What one node proved says nothing about another node.
        XCTAssertNil(
            cache.metadataSHA256(node: Self.otherNode, specVersion: 133, transactionVersion: 131)
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

    // MARK: - Balances layout (runtime 124 and later)

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

    /// Runtime 124 replaced `misc_frozen, fee_frozen` with `frozen, flags` in
    /// the balances pallet. Decoding `System.Account` into the app's model
    /// failed for every account (seen on runtime 133), so XOR balances read
    /// as zero and the send flow could not read the recipient's account. Both
    /// layouts must decode, and the spendable amount must never exceed what
    /// the chain allows.
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

    /// The layout of runtime 119 and earlier still decodes as before, and the
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
            node: Self.node,
            specVersion: 133,
            transactionVersion: 131
        )
        let relaunched = Sora2LiveRuntimeIdentityCache(defaults: defaults)
        XCTAssertEqual(
            relaunched.metadataSHA256(node: Self.node, specVersion: 133, transactionVersion: 131),
            Self.fixtureHexLineSHA256
        )
        // A proof for a runtime below the reviewed floor, a malformed value,
        // or a node without an identity is never stored or loaded.
        relaunched.store(metadataSHA256: Self.fixtureHexLineSHA256, node: Self.node, specVersion: 129, transactionVersion: 129)
        relaunched.store(metadataSHA256: "not-a-hash", node: Self.node, specVersion: 134, transactionVersion: 131)
        relaunched.store(metadataSHA256: Self.fixtureHexLineSHA256, node: "ws://plain.test", specVersion: 134, transactionVersion: 131)
        var persisted = defaults.dictionary(forKey: Sora2LiveRuntimeIdentityCache.persistenceKey) ?? [:]
        XCTAssertEqual(Array(persisted.keys), ["133:131 \(Self.node)"])
        persisted["135:131 \(Self.node)"] = "XYZ"
        persisted["garbage"] = Self.fixtureHexLineSHA256
        // The form of the previous build, which had no node: not a proof
        // for any node.
        persisted["136:131"] = Self.fixtureHexLineSHA256
        defaults.set(persisted, forKey: Sora2LiveRuntimeIdentityCache.persistenceKey)
        let reloaded = Sora2LiveRuntimeIdentityCache(defaults: defaults)
        XCTAssertNil(reloaded.metadataSHA256(node: Self.node, specVersion: 135, transactionVersion: 131))
        XCTAssertNil(reloaded.metadataSHA256(node: Self.node, specVersion: 136, transactionVersion: 131))
        XCTAssertEqual(
            reloaded.metadataSHA256(node: Self.node, specVersion: 133, transactionVersion: 131),
            Self.fixtureHexLineSHA256
        )
        // In-memory caches never write.
        let memoryOnly = Sora2LiveRuntimeIdentityCache()
        memoryOnly.store(metadataSHA256: Self.fixtureHexLineSHA256, node: Self.node, specVersion: 140, transactionVersion: 131)
        XCTAssertNil(Sora2LiveRuntimeIdentityCache(defaults: defaults)
            .metadataSHA256(node: Self.node, specVersion: 140, transactionVersion: 131))
    }

    /// S-9: a proof learned from one node is not used for another. Version 1
    /// of the store kept one proof per runtime version, so metadata a custom
    /// node had served stayed trusted after the user went back to a bundled
    /// node. Each node now proves its own metadata, and the proofs the
    /// previous build stored are not read.
    func testLiveRuntimeProofIsNotReusedForAnotherNode() throws {
        let suite = "Sora2LiveRuntimeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        // What the previous build left behind: one proof for runtime
        // 133/131 with no node, here for altered metadata.
        let altered = String(repeating: "ab", count: 32)
        defaults.set(
            ["133:131": altered],
            forKey: "sora2.mainnet.liveRuntimeMetadataProofs.v1"
        )
        let cache = Sora2LiveRuntimeIdentityCache(defaults: defaults)
        let version = try runtimeVersion(spec: 133, tx: 131)
        let hex = try fixtureMetadata().toHex(includePrefix: true)

        // A custom node proves (altered) metadata for itself.
        cache.store(metadataSHA256: altered, node: Self.otherNode, specVersion: 133, transactionVersion: 131)

        // Back on the first node: nothing is assumed, its own metadata is
        // downloaded and bound to its runtime version.
        var downloads = 0
        let proven = try cache.liveRuntime(for: version, node: Self.node) {
            downloads += 1
            return hex
        }
        XCTAssertEqual(downloads, 1)
        XCTAssertEqual(proven, live())
        // The app's metadata is then checked against this node's proof, not
        // the other node's.
        XCTAssertNoThrow(try Sora2LiveRuntimeValidator.validate(factory: try factory(), live: proven))
        let otherNodeView = try cache.liveRuntime(for: version, node: Self.otherNode) {
            XCTFail("The other node has its own stored proof")
            return ""
        }
        assertError(
            try Sora2LiveRuntimeValidator.validate(factory: try factory(), live: otherNodeView),
            isUpgrade: false
        )
        // Both proofs are kept side by side, each under its node.
        let relaunched = Sora2LiveRuntimeIdentityCache(defaults: defaults)
        XCTAssertEqual(
            relaunched.metadataSHA256(node: Self.node, specVersion: 133, transactionVersion: 131),
            Self.fixtureHexLineSHA256
        )
        XCTAssertEqual(
            relaunched.metadataSHA256(node: Self.otherNode, specVersion: 133, transactionVersion: 131),
            altered
        )

        // The identity of a node is its HTTPS signing route.
        XCTAssertEqual(
            Sora2LiveRuntimeIdentityCache.nodeIdentity(for: URL(string: "wss://WS.mof.sora.org")),
            "https://ws.mof.sora.org/"
        )
        XCTAssertEqual(
            Sora2LiveRuntimeIdentityCache.nodeIdentity(for: URL(string: "wss://node.example:9944/rpc")),
            "https://node.example:9944/rpc"
        )
        XCTAssertNil(Sora2LiveRuntimeIdentityCache.nodeIdentity(for: URL(string: "ws://node.example:9944")))
        XCTAssertNil(Sora2LiveRuntimeIdentityCache.nodeIdentity(for: nil))
        // A node without a signing route cannot be proven at all.
        XCTAssertThrowsError(try cache.liveRuntime(for: version, node: "ws://node.example") { hex })
    }

    /// The extrinsic service asks the proof cache for the node its engine
    /// points at, so a change of node is a new proof.
    func testExtrinsicServiceProvesTheLiveRuntimePerNode() throws {
        let hex = try fixtureMetadata().toHex(includePrefix: true)
        RPCStubProtocol.reset { method, _ in
            switch method {
            case "chain_getRuntimeVersion":
                return #"{"specVersion":133,"transactionVersion":131}"#
            case "state_getMetadata":
                return "\"\(hex)\""
            default:
                return nil
            }
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RPCStubProtocol.self]
        let source = MetadataTestEngine()
        let proofs = Sora2LiveRuntimeIdentityCache()
        let service = ExtrinsicService(
            address: try SS58AddressFactory().address(
                fromAccountId: Data(repeating: 0x42, count: 32),
                type: Chain.sora.addressType()
            ),
            cryptoType: .sr25519,
            runtimeRegistry: RuntimeTestProvider(snapshot: nil),
            engine: Sora2BoundedHTTPJSONRPCEngine(
                sourceEngine: source,
                session: URLSession(configuration: configuration)
            ),
            operationManager: OperationManager(),
            liveRuntimeIdentityCache: proofs
        )
        func runLiveRuntime() -> Result<Sora2LiveRuntime, Error>? {
            let operations = service.createLiveRuntimeOperations()
            OperationQueue().addOperations(operations.all, waitUntilFinished: true)
            return operations.identity.result
        }
        XCTAssertEqual(try runLiveRuntime()?.get(), live())
        XCTAssertEqual(try runLiveRuntime()?.get(), live())
        XCTAssertEqual(RPCStubProtocol.calls("state_getMetadata").count, 1)
        XCTAssertNotNil(proofs.metadataSHA256(node: Self.node, specVersion: 133, transactionVersion: 131))

        // The connection moves to another node: its metadata is proven too.
        source.url = URL(string: "wss://other.test")
        XCTAssertEqual(try runLiveRuntime()?.get(), live())
        XCTAssertEqual(RPCStubProtocol.calls("state_getMetadata").count, 2)
        XCTAssertNotNil(proofs.metadataSHA256(node: Self.otherNode, specVersion: 133, transactionVersion: 131))

        // A node without an HTTPS route is refused before any proof.
        source.url = URL(string: "ws://plain.test")
        guard case let .failure(error)? = runLiveRuntime() else {
            return XCTFail("A node without a signing route cannot prove a runtime")
        }
        XCTAssertNotNil(Sora2BoundedHTTPJSONRPCError.signingRouteUserMessage(for: error))
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
                let result = Result { try cache.liveRuntime(for: version, node: Self.node, fetchMetadataHex: fetch) }
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
            try cache.liveRuntime(for: version, node: Self.node) {
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
            try cache.liveRuntime(for: version, node: Self.node) { throw URLError(.notConnectedToInternet) }
        )
        XCTAssertNil(cache.metadataSHA256(node: Self.node, specVersion: 133, transactionVersion: 131))
        let hex = try fixtureMetadata().toHex(includePrefix: true)
        XCTAssertEqual(try cache.liveRuntime(for: version, node: Self.node) { hex }, live())
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
        XCTAssertNil(proofs.metadataSHA256(node: Self.node, specVersion: 133, transactionVersion: 131))

        // The node now serves its real metadata: it replaces the stored copy
        // and becomes the proof for this runtime.
        engine.respond(with: try fixtureMetadata().toHex(includePrefix: true))
        let deadline = Date().addingTimeInterval(20)
        while proofs.metadataSHA256(node: Self.node, specVersion: 133, transactionVersion: 131) == nil,
              Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertEqual(
            proofs.metadataSHA256(node: Self.node, specVersion: 133, transactionVersion: 131),
            Self.fixtureHexLineSHA256
        )
        // The proof belongs to the node the bytes came from, and to no other.
        XCTAssertNil(proofs.metadataSHA256(node: Self.otherNode, specVersion: 133, transactionVersion: 131))
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
        walletNetworkSnapshot: @escaping () throws -> WalletNetworkSnapshot? = { nil },
        archiveNodes: [String] = [],
        indexedExecution: Sora2IndexedExecutionLookup? = nil,
        rotation: Sora2PendingReconciliationRotation = Sora2PendingReconciliationRotation(),
        now: @escaping () -> Date = Date.init
    ) throws -> Sora2PendingSubmissionReconciler {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RPCStubProtocol.self]
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        // Unit tests never reach the bundled archive nodes or the indexer:
        // both are replaced, by nothing unless a test names them.
        return Sora2PendingSubmissionReconciler(
            store: try Sora2PendingSubmissionStore(baseURL: directory),
            engine: Sora2BoundedHTTPJSONRPCEngine(
                sourceEngine: MetadataTestEngine(),
                session: session
            ),
            runtimeService: runtimeService,
            liveRuntimeIdentityCache: proofs,
            walletNetworkSnapshot: walletNetworkSnapshot,
            archiveEngines: {
                archiveNodes.compactMap { URL(string: $0) }.map {
                    Sora2BoundedHTTPJSONRPCEngine(nodeURL: $0, session: session)
                }
            },
            indexedExecution: indexedExecution,
            rotation: rotation,
            now: now
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
        proven.store(metadataSHA256: Self.fixtureHexLineSHA256, node: Self.node, specVersion: 133, transactionVersion: 131)
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
        otherProof.store(metadataSHA256: String(repeating: "0", count: 64), node: Self.node, specVersion: 133, transactionVersion: 131)
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

    // MARK: - Pending reconciliation against a node that prunes state (S-2, LIVE-8)

    private static let prunedHost = "metadata.test"
    private static let archiveNode = "wss://archive.test"
    private static let archiveHost = "archive.test"

    /// A stub chain. Block `n` has the hash `%064x` of `n` (block zero the
    /// mainnet genesis). Every node keeps every block; what differs between
    /// nodes is the state.
    private struct StubChain {
        let genesis: String
        var finalizedHeight: Int
        /// Hex extrinsics per block number.
        var extrinsics: [Int: [String]] = [:]
        /// Block numbers whose body no node can give (a read that fails).
        var unreadableBlocks: ClosedRange<Int>?

        func blockHash(_ number: Int) -> String {
            number == 0 ? genesis : String(format: "%064x", number)
        }

        func blockNumber(ofHash hash: String) -> Int? {
            guard let normalized = Sora2PendingSubmissionStore.normalizedHash(hash) else {
                return nil
            }
            return normalized == genesis ? 0 : Int(normalized, radix: 16)
        }

        func header(_ number: Int) -> String {
            let zeroRoot = "0x" + String(repeating: "0", count: 64)
            return #"{"parentHash":"0x\#(blockHash(max(number - 1, 0)))","number":"0x\#(String(number, radix: 16))","stateRoot":"\#(zeroRoot)","extrinsicsRoot":"\#(zeroRoot)","digest":{"logs":[]}}"#
        }

        /// The `chain_*` answers, the same on every node.
        func chainAnswer(_ method: String, _ params: [Any]) -> RPCStubProtocol.Answer? {
            switch method {
            case "chain_getFinalizedHead":
                return .result("\"0x\(blockHash(finalizedHeight))\"")
            case "chain_getHeader":
                return .result(header(finalizedHeight))
            case "chain_getBlockHash":
                guard let number = params.first as? Int else { return nil }
                return .result("\"0x\(blockHash(number))\"")
            case "chain_getBlock":
                guard
                    let hash = params.first as? String,
                    let number = blockNumber(ofHash: hash)
                else {
                    return nil
                }
                if let unreadableBlocks, unreadableBlocks.contains(number) {
                    return .error(code: -32000, message: "Block body unavailable")
                }
                let body = (extrinsics[number] ?? []).map { "\"\($0)\"" }.joined(separator: ",")
                return .result(#"{"block":{"header":\#(header(number)),"extrinsics":[\#(body)]}}"#)
            default:
                return nil
            }
        }

        /// The block a state request names, when it names one.
        static func stateBlock(_ method: String, _ params: [Any]) -> String? {
            switch method {
            case "chain_getRuntimeVersion", "state_getMetadata":
                return params.first as? String
            case "state_queryStorageAt":
                return params.count > 1 ? params[1] as? String : nil
            default:
                return nil
            }
        }
    }

    /// `System.Events` of a block as runtime 133 encodes it, with one
    /// terminal event per extrinsic. The layout is the one mainnet returns
    /// (`0x04000000000000002290753e5517020000` for a block with one
    /// extrinsic).
    private func eventsHex(_ outcomes: [Bool]) -> String {
        var data = Data([UInt8(outcomes.count << 2)])
        for (index, succeeded) in outcomes.enumerated() {
            data.append(0x00) // Phase::ApplyExtrinsic
            withUnsafeBytes(of: UInt32(index).littleEndian) { data.append(contentsOf: $0) }
            // System.ExtrinsicSuccess, or System.ExtrinsicFailed with
            // DispatchError::Other.
            data.append(contentsOf: succeeded ? [0x00, 0x00] : [0x00, 0x01, 0x00])
            data.append(contentsOf: [0x22, 0x90, 0x75, 0x3e, 0x55, 0x17]) // weight
            data.append(contentsOf: [0x00, 0x00]) // class, pays fee
            data.append(0x00) // no topics
        }
        return data.toHex(includePrefix: true)
    }

    /// An archive node: the chain, plus the state of every block.
    private func archiveAnswer(
        chain: StubChain,
        events: [Int: [Bool]],
        _ method: String,
        _ params: [Any]
    ) throws -> RPCStubProtocol.Answer? {
        if let answer = chain.chainAnswer(method, params) {
            return answer
        }
        switch method {
        case "chain_getRuntimeVersion":
            return .result(#"{"specVersion":133,"transactionVersion":131}"#)
        case "state_getMetadata":
            return .result("\"\(try fixtureMetadata().toHex(includePrefix: true))\"")
        case "state_queryStorageAt":
            guard
                let keys = params.first as? [String],
                let key = keys.first,
                params.count > 1,
                let block = params[1] as? String,
                let number = chain.blockNumber(ofHash: block),
                let outcomes = events[number]
            else {
                return nil
            }
            return .result(#"[{"block":"\#(block)","changes":[["\#(key)","\#(eventsHex(outcomes))"]]}]"#)
        default:
            return nil
        }
    }

    /// A node that keeps the chain but has discarded the state of every
    /// block a test asks about, as the first bundled node does after about
    /// 256 blocks.
    private func prunedAnswer(
        chain: StubChain,
        _ method: String,
        _ params: [Any]
    ) -> RPCStubProtocol.Answer? {
        if let answer = chain.chainAnswer(method, params) {
            return answer
        }
        if let block = StubChain.stateBlock(method, params) {
            return .stateDiscarded(block)
        }
        return nil
    }

    private struct PendingAccount {
        let address: String
        let key: Data
        let snapshot: WalletNetworkSnapshot
    }

    private func pendingAccount(_ byte: UInt8 = 0x21) throws -> PendingAccount {
        let key = Data(repeating: byte, count: 32)
        let address = try SS58AddressFactory().address(
            fromAccountId: key,
            type: Chain.sora.addressType()
        )
        return PendingAccount(
            address: address,
            key: key,
            snapshot: WalletNetworkSnapshot(
                schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
                selectedWalletId: address,
                wallets: [
                    WalletIdentity(
                        id: address,
                        displayName: "Sender",
                        existingSoraAddress: address,
                        secretSource: .rawSeed
                    )
                ],
                accounts: [
                    NetworkAccount(
                        walletId: address,
                        networkId: .sora2,
                        derivationVersion: 0,
                        publicKey: key,
                        address: address
                    )
                ],
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )
    }

    private func pendingContext(
        account: PendingAccount,
        hash: String,
        chain: StubChain,
        birthBlock: Int,
        birthBlockHash: String? = nil
    ) -> Sora2SubmissionRecoveryContext {
        let period = Sora2SubmissionRecoveryContext.reviewedEraPeriod
        return Sora2SubmissionRecoveryContext(
            schemaVersion: Sora2SubmissionRecoveryContext.currentSchemaVersion,
            walletId: account.address,
            accountId: account.key.toHex(includePrefix: false).lowercased(),
            publicKey: account.key.toHex(includePrefix: false).lowercased(),
            transactionHash: hash,
            genesisHash: chain.genesis,
            specVersion: 133,
            transactionVersion: 131,
            metadataSHA256: Self.fixtureHexLineSHA256,
            eraBirthBlock: birthBlock,
            eraDeathBlockExclusive: birthBlock + period,
            eraPeriod: period,
            eraPhase: birthBlock % period,
            eraBirthBlockHash: birthBlockHash ?? chain.blockHash(birthBlock)
        )
    }

    /// Writes a journal as a build of the app would have left it (same
    /// encoding, same durable writer), for entries whose age matters.
    private func writeJournal(_ entries: [Sora2PendingSubmission], in directory: URL) throws {
        let folder = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try DurableFileWriter.write(
            try encoder.encode(entries),
            to: folder.appendingPathComponent("sora2-signed-v1.json"),
            fileManager: .default,
            protection: .completeUntilFirstUserAuthentication
        )
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func mainnetChain(finalizedHeight: Int) throws -> StubChain {
        StubChain(
            genesis: try XCTUnwrap(
                Sora2PendingSubmissionStore.normalizedHash(PIIndexerClient.soraMainnetGenesis)
            ),
            finalizedHeight: finalizedHeight
        )
    }

    /// The node's own words for discarded state become one typed error, and
    /// nothing else does. Before, every node error was the same
    /// `remoteError`, so the app could not know an archive would answer.
    func testBoundedTransportRecognisesDiscardedState() throws {
        let block = "0x5c76cd611d50d4d17657e22347521ea550ea69bc3d0dde74412fc6a46dc7b09a"
        // The two answers `ws.mof.sora.org` gave on 12 October 2026 for
        // `chain_getRuntimeVersion` and `state_queryStorageAt` at a block
        // 2,000 blocks behind the head.
        for message in [
            "Client error: Api called for an unknown Block: State already discarded for \(block)",
            "Client error: UnknownBlock: State already discarded for \(block)"
        ] {
            let body = Data(#"{"jsonrpc":"2.0","id":7,"error":{"code":4003,"message":"\#(message)"}}"#.utf8)
            XCTAssertThrowsError(try Sora2BoundedHTTPJSONRPCEngine.validateEnvelope(body, identifier: 7)) { error in
                guard case Sora2BoundedHTTPJSONRPCError.blockStateUnavailable = error else {
                    return XCTFail("\(error)")
                }
            }
        }
        let other = Data(#"{"jsonrpc":"2.0","id":7,"error":{"code":1010,"message":"Invalid Transaction"}}"#.utf8)
        XCTAssertThrowsError(try Sora2BoundedHTTPJSONRPCEngine.validateEnvelope(other, identifier: 7)) { error in
            guard case Sora2BoundedHTTPJSONRPCError.remoteError = error else {
                return XCTFail("\(error)")
            }
        }
    }

    /// S-2 / LIVE-8. A transfer is in a finalized block, and the connected
    /// node has already discarded that block's state ("State already
    /// discarded", error 4003). Before the fix the entry stayed unresolved
    /// for as long as the app was connected to that node. Now the result is
    /// read from an archive node that proves the same genesis and the same
    /// block.
    func testPendingRecoveryReadsTheResultFromAnArchiveWhenTheNodePrunedState() async throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        var chain = try mainnetChain(finalizedHeight: 5_000)
        let extrinsic = Data([0x12, 0x34, 0xab, 0xcd])
        let hash = try extrinsic.blake2b32().toHex(includePrefix: false)
        chain.extrinsics[130] = ["0x00", extrinsic.toHex(includePrefix: true)]
        let archive = chain
        RPCStubProtocol.resetByHost { [unowned self] host, method, params in
            host == Self.archiveHost
                ? try? self.archiveAnswer(chain: archive, events: [130: [true, true]], method, params)
                : self.prunedAnswer(chain: archive, method, params)
        }

        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let pending = try store.stage(
            account: account.address,
            hash: hash,
            recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128)
        )
        try store.update(pending, state: .submitted)
        XCTAssertFalse(try XCTUnwrap(store.all().first).isPrunable)

        let report = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory,
            walletNetworkSnapshot: { account.snapshot },
            archiveNodes: [Self.archiveNode]
        ).reconcile()

        XCTAssertEqual(report.resolved, 1)
        XCTAssertFalse(report.hasUnresolved)
        let entry = try XCTUnwrap(store.all().first)
        XCTAssertEqual(entry.terminalResolution?.kind, .finalizedSuccess)
        XCTAssertEqual(entry.terminalResolution?.blockNumber, 130)
        XCTAssertEqual(entry.terminalResolution?.blockHash, chain.blockHash(130))
        XCTAssertTrue(entry.isPrunable)
        // The connected node was asked first and said the state was gone.
        XCTAssertEqual(RPCStubProtocol.callCount("chain_getRuntimeVersion", host: Self.prunedHost), 1)
        // The archive proved genesis and the block before its state was read.
        XCTAssertEqual(RPCStubProtocol.callCount("chain_getBlockHash", host: Self.archiveHost), 2)
        XCTAssertEqual(RPCStubProtocol.callCount("state_queryStorageAt", host: Self.archiveHost), 1)
        // Blocks were scanned on the connected node only.
        XCTAssertEqual(RPCStubProtocol.callCount("chain_getBlock", host: Self.archiveHost), 0)
        // Activity shows the final status.
        let overlay = TransactionHistoryMergeManager.pendingJournalOverlay(
            address: account.address,
            submissions: try store.all(),
            visibleLocalItems: [],
            remoteHashes: []
        )
        XCTAssertEqual(overlay.first?.status, .success)
    }

    /// A failed extrinsic is reported as failed, read the same way.
    func testPendingRecoveryReadsAFailedResultFromAnArchive() async throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        var chain = try mainnetChain(finalizedHeight: 5_000)
        let extrinsic = Data([0x56, 0x78])
        let hash = try extrinsic.blake2b32().toHex(includePrefix: false)
        chain.extrinsics[150] = [extrinsic.toHex(includePrefix: true)]
        let archive = chain
        RPCStubProtocol.resetByHost { [unowned self] host, method, params in
            host == Self.archiveHost
                ? try? self.archiveAnswer(chain: archive, events: [150: [false]], method, params)
                : self.prunedAnswer(chain: archive, method, params)
        }
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let pending = try store.stage(
            account: account.address,
            hash: hash,
            recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128)
        )
        try store.update(pending, state: .submissionUnknown)

        try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory,
            walletNetworkSnapshot: { account.snapshot },
            archiveNodes: [Self.archiveNode]
        ).reconcileStatusOnly()

        let entry = try XCTUnwrap(store.all().first)
        XCTAssertEqual(entry.terminalResolution?.kind, .finalizedFailure)
        XCTAssertEqual(entry.state, .submitted)
    }

    /// An archive is believed only for the block the connected node named:
    /// another genesis, or another block at that height, is not asked for
    /// state. Without any source the inclusion itself is recorded. The entry
    /// then no longer blocks account removal or holds a journal place, and
    /// the next pass reads only the result, without scanning blocks again.
    func testPendingRecoveryRecordsInclusionWhenNoSourceHasTheResult() async throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        var chain = try mainnetChain(finalizedHeight: 5_000)
        let extrinsic = Data([0x9a, 0xbc])
        let hash = try extrinsic.blake2b32().toHex(includePrefix: false)
        chain.extrinsics[131] = [extrinsic.toHex(includePrefix: true)]
        let connected = chain
        // An "archive" on another chain, and one with another block 131.
        let foreign = StubChain(
            genesis: String(repeating: "7e", count: 32),
            finalizedHeight: chain.finalizedHeight,
            extrinsics: chain.extrinsics
        )
        RPCStubProtocol.resetByHost { [unowned self] host, method, params in
            switch host {
            case "foreign.test":
                return try? self.archiveAnswer(chain: foreign, events: [131: [true]], method, params)
            case "fork.test":
                if method == "chain_getBlockHash", params.first as? Int == 131 {
                    return .result("\"0x\(String(repeating: "f0", count: 32))\"")
                }
                return try? self.archiveAnswer(chain: connected, events: [131: [true]], method, params)
            case "down.test":
                return .http(502)
            default:
                return self.prunedAnswer(chain: connected, method, params)
            }
        }
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let pending = try store.stage(
            account: account.address,
            hash: hash,
            recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128)
        )
        try store.update(pending, state: .submissionUnknown)

        var indexerAnswer: Sora2IndexedExecution?
        var indexerCalls: [(String, String)] = []
        let rotation = Sora2PendingReconciliationRotation()
        func pass(archives: [String]) async throws -> Sora2PendingReconciliationReport {
            try await reconciler(
                runtimeService: RuntimeTestProvider(snapshot: nil),
                proofs: Sora2LiveRuntimeIdentityCache(),
                directory: directory,
                walletNetworkSnapshot: { account.snapshot },
                archiveNodes: archives,
                indexedExecution: { address, transaction in
                    indexerCalls.append((address, transaction))
                    return indexerAnswer
                },
                rotation: rotation
            ).reconcile()
        }

        // The indexer names another block for this hash: not this transaction's
        // record, so its flag is not used.
        indexerAnswer = Sora2IndexedExecution(blockNumber: 132, blockHash: chain.blockHash(132), succeeded: true)
        let first = try await pass(archives: ["wss://foreign.test", "wss://fork.test", "wss://down.test"])
        XCTAssertEqual(first.resolved, 0)
        XCTAssertEqual(first.awaitingResult, 1)
        XCTAssertEqual(indexerCalls.count, 1)
        XCTAssertEqual(indexerCalls.first?.0, account.address)
        XCTAssertEqual(indexerCalls.first?.1, hash)
        // No state was asked of a node that did not prove the chain and block.
        for host in ["foreign.test", "fork.test", "down.test"] {
            XCTAssertEqual(RPCStubProtocol.callCount("state_queryStorageAt", host: host), 0, host)
            XCTAssertEqual(RPCStubProtocol.callCount("state_getMetadata", host: host), 0, host)
        }
        var entry = try XCTUnwrap(store.all().first)
        XCTAssertNil(entry.terminalResolution)
        XCTAssertEqual(entry.finalizedInclusion?.blockNumber, 131)
        XCTAssertEqual(entry.finalizedInclusion?.blockHash, chain.blockHash(131))
        XCTAssertEqual(entry.finalizedInclusion?.extrinsicIndex, 0)
        // It is on the chain for good: transport is no longer in doubt, and
        // nothing waits for it.
        XCTAssertEqual(entry.state, .submitted)
        XCTAssertFalse(entry.mayStillEnterChain(now: Date()))
        XCTAssertNoThrow(
            try WalletPendingDeletionPolicy.validate(
                nexusTransactions: [],
                polkamarktTransactions: [],
                sora2Submissions: try store.all(),
                walletId: account.address,
                soraAddress: account.address
            )
        )
        // Activity says pending while the result is still being looked for.
        XCTAssertEqual(
            TransactionHistoryMergeManager.pendingJournalOverlay(
                address: account.address,
                submissions: [entry],
                visibleLocalItems: [],
                remoteHashes: []
            ).first?.status,
            .pending
        )

        // Next pass: the indexer has the transaction in that very block. No
        // block is fetched again; only the result is read.
        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: connected, method, params)
        }
        indexerAnswer = Sora2IndexedExecution(blockNumber: 131, blockHash: chain.blockHash(131), succeeded: false)
        let second = try await pass(archives: [])
        XCTAssertEqual(second.resolved, 1)
        XCTAssertFalse(second.hasUnresolved)
        // Only block zero (the chain check) was read.
        XCTAssertEqual(RPCStubProtocol.callCount("chain_getBlock", host: Self.prunedHost), 1)
        entry = try XCTUnwrap(store.all().first)
        XCTAssertEqual(entry.terminalResolution?.kind, .finalizedFailure)
        XCTAssertEqual(entry.terminalResolution?.blockNumber, 131)
        XCTAssertTrue(entry.isPrunable)
    }

    /// A finalized transaction whose result nobody could give for a week is
    /// no longer asked about and no longer shown as pending. The indexer's
    /// own row is then the record.
    func testFinalizedEntryWithoutAResultAgesOut() async throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        let chain = try mainnetChain(finalizedHeight: 5_000)
        let hash = String(repeating: "c4", count: 32)
        let created = Date(timeIntervalSince1970: 1_800_000_000)
        let entry = Sora2PendingSubmission(
            id: UUID(),
            account: account.address,
            extrinsicHash: hash,
            createdAt: created,
            updatedAt: created,
            state: .submitted,
            recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128),
            finalizedInclusion: Sora2PendingFinalizedInclusion(
                schemaVersion: Sora2PendingFinalizedInclusion.currentSchemaVersion,
                blockNumber: 140,
                blockHash: chain.blockHash(140),
                extrinsicIndex: 2,
                finalizedHeight: 200
            )
        )
        try writeJournal([entry], in: directory)
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        XCTAssertEqual(try store.all(), [entry])

        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: chain, method, params)
        }
        func pass(at now: Date) async throws -> Sora2PendingReconciliationReport {
            try await reconciler(
                runtimeService: RuntimeTestProvider(snapshot: nil),
                proofs: Sora2LiveRuntimeIdentityCache(),
                directory: directory,
                walletNetworkSnapshot: { account.snapshot },
                now: { now }
            ).reconcile()
        }
        func overlay(at now: Date) throws -> [TransactionHistoryItem] {
            TransactionHistoryMergeManager.pendingJournalOverlay(
                address: account.address,
                submissions: try store.all(),
                visibleLocalItems: [],
                remoteHashes: [],
                now: now
            )
        }
        // Six days in: still asked about, still shown as pending, with the
        // block it is in.
        let sixDays = created.addingTimeInterval(6 * 24 * 3_600)
        let early = try await pass(at: sixDays)
        XCTAssertEqual(early.awaitingResult, 1)
        XCTAssertGreaterThan(RPCStubProtocol.hosts().count, 0)
        XCTAssertEqual(try overlay(at: sixDays).first?.status, .pending)
        XCTAssertEqual(try overlay(at: sixDays).first?.blockNumber, 140)

        // Eight days in: nothing is asked of any node, and Activity no
        // longer claims the transaction is pending.
        RPCStubProtocol.resetByHost { _, _, _ in nil }
        let eightDays = created.addingTimeInterval(8 * 24 * 3_600)
        let late = try await pass(at: eightDays)
        XCTAssertEqual(late, Sora2PendingReconciliationReport())
        XCTAssertTrue(RPCStubProtocol.hosts().isEmpty)
        XCTAssertTrue(try overlay(at: eightDays).isEmpty)
        // The witness itself is never deleted by a pass.
        XCTAssertEqual(try store.all(), [entry])
    }

    /// Entries that cannot be resolved never keep others from being looked
    /// at. Before the fix each pass took the 16 oldest entries, so 16 stuck
    /// ones hid every later transaction for good.
    func testUnresolvableEntriesDoNotStarveOtherEntries() async throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        var chain = try mainnetChain(finalizedHeight: 5_000)
        // Blocks 1000 ..< 1064 cannot be read from any node: entries of
        // that era cannot be resolved for now.
        chain.unreadableBlocks = 1_000 ... 1_063
        let stubChain = chain
        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: stubChain, method, params)
        }
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        var entries: [Sora2PendingSubmission] = []
        func entry(_ index: Int, birthBlock: Int, age: TimeInterval) -> Sora2PendingSubmission {
            let hash = String(format: "%064x", 0xabc000 + index)
            let created = base.addingTimeInterval(-age)
            return Sora2PendingSubmission(
                id: UUID(),
                account: account.address,
                extrinsicHash: hash,
                createdAt: created,
                updatedAt: created,
                state: .submissionUnknown,
                recoveryContext: pendingContext(account: account, hash: hash, chain: stubChain, birthBlock: birthBlock)
            )
        }
        // 17 stuck entries older than, and 17 newer than, three ordinary
        // ones whose era (128 ..< 192) ended without them.
        for index in 0 ..< 17 {
            entries.append(entry(index, birthBlock: 1_000, age: 10_000 - Double(index)))
        }
        let ordinary = (0 ..< 3).map { entry(100 + $0, birthBlock: 128, age: 5_000 - Double($0)) }
        entries.append(contentsOf: ordinary)
        for index in 0 ..< 17 {
            entries.append(entry(200 + index, birthBlock: 1_000, age: 1_000 - Double(index)))
        }
        try writeJournal(entries, in: directory)
        let store = try Sora2PendingSubmissionStore(baseURL: directory)

        let rotation = Sora2PendingReconciliationRotation()
        func pass() async throws -> Sora2PendingReconciliationReport {
            try await reconciler(
                runtimeService: RuntimeTestProvider(snapshot: nil),
                proofs: Sora2LiveRuntimeIdentityCache(),
                directory: directory,
                walletNetworkSnapshot: { account.snapshot },
                rotation: rotation,
                now: { base }
            ).reconcile()
        }
        func resolvedOrdinary() throws -> Int {
            let ids = Set(ordinary.map(\.id))
            return try store.all().filter { ids.contains($0.id) && $0.terminalResolution != nil }.count
        }

        // First pass: the 16 newest, all stuck.
        let first = try await pass()
        XCTAssertEqual(first.deferred, Sora2PendingSubmissionReconciler.maximumWitnessesPerPass)
        XCTAssertEqual(first.resolved, 0)
        XCTAssertEqual(first.notExamined, entries.count - 16)
        XCTAssertEqual(try resolvedOrdinary(), 0)
        // Second pass: entries not tried yet come first, so the ordinary
        // ones are reached although 34 stuck entries surround them.
        let second = try await pass()
        XCTAssertEqual(second.resolved, 3)
        XCTAssertEqual(try resolvedOrdinary(), 3)
        XCTAssertTrue(
            try store.all()
                .filter { entry in ordinary.contains { $0.id == entry.id } }
                .allSatisfy { $0.terminalResolution?.kind == .expiredNotIncluded }
        )
        // The stuck entries are untouched and still there to be resolved.
        XCTAssertEqual(try store.all().filter { $0.terminalResolution == nil }.count, 34)
        // The same pass with the old rule (the 16 oldest first) would never
        // have reached them: the 16 oldest are all stuck.
        let oldestSixteen = entries.sorted { $0.updatedAt < $1.updatedAt }.prefix(16)
        XCTAssertTrue(oldestSixteen.allSatisfy { $0.recoveryContext?.eraBirthBlock == 1_000 })
    }

    /// A transaction signed against a block that did not become final can
    /// never be valid. It used to stay unresolved for ever; the scan of its
    /// era now proves, as for any entry, that it is not on the chain.
    func testEntrySignedAgainstANonCanonicalBlockExpires() async throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        let chain = try mainnetChain(finalizedHeight: 400)
        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: chain, method, params)
        }
        let hash = String(repeating: "d5", count: 32)
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let pending = try store.stage(
            account: account.address,
            hash: hash,
            recoveryContext: pendingContext(
                account: account,
                hash: hash,
                chain: chain,
                birthBlock: 128,
                birthBlockHash: String(repeating: "0f", count: 32)
            )
        )
        try store.update(pending, state: .submissionUnknown)

        let report = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory,
            walletNetworkSnapshot: { account.snapshot }
        ).reconcile()
        XCTAssertEqual(report.resolved, 1)
        XCTAssertEqual(try store.all().first?.terminalResolution?.kind, .expiredNotIncluded)
    }

    /// A transaction that is not in a finalized block yet, with its era
    /// still open, stays as it is and asks for another pass soon.
    func testEntryInsideItsEraAsksForAFollowUp() async throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        let chain = try mainnetChain(finalizedHeight: 130)
        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: chain, method, params)
        }
        let hash = String(repeating: "e6", count: 32)
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let pending = try store.stage(
            account: account.address,
            hash: hash,
            recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128)
        )
        try store.update(pending, state: .submitted)
        let report = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory,
            walletNetworkSnapshot: { account.snapshot }
        ).reconcile()
        XCTAssertEqual(report.withinEra, 1)
        XCTAssertTrue(report.needsFollowUp)
        XCTAssertNil(try store.all().first?.terminalResolution)
        // Only the blocks finalized so far were read: 128, 129, 130 and zero.
        XCTAssertEqual(RPCStubProtocol.callCount("chain_getBlock", host: Self.prunedHost), 4)

        // The schedule looks again within seconds, and keeps looking until
        // after the era must be over (64 blocks of six seconds).
        XCTAssertLessThanOrEqual(try XCTUnwrap(Sora2PendingFollowUpSchedule.delay(afterAttempt: 0)), 15)
        XCTAssertGreaterThan(Sora2PendingFollowUpSchedule.delays.reduce(0, +), 2 * 64 * 6)
        XCTAssertNil(Sora2PendingFollowUpSchedule.delay(afterAttempt: Sora2PendingFollowUpSchedule.delays.count))
        let journal = try store.all()
        let created = try XCTUnwrap(journal.first).createdAt
        // A pass that failed as a whole (offline) still asks again while the
        // transaction may be entering the network, and not after.
        XCTAssertTrue(Sora2PendingFollowUpSchedule.needsFollowUp(report: nil, journal: journal, now: created.addingTimeInterval(60)))
        XCTAssertFalse(Sora2PendingFollowUpSchedule.needsFollowUp(report: nil, journal: journal, now: created.addingTimeInterval(2 * 3_600)))
        XCTAssertFalse(Sora2PendingFollowUpSchedule.needsFollowUp(report: Sora2PendingReconciliationReport(), journal: [], now: created))
    }

    /// S-2, first part. A pass used to run only at process start, on return
    /// to the foreground and on account change, so the transaction just
    /// sent was looked at only then. A submission now starts passes of its
    /// own, on the follow-up schedule, until nothing recent is unresolved.
    @MainActor
    func testSubmissionStartsReconciliationPassesOfItsOwn() async throws {
        let account = try pendingAccount()
        let chain = try mainnetChain(finalizedHeight: 130)
        let hash = String(repeating: "b8", count: 32)
        let sent = Sora2PendingSubmission(
            id: UUID(),
            account: account.address,
            extrinsicHash: hash,
            createdAt: Date(),
            updatedAt: Date(),
            state: .submitted,
            recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128)
        )
        let script = RecoveryScript()
        let runtime = Sora2PendingSubmissionRecoveryRuntime(
            makePass: { script.makePass() },
            journal: { script.journal },
            sleep: { script.slept($0) },
            notifyResolved: { script.noteResolved() }
        )
        func settle(passes: Int) async {
            let deadline = Date().addingTimeInterval(10)
            while script.passes < passes, Date() < deadline {
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            // Anything that would still follow has time to show itself.
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        // Nothing runs before wallet storage and the chain are both ready.
        runtime.noteSubmission()
        runtime.markWalletStorageReadyAndResume()
        await settle(passes: 0)
        XCTAssertEqual(script.passes, 0)
        XCTAssertEqual(script.delays, [])

        // Process start: one pass. The journal holds nothing recent, so
        // nothing is scheduled.
        runtime.markChainReadyAndResume()
        await settle(passes: 1)
        XCTAssertEqual(script.passes, 1)
        XCTAssertEqual(script.delays, [])

        // A transaction is handed to the network. Twelve seconds later a
        // pass runs without any start or foreground event; the transaction
        // is not in a finalized block yet, so another follows, which finds
        // it. Then the passes stop.
        var withinEra = Sora2PendingReconciliationReport()
        withinEra.withinEra = 1
        var resolved = Sora2PendingReconciliationReport()
        resolved.resolved = 1
        script.journal = [sent]
        script.enqueue(.success(withinEra))
        script.enqueue(.success(resolved), journalAfterwards: [])
        runtime.noteSubmission()
        await settle(passes: 3)
        XCTAssertEqual(script.passes, 3)
        XCTAssertEqual(script.delays, [12, 20])
        // Open Activity lists are told once, when the status became final.
        XCTAssertEqual(script.resolvedNotices, 1)

        // Offline: every pass fails as a whole. The passes go on while the
        // transaction may still be entering the network, for the length of
        // the schedule, and then stop; nothing is latched.
        script.reset()
        script.journal = [sent]
        script.failEveryPass = true
        runtime.noteSubmission()
        await settle(passes: Sora2PendingFollowUpSchedule.delays.count)
        XCTAssertEqual(script.passes, Sora2PendingFollowUpSchedule.delays.count)
        XCTAssertEqual(script.delays, Sora2PendingFollowUpSchedule.delays)
        XCTAssertEqual(script.resolvedNotices, 0)

        // Back in the foreground the schedule starts again from its first
        // delay, and ends as soon as a pass resolves the transaction.
        script.reset()
        script.journal = [sent]
        script.enqueue(.success(withinEra))
        script.enqueue(.success(resolved), journalAfterwards: [])
        runtime.resumePendingAfterProcessStart()
        await settle(passes: 2)
        XCTAssertEqual(script.passes, 2)
        XCTAssertEqual(script.delays, [12])
        XCTAssertEqual(script.resolvedNotices, 1)

        // While the connection is not ready nothing is scheduled, and a
        // pass that cannot be built marks the chain as not ready.
        script.reset()
        script.chainAvailable = false
        runtime.resumePendingAfterProcessStart()
        runtime.noteSubmission()
        await settle(passes: 0)
        XCTAssertEqual(script.passes, 0)
        XCTAssertEqual(script.delays, [])
    }

    // MARK: - Journal capacity and account removal

    /// The 500-entry cap must never refuse a new transaction because of
    /// stale entries. Before the fix a journal full of entries without a
    /// terminal resolution refused every new send, swap and liquidity action
    /// before transport.
    func testFullJournalOfStaleEntriesStillAcceptsANewTransaction() throws {
        let directory = try temporaryDirectory()
        let now = Date()
        func stale(_ index: Int, age: TimeInterval, state: Sora2PendingSubmissionState = .submissionUnknown) -> Sora2PendingSubmission {
            let created = Date(timeIntervalSince1970: (now.timeIntervalSince1970 - age).rounded(.down))
            return Sora2PendingSubmission(
                id: UUID(),
                account: "sora-account",
                extrinsicHash: String(format: "%064x", 0x500000 + index),
                createdAt: created,
                updatedAt: created,
                state: state
            )
        }
        // 500 entries without a resolution, each two hours old or more.
        let entries = (0 ..< 500).map { stale($0, age: 7_200 + Double(500 - $0)) }
        try writeJournal(entries, in: directory)
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        XCTAssertEqual(try store.all().count, 500)
        XCTAssertTrue(try store.all().allSatisfy { !$0.isPrunable })

        let fresh = try store.stage(account: "sora-account", hash: String(repeating: "aa", count: 32))
        let after = try store.all()
        XCTAssertEqual(after.count, 500)
        XCTAssertTrue(after.contains { $0.id == fresh.id })
        // The oldest stale entry gave its place.
        XCTAssertFalse(after.contains { $0.id == entries[0].id })
        XCTAssertTrue(after.contains { $0.id == entries[1].id })

        // An entry whose transaction may still be entering the network is
        // never the one evicted, and neither is one a feature journal owns.
        let protectedDirectory = try temporaryDirectory()
        var protected = (0 ..< 499).map { stale($0, age: 60) }
        protected.append(stale(499, age: 7_200, state: .stagedBeforeTransport))
        try writeJournal(protected, in: protectedDirectory)
        let protectedStore = try Sora2PendingSubmissionStore(baseURL: protectedDirectory)
        XCTAssertThrowsError(
            try protectedStore.stage(account: "sora-account", hash: String(repeating: "bb", count: 32))
        ) { error in
            guard case ExtrinsicServiceError.pendingSubmissionCapacityExceeded = error else {
                return XCTFail("\(error)")
            }
        }
        XCTAssertEqual(try protectedStore.all().count, 500)

        // A resolved entry goes before a stale one.
        let values = [stale(1, age: 9_000), stale(2, age: 8_000, state: .submitted), stale(3, age: 60)]
        XCTAssertEqual(Sora2PendingSubmissionStore.evictionIndex(in: values, now: now), 1)
        XCTAssertEqual(Sora2PendingSubmissionStore.evictionIndex(in: [values[0], values[2]], now: now), 0)
        XCTAssertNil(Sora2PendingSubmissionStore.evictionIndex(in: [values[2]], now: now))
    }

    /// Account removal waits only while a transaction of that account may
    /// still be entering the network. Before the fix one entry that could
    /// not be resolved blocked removal for good.
    func testAccountRemovalIsNotBlockedForEverByAnUnresolvedEntry() throws {
        let created = Date(timeIntervalSince1970: 1_800_000_000)
        let entry = Sora2PendingSubmission(
            id: UUID(),
            account: "sora-account",
            extrinsicHash: String(repeating: "ef", count: 32),
            createdAt: created,
            updatedAt: created,
            state: .submissionUnknown
        )
        func validate(now: Date) throws {
            try WalletPendingDeletionPolicy.validate(
                nexusTransactions: [],
                polkamarktTransactions: [],
                sora2Submissions: [entry],
                walletId: "wallet",
                soraAddress: "sora-account",
                now: now
            )
        }
        // A minute after sending: wait.
        XCTAssertThrowsError(try validate(now: created.addingTimeInterval(60))) { error in
            XCTAssertEqual(error as? WalletPendingDeletionPreflightError, .unresolvedSora2Submission)
        }
        XCTAssertThrowsError(try validate(now: created.addingTimeInterval(59 * 60)))
        // After the window: the transaction can no longer enter the chain.
        XCTAssertNoThrow(try validate(now: created.addingTimeInterval(61 * 60)))
        XCTAssertNoThrow(try validate(now: created.addingTimeInterval(30 * 24 * 3_600)))
        // A device clock set back does not extend the wait.
        XCTAssertNoThrow(try validate(now: created.addingTimeInterval(-2 * 3_600)))

        // The message says what to do and for how long, in both languages.
        for error in [
            WalletPendingDeletionPreflightError.unresolvedSora2Submission,
            .sora2JournalUnavailable
        ] {
            let text = try XCTUnwrap(error.errorDescription)
            XCTAssertFalse(text.isEmpty)
        }
        for key in [
            "A transaction from this account was sent a moment ago and is still being confirmed. This usually takes less than a minute and never more than an hour. Please try again shortly. Nothing was removed.",
            "The app could not read its list of recently sent transactions, so it can't tell whether one from this account is still being confirmed. Please try again in an hour. Nothing was removed."
        ] {
            XCTAssertEqual(WalletUX.text(key, language: "en"), key)
            XCTAssertNotEqual(WalletUX.text(key, language: "ja"), key)
        }

        // A journal that cannot be read blocks removal only while it could
        // hold such an entry: it was written within the window.
        let directory = try temporaryDirectory()
        XCTAssertTrue(
            Sora2PendingSubmissionStore.journalPredatesSubmissionWindow(now: Date(), baseURL: directory)
        )
        let folder = directory
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("sora2-signed-v1.json")
        try Data("not a journal".utf8).write(to: file)
        XCTAssertThrowsError(try Sora2PendingSubmissionStore(baseURL: directory).all())
        XCTAssertFalse(
            Sora2PendingSubmissionStore.journalPredatesSubmissionWindow(now: Date(), baseURL: directory)
        )
        XCTAssertTrue(
            Sora2PendingSubmissionStore.journalPredatesSubmissionWindow(
                now: Date().addingTimeInterval(2 * 3_600),
                baseURL: directory
            )
        )
    }

    /// The inclusion witness is additive: a journal an earlier build wrote
    /// reads unchanged, and a witness that does not fit its entry is dropped
    /// instead of making the journal unreadable.
    func testInclusionWitnessIsAdditiveAndNeverBreaksTheJournal() throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        let chain = try mainnetChain(finalizedHeight: 5_000)
        let hash = String(repeating: "a7", count: 32)
        let created = Date(timeIntervalSince1970: 1_800_000_000)
        let context = pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128)
        let plain = Sora2PendingSubmission(
            id: UUID(),
            account: account.address,
            extrinsicHash: hash,
            createdAt: created,
            updatedAt: created,
            state: .submitted,
            recoveryContext: context
        )
        try writeJournal([plain], in: directory)
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        XCTAssertEqual(try store.all(), [plain])
        XCTAssertNil(try store.all().first?.finalizedInclusion)

        // A witness outside the entry's era is ignored.
        var broken = plain
        broken.finalizedInclusion = Sora2PendingFinalizedInclusion(
            schemaVersion: Sora2PendingFinalizedInclusion.currentSchemaVersion,
            blockNumber: 9_999,
            blockHash: chain.blockHash(9_999),
            extrinsicIndex: 0,
            finalizedHeight: 10_000
        )
        try writeJournal([broken], in: directory)
        XCTAssertEqual(try store.all(), [plain])

        // Recording is refused for a block outside the era, accepted for
        // one inside it, and a second, different record is refused.
        XCTAssertThrowsError(
            try store.recordFinalizedInclusion(plain, blockNumber: 192, blockHash: chain.blockHash(192), extrinsicIndex: 0, finalizedHeight: 300)
        )
        try store.recordFinalizedInclusion(plain, blockNumber: 150, blockHash: chain.blockHash(150), extrinsicIndex: 3, finalizedHeight: 300)
        XCTAssertEqual(try store.all().first?.finalizedInclusion?.blockNumber, 150)
        XCTAssertThrowsError(
            try store.recordFinalizedInclusion(plain, blockNumber: 151, blockHash: chain.blockHash(151), extrinsicIndex: 0, finalizedHeight: 300)
        )
        // The result must be for the recorded block.
        XCTAssertThrowsError(
            try store.resolveAuthoritatively(
                plain,
                proof: .finalizedInclusion(blockNumber: 151, blockHash: chain.blockHash(151), succeeded: true, finalizedHeight: 300)
            )
        )
        XCTAssertThrowsError(
            try store.resolveAuthoritatively(
                plain,
                proof: .mortalEraAbsence(scannedBirthBlock: 128, scannedDeathBlockExclusive: 192, finalizedHeight: 300)
            )
        )
        try store.resolveAuthoritatively(
            plain,
            proof: .finalizedInclusion(blockNumber: 150, blockHash: chain.blockHash(150), succeeded: true, finalizedHeight: 300)
        )
        XCTAssertEqual(try store.all().first?.terminalResolution?.kind, .finalizedSuccess)
    }

    // MARK: - Signed extensions (S-3, LIVE-12)

    private typealias SignedExtension = RuntimeMetadataV14.ExtrinsicMetadata.SignedExtension

    /// Runtime 133 metadata with other signed extensions (and, when a test
    /// needs them, extra types), encoded and loaded exactly like metadata a
    /// node serves.
    private func factory(
        editingSignedExtensions edit: (inout [SignedExtension], [SchemaItem]) throws -> [SchemaItem]
    ) throws -> RuntimeCoderFactory {
        let original = try fixtureMetadata()
        let base = try RuntimeMetadata(scaleDecoder: ScaleDecoder(data: original))
        let types = try XCTUnwrap(base.schema).types
        let extrinsic = try XCTUnwrap(base.extrinsic as? RuntimeMetadataV14.ExtrinsicMetadata)
        let modules = base.modules.compactMap { $0 as? RuntimeMetadataV14.ModuleMetadata }
        XCTAssertEqual(modules.count, base.modules.count)

        // The runtime type id that follows the extrinsic metadata is the
        // rest of the original bytes.
        let extrinsicEncoder = ScaleEncoder()
        try extrinsic.encode(scaleEncoder: extrinsicEncoder)
        let extrinsicBytes = extrinsicEncoder.encode()
        let position = try XCTUnwrap(original.range(of: extrinsicBytes, options: .backwards))
        let tail = original[position.upperBound...]

        var extensions = extrinsic.signedExtensions
        let added = try edit(&extensions, types)
        let encoder = ScaleEncoder()
        try base.metaReserved.encode(scaleEncoder: encoder)
        try base.version.encode(scaleEncoder: encoder)
        try Schema(types: types + added).encode(scaleEncoder: encoder)
        try modules.encode(scaleEncoder: encoder)
        try RuntimeMetadataV14.ExtrinsicMetadata(
            type: try XCTUnwrap(extrinsic.type),
            version: extrinsic.version,
            signedExtensions: extensions
        ).encode(scaleEncoder: encoder)
        encoder.appendRaw(data: Data(tail))

        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(
            chainId: PIIndexerClient.soraMainnetGenesis,
            runtimeMetadataItem: try item(metadata: encoder.encode()),
            ownTypes: try chainTypes(),
            dataHasher: .twox256
        )
        return RuntimeCoderFactory(
            catalog: snapshot.typeRegistryCatalog,
            specVersion: 133,
            txVersion: 131,
            metadata: snapshot.metadata
        )
    }

    private func typeId(in types: [SchemaItem], where matches: (TypeMetadata) -> Bool) throws -> BigUInt {
        try XCTUnwrap(types.first(where: { matches($0.type) })?.id)
    }

    private func unitTypeId(in types: [SchemaItem]) throws -> BigUInt {
        try typeId(in: types) {
            if case let .tuple(items) = $0.def { return items.isEmpty }
            return false
        }
    }

    private func u32TypeId(in types: [SchemaItem]) throws -> BigUInt {
        try typeId(in: types) {
            if case .primitive(.u32) = $0.def { return true }
            return false
        }
    }

    private func hashTypeId(in types: [SchemaItem]) throws -> BigUInt {
        try typeId(in: types) { $0.path == ["primitive_types", "H256"] }
    }

    /// One type of the registry, written in the metadata's own encoding.
    private func schemaItem(
        id: BigUInt,
        path: [String],
        definition: (ScaleEncoder) throws -> Void
    ) throws -> SchemaItem {
        let encoder = ScaleEncoder()
        try id.encode(scaleEncoder: encoder)
        try path.encode(scaleEncoder: encoder)
        try [String]().encode(scaleEncoder: encoder) // no type parameters
        try definition(encoder)
        try [String]().encode(scaleEncoder: encoder) // no docs
        return try SchemaItem(scaleDecoder: ScaleDecoder(data: encoder.encode()))
    }

    /// `CheckMetadataHash { mode: Mode }` with `enum Mode { Disabled, Enabled }`,
    /// as `frame-metadata-hash-extension` declares them.
    private func metadataHashTypes(after types: [SchemaItem]) throws -> (extensionType: BigUInt, items: [SchemaItem]) {
        let next = (types.map(\.id).max() ?? 0) + 1
        let modeId = next
        let extensionId = next + 1
        let mode = try schemaItem(id: modeId, path: ["frame_metadata_hash_extension", "Mode"]) { encoder in
            try UInt8(1).encode(scaleEncoder: encoder) // variant
            try BigUInt(2).encode(scaleEncoder: encoder)
            for (index, name) in ["Disabled", "Enabled"].enumerated() {
                try name.encode(scaleEncoder: encoder)
                try [String]().encode(scaleEncoder: encoder) // no fields
                try UInt8(index).encode(scaleEncoder: encoder)
                try [String]().encode(scaleEncoder: encoder)
            }
        }
        let check = try schemaItem(
            id: extensionId,
            path: ["frame_metadata_hash_extension", "CheckMetadataHash"]
        ) { encoder in
            try UInt8(0).encode(scaleEncoder: encoder) // composite
            try BigUInt(1).encode(scaleEncoder: encoder)
            try ScaleOption<String>.some(value: "mode").encode(scaleEncoder: encoder)
            try modeId.encode(scaleEncoder: encoder)
            try ScaleOption<String>.none.encode(scaleEncoder: encoder)
            try [String]().encode(scaleEncoder: encoder)
        }
        return (extensionId, [mode, check])
    }

    private func assembleTransfer(
        with factory: RuntimeCoderFactoryProtocol
    ) throws -> (extrinsic: Data, payload: Data) {
        let accountId = Data(repeating: 0x42, count: 32)
        var payloads: [Data] = []
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
                payloads.append(payload)
                return Data(repeating: 0x01, count: 64)
            }
        )
        return (data, try XCTUnwrap(payloads.first))
    }

    private func liveIdentity(of factory: RuntimeCoderFactoryProtocol) throws -> Sora2LiveRuntime {
        live(sha: try PolkamarktRuntimeContract.signingMetadataSHA256(for: factory))
    }

    /// Runtime 133: every extension that carries bytes is written, and the
    /// extrinsic is byte for byte the vector both mainnet nodes priced on
    /// 10 October 2026 (audit `ios-signing.md` 3.4).
    func testRuntime133SignedExtensionsAreAllWrittenAndTheTransferMatchesTheReferenceVector() throws {
        let factory = try factory()
        XCTAssertNoThrow(try Sora2SignedExtensionSupport.validate(metadata: factory.metadata))
        XCTAssertNoThrow(try Sora2LiveRuntimeValidator.validate(factory: factory, live: live()))
        // The check names an extension by the rule the encoder uses: SORA's
        // own payment extension is the one that carries the tip.
        XCTAssertEqual(
            SoraPassport.ExtrinsicCheck.matching(typeName: "xor_fee::extension::ChargeTransactionPayment"),
            .txPayment
        )
        XCTAssertEqual(
            SoraPassport.ExtrinsicCheck.matching(typeName: "frame_system::extensions::check_nonce::CheckNonce"),
            .nonce
        )
        XCTAssertEqual(SoraPassport.ExtrinsicCheck.matching(typeName: "some_pallet::CheckNonce<T>"), .nonce)
        XCTAssertNil(
            SoraPassport.ExtrinsicCheck.matching(
                typeName: "frame_system::extensions::check_non_zero_sender::CheckNonZeroSender"
            )
        )

        let (extrinsic, payload) = try assembleTransfer(with: factory)
        let account = String(repeating: "42", count: 32)
        let call = "1501" + "02" + String(repeating: "00", count: 31) + account + "01" + String(repeating: "00", count: 15)
        XCTAssertEqual(
            extrinsic.toHex(includePrefix: false),
            "e10284" + account + "01" + String(repeating: "01", count: 64) + "55001c00" + call
        )
        // call, extra, spec 133, transaction version 131, genesis, era block.
        XCTAssertEqual(
            payload.toHex(includePrefix: false),
            call + "55001c00" + "85000000" + "83000000" +
                String(PIIndexerClient.soraMainnetGenesis.dropFirst(2)) +
                String(repeating: "ee", count: 32)
        )
    }

    /// S-3. A runtime upgrade adds a signed extension that carries data the
    /// encoder does not write. The live-runtime check used to pass, and the
    /// app signed and submitted transactions every node rejected. Now
    /// nothing is signed, and the message says to update the app.
    func testUnknownSignedExtensionWithDataRefusesToSign() throws {
        // Four bytes in the signed extra.
        let withExtra = try factory { extensions, types in
            extensions.append(
                SignedExtension(
                    identifier: "CheckSomethingNew",
                    type: try u32TypeId(in: types),
                    additionalSigned: try unitTypeId(in: types)
                )
            )
            return []
        }
        // Thirty-two bytes in the additional signed data only.
        let withAdditional = try factory { extensions, types in
            extensions.insert(
                SignedExtension(
                    identifier: "CheckSomethingElse",
                    type: try unitTypeId(in: types),
                    additionalSigned: try hashTypeId(in: types)
                ),
                at: 0
            )
            return []
        }
        for (factory, identifier) in [(withExtra, "CheckSomethingNew"), (withAdditional, "CheckSomethingElse")] {
            XCTAssertThrowsError(try Sora2SignedExtensionSupport.validate(metadata: factory.metadata)) { error in
                XCTAssertEqual(
                    error as? Sora2SignedExtensionSupport.Unsupported,
                    Sora2SignedExtensionSupport.Unsupported(identifier: identifier)
                )
            }
            // The metadata is the node's own (the hash matches), and still
            // nothing is signed.
            XCTAssertThrowsError(
                try Sora2LiveRuntimeValidator.validate(factory: factory, live: try liveIdentity(of: factory))
            ) { error in
                guard
                    case let ExtrinsicServiceError.unsupportedSignedExtension(named) = error
                else {
                    return XCTFail("\(error)")
                }
                XCTAssertEqual(named, identifier)
                XCTAssertEqual(Sora2SigningNotice.kind(for: error, nodeURL: nil), .appUpdateRequired)
            }
        }

        // A known extension that stops carrying its data is refused too:
        // the encoder would write bytes the runtime does not read.
        let nonceWithoutData = try factory { extensions, types in
            let index = try XCTUnwrap(extensions.firstIndex { $0.identifier == "CheckNonce" })
            // `CheckNonce` as a struct without fields.
            let empty = try schemaItem(
                id: (types.map(\.id).max() ?? 0) + 1,
                path: ["frame_system", "extensions", "check_nonce", "CheckNonce"]
            ) { encoder in
                try UInt8(0).encode(scaleEncoder: encoder) // composite
                try BigUInt(0).encode(scaleEncoder: encoder) // no fields
            }
            extensions[index] = SignedExtension(
                identifier: "CheckNonce",
                type: empty.id,
                additionalSigned: extensions[index].additionalSigned
            )
            return [empty]
        }
        XCTAssertThrowsError(try Sora2SignedExtensionSupport.validate(metadata: nonceWithoutData.metadata)) { error in
            XCTAssertEqual(
                error as? Sora2SignedExtensionSupport.Unsupported,
                Sora2SignedExtensionSupport.Unsupported(identifier: "CheckNonce")
            )
        }

        // The message is calm, says nothing was signed, and is translated.
        let key = "The SORA network was upgraded and this version of the app can't send transactions on it yet. Nothing was signed and your funds are safe. Please update the app."
        let error = ExtrinsicServiceError.unsupportedSignedExtension(identifier: "CheckSomethingNew")
        XCTAssertEqual(ExtrinsicServiceError.runtimeUserMessage(for: error), WalletUX.text(key))
        XCTAssertEqual(error.errorDescription, WalletUX.text(key))
        XCTAssertEqual(WalletUX.text(key, language: "en"), key)
        XCTAssertNotEqual(WalletUX.text(key, language: "ja"), key)
        XCTAssertEqual(Sora2SigningNotice.message(for: .appUpdateRequired), WalletUX.text(key))
        // Wrapped by the transport layer, the message is the same.
        XCTAssertEqual(
            ExtrinsicServiceError.runtimeUserMessage(
                for: PreparedExtrinsicTransportError.failedBeforeTransport(error)
            ),
            WalletUX.text(key)
        )
    }

    /// An extension without data needs no bytes, known or not
    /// (`CheckNonZeroSender` is in every current Substrate runtime): the
    /// transaction is unchanged and signing goes on.
    func testUnknownSignedExtensionWithoutDataChangesNothing() throws {
        let baseline = try assembleTransfer(with: try factory())
        let withEmptyExtension = try factory { extensions, types in
            let unit = try unitTypeId(in: types)
            extensions.insert(
                SignedExtension(identifier: "CheckNonZeroSender", type: unit, additionalSigned: unit),
                at: 0
            )
            return []
        }
        XCTAssertNoThrow(try Sora2SignedExtensionSupport.validate(metadata: withEmptyExtension.metadata))
        XCTAssertNoThrow(
            try Sora2LiveRuntimeValidator.validate(
                factory: withEmptyExtension,
                live: try liveIdentity(of: withEmptyExtension)
            )
        )
        let patched = try assembleTransfer(with: withEmptyExtension)
        XCTAssertEqual(patched.extrinsic, baseline.extrinsic)
        XCTAssertEqual(patched.payload, baseline.payload)
    }

    /// `CheckMetadataHash` is written in disabled mode: one mode byte (0)
    /// after the tip, and an absent hash (0) at the end of the signed
    /// payload. Everything else is byte for byte the runtime 133 extrinsic.
    func testCheckMetadataHashIsWrittenInDisabledMode() throws {
        let baseline = try assembleTransfer(with: try factory())
        let withMetadataHash = try factory { extensions, types in
            let added = try metadataHashTypes(after: types)
            extensions.append(
                SignedExtension(
                    identifier: "CheckMetadataHash",
                    type: added.extensionType,
                    // Option<[u8; 32]> on chain; any type with bytes does
                    // here, the app writes "none".
                    additionalSigned: try hashTypeId(in: types)
                )
            )
            return added.items
        }
        XCTAssertNoThrow(try Sora2SignedExtensionSupport.validate(metadata: withMetadataHash.metadata))
        XCTAssertNoThrow(
            try Sora2LiveRuntimeValidator.validate(
                factory: withMetadataHash,
                live: try liveIdentity(of: withMetadataHash)
            )
        )
        let patched = try assembleTransfer(with: withMetadataHash)
        let account = String(repeating: "42", count: 32)
        let call = "1501" + "02" + String(repeating: "00", count: 31) + account + "01" + String(repeating: "00", count: 15)
        XCTAssertEqual(
            patched.extrinsic.toHex(includePrefix: false),
            // One byte longer (185), with the mode byte after era, nonce, tip.
            "e50284" + account + "01" + String(repeating: "01", count: 64) + "55001c00" + "00" + call
        )
        XCTAssertEqual(
            patched.payload.toHex(includePrefix: false),
            call + "55001c00" + "00" + String(baseline.payload.toHex(includePrefix: false).dropFirst(call.count + 8)) + "00"
        )
        XCTAssertEqual(patched.payload.count, baseline.payload.count + 2)
    }

    // MARK: - Balance unavailable, never zero

    /// A storage value the balance model does not recognise is "balance
    /// unavailable". Before the fix it read as zero: this is how every XOR
    /// balance became 0 when runtime 124 renamed the balances fields.
    func testUnrecognisedBalanceLayoutIsUnavailableNeverZero() throws {
        let factory = try factory()
        let xor = BigUInt(10).power(18)
        // `System.Account` as the node's metadata decodes it, through the
        // operation the balance read uses.
        let operation = StorageFallbackDecodingListOperation<JSON>(
            path: .account,
            dataList: [
                systemAccountBytes(nonce: 1, free: 2 * xor, reserved: xor, frozen: 3 * xor / 2, flags: BigUInt(1) << 127),
                nil
            ]
        )
        operation.codingFactory = factory
        operation.start()
        let decoded = try XCTUnwrap(operation.result).get()
        let account = try XCTUnwrap(decoded[0])

        guard case let .amounts(known) = WalletBalanceReading.xor(account: account) else {
            return XCTFail("Runtime 133 balances must be read")
        }
        XCTAssertEqual(known.free, 2 * xor)
        XCTAssertEqual(known.available, 3 * xor / 2)
        // An account the chain has nothing for holds nothing: a real zero.
        XCTAssertEqual(
            WalletBalanceReading.xor(account: decoded[1]),
            .amounts(AccountData(free: 0, reserved: 0, miscFrozen: 0, feeFrozen: 0))
        )
        XCTAssertEqual(
            WalletBalanceReading.xor(account: nil),
            .amounts(AccountData(free: 0, reserved: 0, miscFrozen: 0, feeFrozen: 0))
        )

        // The next upgrade renames a field of the same value.
        func renaming(_ key: String, to newKey: String, in json: JSON) -> JSON {
            guard case let .dictionaryValue(fields) = json else { return json }
            var renamed: [String: JSON] = [:]
            for (name, value) in fields {
                renamed[name == key ? newKey : name] = renaming(key, to: newKey, in: value)
            }
            return .dictionaryValue(renamed)
        }
        XCTAssertEqual(WalletBalanceReading.xor(account: renaming("free", to: "liquid", in: account)), .unavailable)
        XCTAssertEqual(WalletBalanceReading.xor(account: renaming("frozen", to: "held", in: account)), .unavailable)
        XCTAssertEqual(WalletBalanceReading.xor(account: renaming("data", to: "balances", in: account)), .unavailable)

        // Tokens: three u128 values, or nothing stored.
        func balance(_ value: UInt8) -> [UInt8] { [value] + [UInt8](repeating: 0, count: 15) }
        let token = Data(balance(9) + balance(2) + balance(3))
        guard case let .amounts(tokens) = WalletBalanceReading.token(
            storage: .success(OrmlAccountStorage(hex: token.toHex(includePrefix: true)))
        ) else {
            return XCTFail("A token account must be read")
        }
        XCTAssertEqual(tokens.free, 9)
        XCTAssertEqual(
            WalletBalanceReading.token(storage: .success(OrmlAccountStorage(hex: nil))),
            .amounts(AccountData(free: 0, reserved: 0, miscFrozen: 0, feeFrozen: 0))
        )
        // Another length is another layout; a failed read is not a zero.
        for other in [token.dropLast(), token + Data([0x01]), Data()] {
            XCTAssertEqual(
                WalletBalanceReading.token(
                    storage: .success(OrmlAccountStorage(hex: Data(other).toHex(includePrefix: true)))
                ),
                .unavailable
            )
        }
        XCTAssertEqual(
            WalletBalanceReading.token(storage: .failure(URLError(.timedOut))),
            .unavailable
        )
        XCTAssertEqual(
            try JSONDecoder().decode([OrmlAccountStorage].self, from: Data(#"[null,"0x00"]"#.utf8)).map(\.hex),
            [nil, "0x00"]
        )

        // An unavailable balance never reaches a consumer as a number: the
        // provider keeps it apart from the balances that were read.
        let read = BalanceData(identifier: "0x0200050000000000000000000000000000000000000000000000000000000000", balance: AmountDecimal(value: 5))
        let marked = BalanceData.unavailable(identifier: Self.xorAssetId)
        XCTAssertTrue(marked.isUnavailable)
        XCTAssertFalse(read.isUnavailable)
        let split = AssetProvider.split([marked, read])
        XCTAssertEqual(split.balances, [read])
        XCTAssertEqual(split.unavailable, [Self.xorAssetId])
        // The mark survives the provider's cache.
        let cached = try JSONDecoder().decode([BalanceData].self, from: JSONEncoder().encode([marked, read]))
        XCTAssertEqual(AssetProvider.split(cached).unavailable, [Self.xorAssetId])

        XCTAssertEqual(WalletUX.text("Balance unavailable", language: "en"), "Balance unavailable")
        XCTAssertNotEqual(WalletUX.text("Balance unavailable", language: "ja"), "Balance unavailable")
        XCTAssertEqual(WalletUX.balanceUnavailableText, WalletUX.text("Balance unavailable"))
    }

    /// The wallet list through its production service. An asset whose
    /// balance could not be read keeps its row, which says "Balance
    /// unavailable" and shows no amount and no value, and the total says it
    /// leaves that balance out. Before the fix the row read "0 XOR".
    func testWalletListShowsBalanceUnavailableInsteadOfZero() async throws {
        let val = "0x0200040000000000000000000000000000000000000000000000000000000000"
        let assets = [
            AssetInfo(id: Self.xorAssetId, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
            AssetInfo(id: val, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "SORA Validator Token", visible: true),
        ]
        let manager = BalanceListAssetManager(assets: assets)
        // What the real provider holds after a read in which XOR was not
        // understood and VAL was.
        let split = AssetProvider.split([
            BalanceData.unavailable(identifier: Self.xorAssetId),
            BalanceData(identifier: val, balance: AmountDecimal(value: 5)),
        ])
        let provider = BalanceListAssetProvider(balances: split.balances, unavailable: split.unavailable)
        let prices = BalanceListPrices()
        let service = AssetsItemService(
            marketCapService: prices,
            fiatService: nil,
            assetViewModelsFactory: AssetViewModelFactory(walletAssets: assets, assetManager: manager, fiatService: nil),
            assetManager: manager,
            assetProvider: provider,
            priceInfoService: prices
        )
        service.setup()
        // The first rows are drawn at once, before any price.
        XCTAssertEqual(service.assetViewModels.map(\.identifier), [Self.xorAssetId, val])
        for _ in 0 ..< 400 where service.priceNoteText.isEmpty {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(service.assetViewModels.map(\.identifier), [Self.xorAssetId, val])
        let xorRow = try XCTUnwrap(service.assetViewModels.first)
        XCTAssertEqual(xorRow.subtitle, WalletUX.balanceUnavailableText)
        XCTAssertFalse(xorRow.subtitle.contains("0"))
        XCTAssertEqual(xorRow.fiatText, "")
        XCTAssertTrue(xorRow.priceLoadFinished)
        let valRow = try XCTUnwrap(service.assetViewModels.last)
        XCTAssertTrue(valRow.subtitle.contains("5"))
        XCTAssertTrue(valRow.subtitle.contains("VAL"))
        let noteKey = "This total does not include balances that could not be read"
        XCTAssertEqual(service.priceNoteText, WalletUX.text(noteKey))
        XCTAssertEqual(WalletUX.text(noteKey, language: "en"), noteKey)
        XCTAssertNotEqual(WalletUX.text(noteKey, language: "ja"), noteKey)

        // Once the balance is read again the row and the note are ordinary.
        provider.set(
            balances: [
                BalanceData(identifier: Self.xorAssetId, balance: AmountDecimal(value: 2)),
                BalanceData(identifier: val, balance: AmountDecimal(value: 5)),
            ],
            unavailable: []
        )
        service.setup()
        for _ in 0 ..< 400 where !service.priceNoteText.isEmpty {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(service.priceNoteText, "")
        XCTAssertNotEqual(service.assetViewModels.first?.subtitle, WalletUX.balanceUnavailableText)
        XCTAssertEqual(service.assetViewModels.count, 2)
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
    /// What a stub node answers to one request.
    enum Answer {
        /// A JSON-RPC result (JSON text).
        case result(String)
        /// A JSON-RPC error object.
        case error(code: Int, message: String)
        /// An HTTP status without a JSON-RPC body.
        case http(Int)

        /// What a node that prunes state answers for a block it no longer
        /// holds the state of (as `ws.mof.sora.org` does after 256 blocks).
        static func stateDiscarded(_ blockHash: String) -> Answer {
            .error(
                code: 4003,
                message: "Client error: Api called for an unknown Block: State already discarded for \(blockHash)"
            )
        }
    }

    private static let lock = NSLock()
    private static var responder: ((String, [Any]) -> String?)?
    private static var hostResponder: ((String, String, [Any]) -> Answer?)?
    private static var recorded: [(host: String, method: String, params: [Any])] = []

    static func reset(_ responder: @escaping (String, [Any]) -> String?) {
        lock.lock()
        self.responder = responder
        hostResponder = nil
        recorded = []
        lock.unlock()
    }

    /// Answers by host, so one test can have a pruning node and an archive.
    static func resetByHost(_ responder: @escaping (String, String, [Any]) -> Answer?) {
        lock.lock()
        self.responder = nil
        hostResponder = responder
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

    static func callCount(_ method: String, host: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return recorded.filter { $0.method == method && $0.host == host }.count
    }

    static func hosts() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(recorded.map(\.host))
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
        let host = request.url?.host ?? ""
        Self.lock.lock()
        Self.recorded.append((host, method, params))
        let answer: Answer?
        if let hostResponder = Self.hostResponder {
            answer = hostResponder(host, method, params)
        } else {
            answer = Self.responder?(method, params).map { .result($0) }
        }
        Self.lock.unlock()
        var statusCode = 200
        let text: String
        switch answer {
        case let .result(result):
            text = #"{"jsonrpc":"2.0","id":\#(identifier),"result":\#(result)}"#
        case let .error(code, message):
            text = #"{"jsonrpc":"2.0","id":\#(identifier),"error":{"code":\#(code),"message":"\#(message)"}}"#
        case let .http(status):
            statusCode = status
            text = ""
        case .none:
            text = #"{"jsonrpc":"2.0","id":\#(identifier),"error":{"code":-32601,"message":"Method not found"}}"#
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": statusCode == 200 ? "application/json" : "text/html"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Recovery schedule test doubles

/// What the recovery runtime sees in the scheduling test: the reports its
/// passes return, the journal, and the delays it asked to sleep for.
private final class RecoveryScript: @unchecked Sendable {
    private let lock = NSLock()
    private var queued: [(Result<Sora2PendingReconciliationReport, Error>, [Sora2PendingSubmission]?)] = []
    private var passCount = 0
    private var sleptFor: [TimeInterval] = []
    private var notices = 0
    private var entries: [Sora2PendingSubmission] = []
    private var failing = false
    private var available = true

    var passes: Int { locked { passCount } }
    var delays: [TimeInterval] { locked { sleptFor } }
    var resolvedNotices: Int { locked { notices } }
    var journal: [Sora2PendingSubmission] {
        get { locked { entries } }
        set { locked { entries = newValue } }
    }
    var failEveryPass: Bool {
        get { locked { failing } }
        set { locked { failing = newValue } }
    }
    var chainAvailable: Bool {
        get { locked { available } }
        set { locked { available = newValue } }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func enqueue(
        _ result: Result<Sora2PendingReconciliationReport, Error>,
        journalAfterwards: [Sora2PendingSubmission]? = nil
    ) {
        locked { queued.append((result, journalAfterwards)) }
    }

    func reset() {
        locked {
            queued = []
            passCount = 0
            sleptFor = []
            notices = 0
            entries = []
            failing = false
            available = true
        }
    }

    func makePass() -> Sora2PendingSubmissionRecoveryRuntime.Pass? {
        guard chainAvailable else {
            return nil
        }
        return { [self] in
            let result: Result<Sora2PendingReconciliationReport, Error> = locked {
                passCount += 1
                if failing {
                    return .failure(URLError(.notConnectedToInternet))
                }
                guard !queued.isEmpty else {
                    return .success(Sora2PendingReconciliationReport())
                }
                let next = queued.removeFirst()
                if let journal = next.1 {
                    entries = journal
                }
                return next.0
            }
            return try result.get()
        }
    }

    func slept(_ delay: TimeInterval) {
        locked { sleptFor.append(delay) }
    }

    func noteResolved() {
        locked { notices += 1 }
    }
}

private final class BalanceListAssetManager: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []

    let assets: [AssetInfo]

    init(assets: [AssetInfo]) {
        self.assets = assets
    }

    func assetInfo(for identifier: String) -> AssetInfo? {
        assets.first { $0.assetId == identifier }
    }

    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_: [AssetInfo]) {}
    func saveAssetList(_: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible _: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(assets.count) }
    func setup(for _: SelectedWalletSettings) {}
}

/// What `AssetProvider` hands to the wallet list: the balances that were
/// read, and apart from them the assets whose balance could not be read.
private final class BalanceListAssetProvider: AssetProviderProtocol {
    private let lock = NSLock()
    private var balances: [BalanceData]
    private var unavailable: Set<String>

    init(balances: [BalanceData], unavailable: Set<String>) {
        self.balances = balances
        self.unavailable = unavailable
    }

    func set(balances: [BalanceData], unavailable: Set<String>) {
        lock.lock()
        self.balances = balances
        self.unavailable = unavailable
        lock.unlock()
    }

    func getBalances(with assetIds: [String]) -> [BalanceData] {
        lock.lock()
        defer { lock.unlock() }
        return assetIds.compactMap { id in balances.first { $0.identifier == id } }
    }

    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return unavailable.intersection(assetIds)
    }

    func add(observer _: AssetProviderObserverProtocol) {}
    func remove(observer _: AssetProviderObserverProtocol) {}
}

/// No prices and no market data: the wallet list is about balances here.
private final class BalanceListPrices: PriceInfoServiceProtocol, MarketCapServiceProtocol {
    func getPriceInfo(for _: [String]) async -> PriceInfo {
        PriceInfo(fiatData: [], marketCapInfo: [])
    }

    func getMarketCap(for _: [String]) async -> Set<MarketCapInfo> { [] }
}
