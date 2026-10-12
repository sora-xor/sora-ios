// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SoraUIKit
import SSFModels
import SSFUtils
import UIKit
import XCTest
// Only the two indexer row types: the module also declares an `Error` that
// would hide Swift's in this file.
import class sorawallet.TxHistoryItem
import class sorawallet.TxHistoryItemParam
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
        // Hours later an entry the pass could not even start on is still
        // waiting: the next passes of the schedule ask again. (Before,
        // nothing was scheduled once the first hour was over.)
        XCTAssertTrue(Sora2PendingFollowUpSchedule.needsFollowUp(report: nil, journal: journal, now: created.addingTimeInterval(2 * 3_600)))
        // After a week it waits for the next start or foreground instead.
        XCTAssertFalse(Sora2PendingFollowUpSchedule.needsFollowUp(report: nil, journal: journal, now: created.addingTimeInterval(8 * 24 * 3_600)))
        // A pass that examined it and found nothing to wait for (its
        // report says so) ends the asking once the first hour is over.
        XCTAssertFalse(Sora2PendingFollowUpSchedule.needsFollowUp(report: Sora2PendingReconciliationReport(), journal: journal, now: created.addingTimeInterval(2 * 3_600)))
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
        // A request that got no answer is told apart from an answer that
        // was not understood: nothing new is known about that balance.
        XCTAssertEqual(
            WalletBalanceReading.token(storage: .failure(URLError(.timedOut))),
            .notRead
        )
        XCTAssertEqual(
            WalletBalanceReading.token(
                storage: .failure(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "")))
            ),
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

    // MARK: - Custom nodes and the HTTPS signing route (S-6)

    /// A custom node is checked for the HTTPS JSON-RPC route that signing
    /// uses before it is saved. Before the fix only its WebSocket was
    /// checked, so a WebSocket-only node showed balances and failed every
    /// fee estimate and send without explanation.
    func testCustomNodeIsCheckedForTheSigningRoute() async throws {
        let genesis = PIIndexerClient.soraMainnetGenesis
        RPCStubProtocol.resetByHost { host, method, _ in
            guard method == "chain_getBlockHash" else { return nil }
            switch host {
            case "good.test":
                return .result("\"\(genesis)\"")
            case "other-network.test":
                return .result("\"0x\(String(repeating: "7e", count: 32))\"")
            case "websocket-only.test":
                return .http(404)
            default:
                return nil
            }
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RPCStubProtocol.self]
        let session = URLSession(configuration: configuration)
        func probe(_ address: String) async throws -> Sora2NodeSigningRoute {
            await Sora2NodeSigningRoute.probe(nodeURL: try XCTUnwrap(URL(string: address)), session: session)
        }

        let good = try await probe("wss://good.test")
        XCTAssertEqual(good, .available)
        let other = try await probe("wss://other-network.test")
        XCTAssertEqual(other, .anotherNetwork)
        let websocketOnly = try await probe("wss://websocket-only.test:9944/rpc")
        XCTAssertEqual(websocketOnly, .missing)
        XCTAssertEqual(RPCStubProtocol.callCount("chain_getBlockHash", host: "websocket-only.test"), 1)
        // A plain `ws://` address has no HTTPS route at all; nothing is sent.
        let plain = try await probe("ws://plain.test:9944")
        XCTAssertEqual(plain, .missing)
        XCTAssertFalse(RPCStubProtocol.hosts().contains("plain.test"))

        // The user is told what is missing, in both languages.
        for key in [
            "This node answers on its WebSocket address but not over HTTPS at the same address. The app needs both: balances use the WebSocket, and fee estimates and sends use HTTPS. With this node balances would load and every send would fail, so it was not saved. Use a node that serves wss:// and https:// at the same address.",
            "This node does not answer over HTTPS, so it can't send transactions",
            "The selected node does not answer over HTTPS at its address, so the app can't prepare or send transactions through it. Balances still load. Choose another node in the node settings and try again."
        ] {
            XCTAssertEqual(WalletUX.text(key, language: "en"), key)
            XCTAssertNotEqual(WalletUX.text(key, language: "ja"), key)
        }
        XCTAssertFalse(Sora2NodeSigningRoute.missingRouteMessage.isEmpty)

        // A node selected by an earlier version may still lack the route.
        // Every signing flow then says why, instead of "try again".
        let custom = URL(string: "ws://plain.test:9944")
        let bundled = URL(string: "wss://ws.mof.sora.org")
        XCTAssertEqual(
            Sora2SigningNotice.kind(for: Sora2BoundedHTTPJSONRPCError.invalidEndpoint, nodeURL: custom),
            .nodeWithoutSigningRoute
        )
        let websocketOnlyNode = URL(string: "wss://websocket-only.test")
        // Statuses that mean "no JSON-RPC here", and a page that is not
        // JSON: the route is missing.
        for status in [404, 405, 426, 501] {
            XCTAssertEqual(
                Sora2SigningNotice.kind(for: Sora2BoundedHTTPJSONRPCError.httpStatus(status), nodeURL: websocketOnlyNode),
                .nodeWithoutSigningRoute,
                "\(status)"
            )
        }
        XCTAssertEqual(
            Sora2SigningNotice.kind(for: Sora2BoundedHTTPJSONRPCError.notJSONRPC, nodeURL: websocketOnlyNode),
            .nodeWithoutSigningRoute
        )
        // A custom node that serves HTTPS and is busy for a moment (rate
        // limit, proxy or node restarting) is not told it can never send.
        // Before, any refusal from a custom node raised the missing-route
        // alert.
        for status in [429, 500, 502, 503, 504] {
            XCTAssertNil(
                Sora2SigningNotice.kind(for: Sora2BoundedHTTPJSONRPCError.httpStatus(status), nodeURL: websocketOnlyNode),
                "\(status)"
            )
        }
        // A bundled node that refuses a request is in trouble, not missing
        // the route; other errors are not about the node's route.
        XCTAssertNil(Sora2SigningNotice.kind(for: Sora2BoundedHTTPJSONRPCError.httpStatus(404), nodeURL: bundled))
        XCTAssertNil(Sora2SigningNotice.kind(for: Sora2BoundedHTTPJSONRPCError.notJSONRPC, nodeURL: bundled))
        XCTAssertNil(Sora2SigningNotice.kind(for: Sora2BoundedHTTPJSONRPCError.remoteError, nodeURL: custom))
        XCTAssertNil(Sora2SigningNotice.kind(for: URLError(.timedOut), nodeURL: custom))
        XCTAssertEqual(
            ExtrinsicServiceError.runtimeUserMessage(for: Sora2BoundedHTTPJSONRPCError.invalidEndpoint),
            Sora2SigningNotice.message(for: .nodeWithoutSigningRoute)
        )
        // An HTTP refusal alone does not say the route is missing (a
        // bundled node can be in trouble for a moment): the message that
        // does not know the node says only that no usable answer came.
        let noAnswerKey = "The SORA node did not give a usable answer. Please try again in a moment, or choose another node."
        XCTAssertEqual(
            ExtrinsicServiceError.runtimeUserMessage(for: Sora2BoundedHTTPJSONRPCError.httpStatus(503)),
            WalletUX.text(noAnswerKey)
        )
        XCTAssertNotEqual(
            ExtrinsicServiceError.runtimeUserMessage(for: Sora2BoundedHTTPJSONRPCError.httpStatus(503)),
            Sora2SigningNotice.message(for: .nodeWithoutSigningRoute)
        )
        XCTAssertEqual(WalletUX.text(noAnswerKey, language: "en"), noAnswerKey)
        XCTAssertNotEqual(WalletUX.text(noAnswerKey, language: "ja"), noAnswerKey)

        // A JSON-RPC error object is the node answering and saying no (an
        // invalid transaction, for example). That is not a node in trouble,
        // and choosing another node would not help: it has its own text.
        let refusedKey = "The SORA network did not accept this request. Please try again."
        XCTAssertEqual(Sora2BoundedHTTPJSONRPCError.remoteError.localizedDescription, WalletUX.text(refusedKey))
        XCTAssertFalse(refusedKey.lowercased().contains("node"))
        XCTAssertEqual(WalletUX.text(refusedKey, language: "en"), refusedKey)
        XCTAssertNotEqual(WalletUX.text(refusedKey, language: "ja"), refusedKey)

        // What the transport itself reports for each kind of answer.
        RPCStubProtocol.resetByHost { host, _, _ in
            switch host {
            case "busy.test": return .http(503)
            case "limited.test": return .http(429)
            case "page.test": return .page
            case "refusing.test": return .error(code: 1010, message: "Invalid Transaction")
            default: return .http(404)
            }
        }
        func transportError(_ host: String) async -> Error? {
            let engine = Sora2BoundedHTTPJSONRPCEngine(nodeURL: URL(string: "wss://\(host)")!, session: session)
            return await withCheckedContinuation { (continuation: CheckedContinuation<Error?, Never>) in
                do {
                    _ = try engine.callMethod(
                        SoraPassport.RPCMethod.getBlockHash,
                        params: [0],
                        options: JSONRPCOptions()
                    ) { (result: Result<String, Error>) in
                        if case let .failure(error) = result {
                            continuation.resume(returning: error)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                } catch {
                    continuation.resume(returning: error)
                }
            }
        }
        for (host, status) in [("busy.test", 503), ("limited.test", 429), ("gone.test", 404)] {
            guard case let Sora2BoundedHTTPJSONRPCError.httpStatus(code)? = await transportError(host) else {
                XCTFail(host)
                continue
            }
            XCTAssertEqual(code, status, host)
        }
        guard case Sora2BoundedHTTPJSONRPCError.notJSONRPC? = await transportError("page.test") else {
            return XCTFail("A page that is not JSON is not a JSON-RPC answer")
        }
        guard case Sora2BoundedHTTPJSONRPCError.remoteError? = await transportError("refusing.test") else {
            return XCTFail("A JSON-RPC error object is the node's refusal")
        }

        // The notice is shown for a failed attempt, not more than once per
        // interval, and never for an ordinary error.
        var shown: [Sora2SigningNotice.Kind] = []
        let previous = Sora2SigningNotice.present
        Sora2SigningNotice.present = { kind, _ in shown.append(kind) }
        Sora2SigningNotice.resetForTesting()
        defer {
            Sora2SigningNotice.present = previous
            Sora2SigningNotice.resetForTesting()
        }
        let start = Date()
        Sora2SigningNotice.report(Sora2BoundedHTTPJSONRPCError.invalidEndpoint, nodeURL: custom, now: start)
        Sora2SigningNotice.report(Sora2BoundedHTTPJSONRPCError.invalidEndpoint, nodeURL: custom, now: start.addingTimeInterval(5))
        Sora2SigningNotice.report(URLError(.timedOut), nodeURL: custom, now: start.addingTimeInterval(6))
        Sora2SigningNotice.report(
            ExtrinsicServiceError.unsupportedSignedExtension(identifier: "CheckSomethingNew"),
            nodeURL: bundled,
            now: start.addingTimeInterval(7)
        )
        Sora2SigningNotice.report(
            Sora2BoundedHTTPJSONRPCError.invalidEndpoint,
            nodeURL: custom,
            now: start.addingTimeInterval(Sora2SigningNotice.minimumInterval + 1)
        )
        XCTAssertEqual(shown, [.nodeWithoutSigningRoute, .appUpdateRequired, .nodeWithoutSigningRoute])
    }

    /// The add flow itself. A node whose WebSocket answers and whose HTTPS
    /// address does not is not saved, and the form is told why; before the
    /// fix it was saved and every send through it failed. A node with the
    /// route is saved as before.
    func testAddingACustomNodeWithoutTheSigningRouteIsRefused() async throws {
        let chain = SoraPassport.ChainModel(
            chainId: PIIndexerClient.soraMainnetGenesis, name: "SORA", nodes: [], addressPrefix: 69,
            icon: nil, selectedNode: nil, customNodes: nil, iosMinAppVersion: nil
        )
        let address = try XCTUnwrap(URL(string: "wss://custom.test:9944"))
        func add(
            route: Sora2NodeSigningRoute,
            to chain: SoraPassport.ChainModel
        ) async throws -> (output: CustomNodeOutput, saved: [SoraPassport.ChainModel], probed: [URL]) {
            let chains = MemoryRepository<SoraPassport.ChainModel>()
            let output = CustomNodeOutput()
            let probed = LockedList<URL>()
            let interactor = CustomNodeInteractor(
                settings: InMemorySettingsManager(),
                eventCenter: SilentEventCenter(),
                operationManager: OperationManager(),
                repository: AnyDataProviderRepository(chains),
                nodeRepository: AnyDataProviderRepository(MemoryRepository<SoraPassport.ChainNodeModel>()),
                substrateOperationFactory: ReachableNodeOperationFactory(),
                chain: chain,
                mode: .add,
                signingRouteProbe: { url in
                    probed.append(url)
                    return route
                }
            )
            interactor.presenter = output
            interactor.updateCustomNode(url: address, name: "Custom")
            let deadline = Date().addingTimeInterval(10)
            while !output.finished, Date() < deadline {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            return (output, chains.items, probed.values)
        }

        let refused = try await add(route: .missing, to: chain)
        XCTAssertEqual(refused.probed, [address])
        XCTAssertEqual(refused.output.errors.count, 1)
        guard case .noSigningRoute? = refused.output.errors.first else {
            return XCTFail("\(refused.output.errors)")
        }
        XCTAssertNil(refused.output.added)
        XCTAssertTrue(refused.saved.isEmpty)

        let foreign = try await add(route: .anotherNetwork, to: chain)
        guard case .invalidConnection? = foreign.output.errors.first else {
            return XCTFail("\(foreign.output.errors)")
        }
        XCTAssertTrue(foreign.saved.isEmpty)

        let accepted = try await add(route: .available, to: chain)
        XCTAssertTrue(accepted.output.errors.isEmpty)
        XCTAssertEqual(accepted.output.added?.customNodes?.map(\.url), [address])
        XCTAssertEqual(accepted.saved.first?.customNodes?.map(\.url), [address])

        // Only SORA mainnet signs over HTTPS; any other chain keeps the
        // earlier flow and is not probed.
        let other = SoraPassport.ChainModel(
            chainId: "0x" + String(repeating: "3c", count: 32), name: "Other", nodes: [], addressPrefix: 69,
            icon: nil, selectedNode: nil, customNodes: nil, iosMinAppVersion: nil
        )
        let unprobed = try await add(route: .missing, to: other)
        XCTAssertTrue(unprobed.probed.isEmpty)
        XCTAssertEqual(unprobed.saved.first?.customNodes?.map(\.url), [address])

        // The message shown with the refusal names what is missing.
        XCTAssertEqual(
            AddConnectionError.noSigningRoute.toErrorContent(for: Locale(identifier: "en")).message,
            Sora2NodeSigningRoute.missingRouteMessage
        )

        // The WebSocket check that App Store builds make first: the node's
        // block zero must be this network's. A node that does not answer is
        // refused (it used to pass while no genesis had been learned, and
        // otherwise left the form waiting without end).
        let genesis = PIIndexerClient.soraMainnetGenesis
        let foreignGenesis = "0x" + String(repeating: "3c", count: 32)
        XCTAssertTrue(CustomNodeInteractor.isExpectedGenesis(genesis, externalGenesis: genesis, chainId: genesis))
        XCTAssertTrue(CustomNodeInteractor.isExpectedGenesis(genesis.uppercased(), externalGenesis: nil, chainId: genesis))
        XCTAssertFalse(CustomNodeInteractor.isExpectedGenesis(foreignGenesis, externalGenesis: genesis, chainId: genesis))
        XCTAssertFalse(CustomNodeInteractor.isExpectedGenesis(foreignGenesis, externalGenesis: nil, chainId: genesis))
        XCTAssertFalse(CustomNodeInteractor.isExpectedGenesis(nil, externalGenesis: nil, chainId: genesis))
        XCTAssertFalse(CustomNodeInteractor.isExpectedGenesis(nil, externalGenesis: genesis, chainId: genesis))
        XCTAssertFalse(CustomNodeInteractor.isExpectedGenesis("", externalGenesis: nil, chainId: ""))
    }

    // MARK: - Review round 6: the journal's result reaches the screens

    private var xorAsset: AssetInfo {
        AssetInfo(id: Self.xorAssetId, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true)
    }

    private func settle(
        _ what: String,
        timeout: TimeInterval = 10,
        until condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), what)
    }

    private func activityRows(_ viewModel: ActivityViewModel) -> [ActivityContentViewModel] {
        viewModel.sections.flatMap(\.items).compactMap { item in
            if case let .activity(activity) = item {
                return activity.model
            }
            return nil
        }
    }

    /// The Activity screen as the app builds it, on the history service the
    /// app uses, with the indexer's answer and the journal of this test.
    private func activityScreen(
        address: String,
        thisRun: LocalTransactionStorageProtocol,
        indexer: IndexerHistoryStub,
        journal: Sora2PendingSubmissionStore,
        now: @escaping () -> Date = Date.init
    ) -> (viewModel: ActivityViewModel, view: ActivityListTestView, history: HistoryService) {
        let asset = xorAsset
        let manager = BalanceListAssetManager(assets: [asset])
        let history = HistoryService(
            operationManager: OperationManager(),
            address: address,
            assets: [asset],
            localStorage: thisRun,
            readRemote: { _, _, _, _ in indexer.page },
            readJournal: { (try? journal.all()) ?? [] },
            now: now
        )
        let viewModel = ActivityViewModel(
            historyService: history,
            viewModelFactory: ActivityViewModelFactory(walletAssets: [asset], assetManager: manager),
            wireframe: ActivityWireframe(),
            assetManager: manager,
            eventCenter: SilentEventCenter(),
            notificationCenter: NotificationCenter(),
            refreshDelay: { _ in 3_600 }
        )
        let view = ActivityListTestView(viewModel: viewModel)
        viewModel.view = view
        return (viewModel, view, history)
    }

    /// A transfer the indexer lists, as its page carries it.
    private func indexedTransfer(hash: String, from: String, timestamp: Int) -> TxHistoryItem {
        TxHistoryItem(
            id: "0x\(hash)",
            blockHash: "0x" + String(repeating: "b1", count: 32),
            module: "assets",
            method: "transfer",
            timestamp: String(timestamp),
            networkFee: "700000000000000",
            success: true,
            data: [
                TxHistoryItemParam(paramName: "amount", paramValue: "1"),
                TxHistoryItemParam(paramName: "assetId", paramValue: Self.xorAssetId),
                TxHistoryItemParam(paramName: "from", paramValue: from),
                TxHistoryItemParam(paramName: "to", paramValue: "cnRWUatULzf8AVfKVexXMKJx9bT9UeTEM4wmWG7B7g1cxVjXy"),
            ],
            nestedData: nil
        )
    }

    /// Review finding 1. The reconciler wrote what became of a sent
    /// transaction into the journal, and no screen read the journal:
    /// Activity is built by `HistoryService` from the indexer and the rows
    /// of the current run. A transfer the node accepted and never included
    /// stayed "Pending" for the rest of the session and was gone, without a
    /// word, after a restart.
    ///
    /// Here the production reconciler resolves such a transfer against a
    /// stub chain, and the production Activity screen (view model, row
    /// factory, history service) shows it: the row of this run turns to
    /// failed when the "resolved" event arrives, and after a restart a row
    /// made from the journal says that the network did not include it.
    @MainActor
    func testActivityShowsWhatBecameOfASentTransaction() async throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        // The era is 128 ..< 192. The chain is finalized well past it and
        // no block holds the transaction.
        let chain = try mainnetChain(finalizedHeight: 400)
        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: chain, method, params)
        }
        let hash = String(repeating: "a7", count: 32)
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let pending = try store.stage(
            account: account.address,
            hash: hash,
            recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128)
        )
        try store.update(pending, state: .submitted)

        // What the send screen posts when the node accepted the transfer.
        let sentRow = TransferTransaction(
            base: TransactionBase(
                txHash: "0x\(hash)",
                blockHash: "",
                fee: Amount(value: 0),
                status: .pending,
                timestamp: "\(Date().timeIntervalSince1970)"
            ),
            amount: Amount(value: 1),
            peer: "cnRWUatULzf8AVfKVexXMKJx9bT9UeTEM4wmWG7B7g1cxVjXy",
            transferType: .outcoming,
            tokenId: Self.xorAssetId
        )
        let indexer = IndexerHistoryStub()
        let firstRun = activityScreen(
            address: account.address,
            thisRun: SentRowsOfThisRun([account.address: [sentRow]]),
            indexer: indexer,
            journal: store
        )
        firstRun.viewModel.viewDidLoad()
        await settle("the transfer is listed as pending") {
            self.activityRows(firstRun.viewModel).map(\.txHash) == ["0x\(hash)"]
        }
        XCTAssertEqual(activityRows(firstRun.viewModel).first?.status, .pending)
        let sentTitle = try XCTUnwrap(activityRows(firstRun.viewModel).first?.title)

        // The follow-up pass: the era is over and the transfer is not on
        // the chain.
        let report = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory,
            walletNetworkSnapshot: { account.snapshot }
        ).reconcile()
        XCTAssertEqual(report.resolved, 1)
        XCTAssertEqual(try store.all().first?.terminalResolution?.kind, .expiredNotIncluded)

        // The runtime posts the event; the open list loads again. The row
        // of this run now has the journal's result. (The indexer has
        // nothing for a transaction that is not on the chain.)
        firstRun.viewModel.processPendingSubmissionsResolved(event: Sora2PendingSubmissionsResolved())
        await settle("the row of this run shows the final status") {
            self.activityRows(firstRun.viewModel).first?.status == .failed
        }
        XCTAssertEqual(activityRows(firstRun.viewModel).map(\.txHash), ["0x\(hash)"])
        XCTAssertEqual(activityRows(firstRun.viewModel).first?.title, sentTitle)
        XCTAssertEqual(firstRun.view.resets, 1)

        // After a restart the rows of the earlier run are gone. The journal
        // still knows the transaction: it gets a row that says what it is
        // and what became of it.
        let secondRun = activityScreen(
            address: account.address,
            thisRun: SentRowsOfThisRun([:]),
            indexer: indexer,
            journal: store
        )
        secondRun.viewModel.viewDidLoad()
        await settle("the journal's row after a restart") {
            self.activityRows(secondRun.viewModel).map(\.txHash) == ["0x\(hash)"]
        }
        let journalRow = try XCTUnwrap(activityRows(secondRun.viewModel).first)
        XCTAssertEqual(journalRow.status, .failed)
        XCTAssertEqual(journalRow.title, WalletUX.text("Sent transaction"))
        XCTAssertEqual(journalRow.subtitle, WalletUX.text("The network did not include it. Nothing was sent."))
        XCTAssertNotNil(journalRow.typeTransactionImage)
        // Tapping it opens details made from the same row.
        let listed = try await secondRun.history.getPageHistory(count: 50, page: 1, assetId: nil)
        let submitted = try XCTUnwrap(listed.transactions.first as? SubmittedTransaction)
        XCTAssertEqual(submitted.outcome, .notIncluded)
        XCTAssertNotNil(secondRun.history.getTransaction(by: "0x\(hash)") as? SubmittedTransaction)

        // A second transaction of the earlier run succeeded in block 140,
        // and a third was handed to the network a moment ago.
        let succeededHash = String(repeating: "a8", count: 32)
        let waitingHash = String(repeating: "a9", count: 32)
        let earlier = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 - 600).rounded(.down))
        // A few seconds ahead of the first transaction, so the order of the
        // rows does not depend on how fast the test ran.
        let justNow = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down) + 5)
        var entries = try store.all()
        entries.append(
            Sora2PendingSubmission(
                id: UUID(),
                account: account.address,
                extrinsicHash: succeededHash,
                createdAt: earlier,
                updatedAt: earlier,
                state: .submitted,
                recoveryContext: pendingContext(account: account, hash: succeededHash, chain: chain, birthBlock: 128),
                terminalResolution: Sora2PendingTerminalResolution(
                    schemaVersion: Sora2PendingTerminalResolution.currentSchemaVersion,
                    kind: .finalizedSuccess,
                    blockNumber: 140,
                    blockHash: chain.blockHash(140),
                    finalizedHeight: 400
                )
            )
        )
        entries.append(
            Sora2PendingSubmission(
                id: UUID(),
                account: account.address,
                extrinsicHash: waitingHash,
                createdAt: justNow,
                updatedAt: justNow,
                state: .submissionUnknown,
                recoveryContext: pendingContext(account: account, hash: waitingHash, chain: chain, birthBlock: 384)
            )
        )
        // Not rows: another account's transaction, one a feature owns, and
        // one that only reserved its place and never reached transport.
        let other = try pendingAccount(0x42)
        let foreignHash = String(repeating: "aa", count: 32)
        let migrationHash = String(repeating: "ab", count: 32)
        let stagedHash = String(repeating: "ac", count: 32)
        entries.append(
            Sora2PendingSubmission(
                id: UUID(), account: other.address, extrinsicHash: foreignHash,
                createdAt: justNow, updatedAt: justNow, state: .submitted,
                recoveryContext: pendingContext(account: other, hash: foreignHash, chain: chain, birthBlock: 384)
            )
        )
        entries.append(
            Sora2PendingSubmission(
                id: UUID(), account: account.address, extrinsicHash: migrationHash,
                createdAt: justNow, updatedAt: justNow, state: .submitted,
                recoveryContext: pendingContext(account: account, hash: migrationHash, chain: chain, birthBlock: 384),
                purpose: .legacyMigration
            )
        )
        entries.append(
            Sora2PendingSubmission(
                id: UUID(), account: account.address, extrinsicHash: stagedHash,
                createdAt: justNow, updatedAt: justNow, state: .stagedBeforeTransport,
                recoveryContext: pendingContext(account: account, hash: stagedHash, chain: chain, birthBlock: 384)
            )
        )
        try writeJournal(entries, in: directory)

        var clock = Date()
        let thirdRun = activityScreen(
            address: account.address,
            thisRun: SentRowsOfThisRun([:]),
            indexer: indexer,
            journal: store,
            now: { clock }
        )
        thirdRun.viewModel.viewDidLoad()
        await settle("three journal rows, newest first") {
            self.activityRows(thirdRun.viewModel).map(\.txHash) ==
                ["0x\(waitingHash)", "0x\(hash)", "0x\(succeededHash)"]
        }
        var rows = activityRows(thirdRun.viewModel)
        XCTAssertEqual(rows.map(\.status), [.pending, .failed, .success])
        XCTAssertEqual(rows[0].subtitle, WalletUX.text("Waiting for the network to confirm it"))
        XCTAssertEqual(rows[2].subtitle, WalletUX.text("Confirmed by the network"))

        // The indexer has caught up with the one that succeeded: its row
        // is the record, and the transaction is listed once.
        indexer.page = HistoryService.RemotePage(
            items: [indexedTransfer(hash: succeededHash, from: account.address, timestamp: Int(earlier.timeIntervalSince1970))],
            endReached: true
        )
        thirdRun.viewModel.resetPagination()
        await settle("the indexer's row replaces the journal's") {
            let rows = self.activityRows(thirdRun.viewModel)
            return rows.count == 3 && rows.last?.title == sentTitle
        }
        rows = activityRows(thirdRun.viewModel)
        XCTAssertEqual(rows.map(\.txHash), ["0x\(waitingHash)", "0x\(hash)", "0x\(succeededHash)"])
        XCTAssertEqual(rows.last?.status, .success)

        // A page that has older pages under it lists only journal entries
        // from its own stretch of time; an older entry belongs further
        // down, where the indexer's own row for it (if any) is shown.
        indexer.page = HistoryService.RemotePage(
            items: [indexedTransfer(hash: succeededHash, from: account.address, timestamp: Int(justNow.timeIntervalSince1970) + 5)],
            endReached: false
        )
        let bounded = try await thirdRun.history.getPageHistory(count: 50, page: 1, assetId: nil)
        XCTAssertEqual(bounded.transactions.map(\.base.txHash), ["0x\(succeededHash)"])
        // A list for one asset shows no journal rows: the journal does not
        // know which asset a transaction moved.
        indexer.page = HistoryService.RemotePage(items: [], endReached: true)
        let forAsset = try await thirdRun.history.getHistory(count: 100, assetId: Self.xorAssetId)
        XCTAssertTrue(forAsset.isEmpty)
        // It does give a row of this run its final status.
        let assetList = HistoryService(
            operationManager: OperationManager(),
            address: account.address,
            assets: [xorAsset],
            localStorage: SentRowsOfThisRun([account.address: [sentRow]]),
            readRemote: { _, _, _, _ in indexer.page },
            readJournal: { (try? store.all()) ?? [] }
        )
        let recent = try await assetList.getHistory(count: 100, assetId: Self.xorAssetId)
        XCTAssertEqual(recent.map(\.base.txHash), ["0x\(hash)"])
        XCTAssertEqual(recent.first?.base.status, .failed)
        XCTAssertTrue(recent.first is TransferTransaction)

        // "Pending" is a claim with an end: after a week without a result
        // the journal no longer makes it.
        clock = Date().addingTimeInterval(8 * 24 * 3_600)
        let weekLater = try await thirdRun.history.getPageHistory(count: 50, page: 1, assetId: nil)
        XCTAssertEqual(
            weekLater.transactions.map(\.base.txHash),
            ["0x\(hash)", "0x\(succeededHash)"]
        )

        // The texts, in both languages.
        for key in [
            "Sent transaction",
            "Waiting for the network to confirm it",
            "Confirmed by the network",
            "It failed on the network",
            "The network did not include it. Nothing was sent.",
        ] {
            XCTAssertEqual(WalletUX.text(key, language: "en"), key)
            XCTAssertNotEqual(WalletUX.text(key, language: "ja"), key)
        }
        withExtendedLifetime((firstRun, secondRun, thirdRun)) {}
    }

    /// The details of a transaction that is still pending are open (as
    /// right after sending). When a pass gives the transaction its final
    /// status, the screen shows it; before, it kept saying "Pending".
    @MainActor
    func testOpenTransactionDetailsTakeTheFinalStatusFromTheJournal() async throws {
        let hash = "0x" + String(repeating: "c7", count: 32)
        let manager = BalanceListAssetManager(assets: [xorAsset])
        // The journal is a file: it is never read on the main thread.
        let readOnMainThread = LockedList<Bool>()
        func details(
            of model: Transaction,
            outcome: SubmittedTransaction.Outcome?
        ) -> (viewModel: ActivityDetailsViewModel, view: ActivityDetailsTestView) {
            let viewModel = ActivityDetailsViewModel(
                model: model,
                wireframe: nil,
                assetManager: manager,
                detailsFactory: ActivityDetailsViewModelFactory(assetManager: manager),
                historyService: IdleHistoryService(),
                lpServiceFee: NoLiquidityProviderFee(),
                journalOutcome: { asked in
                    readOnMainThread.append(Thread.isMainThread)
                    XCTAssertEqual(asked, hash)
                    return outcome
                }
            )
            let view = ActivityDetailsTestView()
            viewModel.view = view
            viewModel.updateContent { _ in }
            return (viewModel, view)
        }
        func statusText(_ view: ActivityDetailsTestView) -> String? {
            (view.items.first as? HeaderActivityDetailsItem)?.details.first?.assetAmountText.text
        }
        let base = TransactionBase(
            txHash: hash, blockHash: "", fee: Amount(value: 0), status: .pending,
            timestamp: "\(Date().timeIntervalSince1970)"
        )
        let transfer = TransferTransaction(
            base: base, amount: Amount(value: 1), peer: "cnRWUatULzf8AVfKVexXMKJx9bT9UeTEM4wmWG7B7g1cxVjXy",
            transferType: .outcoming, tokenId: Self.xorAssetId
        )

        let failed = details(of: transfer, outcome: .notIncluded)
        XCTAssertEqual(
            (failed.viewModel.items.first as? HeaderActivityDetailsItem)?.details.first?.assetAmountText.text,
            TransactionBase.Status.pending.title
        )
        failed.viewModel.processPendingSubmissionsResolved(event: Sora2PendingSubmissionsResolved())
        await settle("the open details show the final status") {
            statusText(failed.view) == TransactionBase.Status.failed.title
        }

        let succeeded = details(of: transfer, outcome: .succeeded)
        succeeded.viewModel.processPendingSubmissionsResolved(event: Sora2PendingSubmissionsResolved())
        await settle("a success is shown as well") {
            statusText(succeeded.view) == TransactionBase.Status.success.title
        }

        // No result for this transaction yet: the screen is left alone.
        let waiting = details(of: transfer, outcome: nil)
        waiting.viewModel.processPendingSubmissionsResolved(event: Sora2PendingSubmissionsResolved())
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(waiting.view.items.isEmpty)

        // A row made from the journal has details too, and its line of
        // explanation follows the result.
        let journalRow = SubmittedTransaction(base: base, outcome: .pending)
        let fromJournal = details(of: journalRow, outcome: .failed)
        let header = try XCTUnwrap(fromJournal.viewModel.items.first as? HeaderActivityDetailsItem)
        XCTAssertEqual(header.typeText, WalletUX.text("Sent transaction"))
        XCTAssertEqual(header.firstBalanceText.string, WalletUX.text("Waiting for the network to confirm it"))
        XCTAssertTrue(fromJournal.viewModel.items.contains { $0 is ActivityDetailsItem })
        fromJournal.viewModel.processPendingSubmissionsResolved(event: Sora2PendingSubmissionsResolved())
        await settle("the journal row's details follow") {
            statusText(fromJournal.view) == TransactionBase.Status.failed.title
        }
        XCTAssertEqual(
            (fromJournal.view.items.first as? HeaderActivityDetailsItem)?.firstBalanceText.string,
            WalletUX.text("It failed on the network")
        )
        XCTAssertEqual(readOnMainThread.values, [false, false, false, false])
        withExtendedLifetime((failed, succeeded, waiting, fromJournal)) {}
    }

    // MARK: - Review round 6: follow-up passes, ageing, another history

    /// Review finding 2. A pass that found the transaction in a finalized
    /// block and could not read its result, or whose read failed midway,
    /// asked for no further pass: the result was looked for again only at
    /// the next start, return to the foreground or submission.
    func testAPassThatLeavesAResultUnreadAsksForAFollowUp() async throws {
        let account = try pendingAccount()
        var chain = try mainnetChain(finalizedHeight: 5_000)
        let extrinsic = Data([0x31, 0x41, 0x59])
        let hash = try extrinsic.blake2b32().toHex(includePrefix: false)
        chain.extrinsics[131] = [extrinsic.toHex(includePrefix: true)]
        let twoHoursAgo = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 - 2 * 3_600).rounded(.down))
        func entry(_ hash: String, created: Date, birthBlock: Int, in chain: StubChain) -> Sora2PendingSubmission {
            Sora2PendingSubmission(
                id: UUID(),
                account: account.address,
                extrinsicHash: hash,
                createdAt: created,
                updatedAt: created,
                state: .submitted,
                recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: birthBlock)
            )
        }

        // (a) In a finalized block; the node pruned the state and neither
        // an archive nor the indexer answers.
        let included = try temporaryDirectory()
        try writeJournal([entry(hash, created: twoHoursAgo, birthBlock: 128, in: chain)], in: included)
        let connected = chain
        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: connected, method, params)
        }
        let unread = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: included,
            walletNetworkSnapshot: { account.snapshot }
        ).scheduledPass()
        XCTAssertEqual(unread.report?.awaitingResult, 1)
        XCTAssertEqual(unread.report?.needsFollowUp, true)
        XCTAssertTrue(unread.needsFollowUp)
        // The entry is two hours old and can no longer enter the chain:
        // the old rule ("may still enter the chain") scheduled nothing.
        let recorded = try XCTUnwrap(Sora2PendingSubmissionStore(baseURL: included).all().first)
        XCTAssertNotNil(recorded.finalizedInclusion)
        XCTAssertFalse(recorded.mayStillEnterChain(now: Date()))

        // (b) The scan of the era fails midway (block bodies cannot be
        // read on a poor connection).
        let midway = try temporaryDirectory()
        var poor = try mainnetChain(finalizedHeight: 5_000)
        poor.unreadableBlocks = 150 ... 160
        let poorChain = poor
        let otherHash = String(repeating: "5b", count: 32)
        try writeJournal([entry(otherHash, created: twoHoursAgo, birthBlock: 128, in: poorChain)], in: midway)
        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: poorChain, method, params)
        }
        let failedRead = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: midway,
            walletNetworkSnapshot: { account.snapshot }
        ).scheduledPass()
        XCTAssertEqual(failedRead.report?.deferred, 1)
        XCTAssertEqual(failedRead.report?.failedReads, 1)
        XCTAssertTrue(failedRead.needsFollowUp)
        // The same read for an entry signed more than a week ago waits for
        // the next start or foreground: it is still examined then, and it
        // does not keep a schedule running after every pass.
        let ancient = try temporaryDirectory()
        let nineDaysAgo = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 - 9 * 24 * 3_600).rounded(.down))
        try writeJournal([entry(otherHash, created: nineDaysAgo, birthBlock: 128, in: poorChain)], in: ancient)
        let oldFailure = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: ancient,
            walletNetworkSnapshot: { account.snapshot }
        ).scheduledPass()
        XCTAssertEqual(oldFailure.report?.deferred, 1)
        XCTAssertEqual(oldFailure.report?.failedReads, 0)
        XCTAssertFalse(oldFailure.needsFollowUp)

        // (c) An entry whose account is no longer on this device costs no
        // request and asks for nothing.
        let unbound = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: midway,
            walletNetworkSnapshot: { try self.pendingAccount(0x55).snapshot }
        ).scheduledPass()
        XCTAssertEqual(unbound.report?.deferred, 1)
        XCTAssertEqual(unbound.report?.failedReads, 0)
        XCTAssertFalse(unbound.needsFollowUp)

        // (d) The node does not answer at all: the pass fails as a whole.
        // The entry it would have looked at is still waiting.
        RPCStubProtocol.resetByHost { _, _, _ in .http(503) }
        let offline = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: midway,
            walletNetworkSnapshot: { account.snapshot }
        ).scheduledPass()
        XCTAssertNil(offline.report)
        XCTAssertTrue(offline.needsFollowUp)
        let offlineAncient = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: ancient,
            walletNetworkSnapshot: { account.snapshot }
        ).scheduledPass()
        XCTAssertNil(offlineAncient.report)
        XCTAssertFalse(offlineAncient.needsFollowUp)
    }

    /// The runtime keeps asking while a pass says a result is still to be
    /// read, for the length of the schedule and no longer.
    @MainActor
    func testFollowUpPassesContinueWhileAResultIsUnreadAndAreBounded() async throws {
        let script = RecoveryScript()
        let runtime = Sora2PendingSubmissionRecoveryRuntime(
            makePass: { script.makePass() },
            sleep: { script.slept($0) },
            notifyResolved: { script.noteResolved() }
        )
        var awaiting = Sora2PendingReconciliationReport()
        awaiting.awaitingResult = 1
        var failedRead = Sora2PendingReconciliationReport()
        failedRead.deferred = 1
        failedRead.failedReads = 1
        var resolved = Sora2PendingReconciliationReport()
        resolved.resolved = 1
        func settle(passes: Int) async {
            let deadline = Date().addingTimeInterval(10)
            while script.passes < passes, Date() < deadline {
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        // Start: found in a block, result unread; then a read that fails;
        // then the result. Nothing in the journal is recent.
        script.enqueue(.success(awaiting))
        script.enqueue(.success(failedRead))
        script.enqueue(.success(resolved))
        runtime.markWalletStorageReadyAndResume()
        runtime.markChainReadyAndResume()
        await settle(passes: 3)
        XCTAssertEqual(script.passes, 3)
        XCTAssertEqual(script.delays, [12, 20])
        XCTAssertEqual(script.resolvedNotices, 1)

        // A result that never becomes readable: one pass and the eight of
        // the schedule, then nothing until the next start or foreground.
        script.reset()
        for _ in 0 ..< 20 {
            script.enqueue(.success(awaiting))
        }
        runtime.resumePendingAfterProcessStart()
        await settle(passes: Sora2PendingFollowUpSchedule.delays.count + 1)
        XCTAssertEqual(script.passes, Sora2PendingFollowUpSchedule.delays.count + 1)
        XCTAssertEqual(script.delays, Sora2PendingFollowUpSchedule.delays)
    }

    /// Review finding 10. After each pass the runtime, which lives on the
    /// main actor, read the journal file to decide whether to schedule
    /// another pass. The pass now brings that answer with it.
    @MainActor
    func testTheRecoveryPassReadsTheJournalOffTheMainThread() async throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        // The era (128 ..< 192) is over and the transaction is not on the
        // chain: the pass resolves it, and then looks into the journal for
        // anything recent that is still open.
        let chain = try mainnetChain(finalizedHeight: 400)
        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: chain, method, params)
        }
        let hash = String(repeating: "e9", count: 32)
        let plain = try Sora2PendingSubmissionStore(baseURL: directory)
        let pending = try plain.stage(
            account: account.address,
            hash: hash,
            recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128)
        )
        try plain.update(pending, state: .submitted)

        let files = ThreadRecordingFileManager()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RPCStubProtocol.self]
        let reconciler = Sora2PendingSubmissionReconciler(
            store: try Sora2PendingSubmissionStore(fileManager: files, baseURL: directory),
            engine: Sora2BoundedHTTPJSONRPCEngine(
                sourceEngine: MetadataTestEngine(),
                session: URLSession(configuration: configuration)
            ),
            runtimeService: RuntimeTestProvider(snapshot: nil),
            liveRuntimeIdentityCache: Sora2LiveRuntimeIdentityCache(),
            walletNetworkSnapshot: { account.snapshot },
            archiveEngines: { [] },
            indexedExecution: nil,
            rotation: Sora2PendingReconciliationRotation()
        )
        let resolvedNotices = LockedList<Bool>()
        let slept = LockedList<TimeInterval>()
        // The runtime as the app builds it: its pass is the reconciler's.
        let runtime = Sora2PendingSubmissionRecoveryRuntime(
            makePass: { { await reconciler.scheduledPass() } },
            sleep: { delay in
                slept.append(delay)
                try await Task.sleep(nanoseconds: 3_600_000_000_000)
            },
            notifyResolved: { resolvedNotices.append(true) }
        )
        files.startRecording()
        runtime.markWalletStorageReadyAndResume()
        runtime.markChainReadyAndResume()
        await settle("the pass ran and resolved the transaction") { resolvedNotices.values == [true] }
        try await Task.sleep(nanoseconds: 200_000_000)
        runtime.prepareForWalletStorageMigration()
        // Nothing is left open, so no follow-up was scheduled; the journal
        // was read for that decision, and never on the main thread.
        XCTAssertTrue(slept.values.isEmpty)
        XCTAssertGreaterThan(files.reads, 0)
        XCTAssertEqual(files.readsOnMainThread, 0)
        XCTAssertEqual(try plain.all().first?.terminalResolution?.kind, .expiredNotIncluded)
    }

    /// Review finding 3. The seven days after which a finalized
    /// transaction's result is no longer asked for were counted from
    /// signing, also for entries a feature waits for. An entry first
    /// examined more than seven days after signing therefore got exactly
    /// one try: if that read failed, every later pass left it out for good,
    /// and the legacy migration that owns such an entry polled a reconciler
    /// that never looked at it again.
    func testAResultFirstAskedForLateIsStillAskedForAgain() async throws {
        let account = try pendingAccount()
        var chain = try mainnetChain(finalizedHeight: 5_000)
        let extrinsic = Data([0x27, 0x18, 0x28])
        let hash = try extrinsic.blake2b32().toHex(includePrefix: false)
        chain.extrinsics[131] = [extrinsic.toHex(includePrefix: true)]
        let connected = chain
        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: connected, method, params)
        }
        let signed = Date(timeIntervalSince1970: 1_800_000_000)
        let opened = signed.addingTimeInterval(8 * 24 * 3_600)

        for purpose in [Sora2PendingSubmissionPurpose.legacyMigration, .generic] {
            let directory = try temporaryDirectory()
            try writeJournal(
                [
                    Sora2PendingSubmission(
                        id: UUID(),
                        account: account.address,
                        extrinsicHash: hash,
                        createdAt: signed,
                        updatedAt: signed,
                        state: .submitted,
                        recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128),
                        purpose: purpose
                    ),
                ],
                in: directory
            )
            let store = try Sora2PendingSubmissionStore(baseURL: directory)
            var indexerAnswer: Sora2IndexedExecution?
            let rotation = Sora2PendingReconciliationRotation()
            func pass(at now: Date) async throws -> Sora2PendingReconciliationReport {
                try await reconciler(
                    runtimeService: RuntimeTestProvider(snapshot: nil),
                    proofs: Sora2LiveRuntimeIdentityCache(),
                    directory: directory,
                    walletNetworkSnapshot: { account.snapshot },
                    indexedExecution: { _, _ in indexerAnswer },
                    rotation: rotation,
                    now: { now }
                ).reconcile()
            }

            // The app is opened eight days after signing. The node has
            // pruned the state and no other source answers in this pass.
            let first = try await pass(at: opened)
            XCTAssertEqual(first.awaitingResult, 1, "\(purpose)")
            var entry = try XCTUnwrap(store.all().first)
            XCTAssertEqual(entry.finalizedInclusion?.blockNumber, 131)
            XCTAssertEqual(entry.finalizedInclusion?.recordedAt, opened)
            XCTAssertNil(entry.terminalResolution)
            XCTAssertTrue(entry.resultIsStillLookedFor(now: opened.addingTimeInterval(60)), "\(purpose)")

            // A minute later the indexer answers. The entry is asked about
            // again and gets its result. Before the fix this pass returned
            // an empty report and the entry stayed without one for ever.
            indexerAnswer = Sora2IndexedExecution(blockNumber: 131, blockHash: chain.blockHash(131), succeeded: true)
            let second = try await pass(at: opened.addingTimeInterval(60))
            XCTAssertEqual(second.resolved, 1, "\(purpose)")
            entry = try XCTUnwrap(store.all().first)
            XCTAssertEqual(entry.terminalResolution?.kind, .finalizedSuccess, "\(purpose)")
        }

        // A week of asking does end for a generic entry, counted from the
        // moment its inclusion was written down; an entry a feature waits
        // for is asked about for as long as it has no result.
        func awaiting(_ purpose: Sora2PendingSubmissionPurpose, recordedAt: Date?) -> Sora2PendingSubmission {
            Sora2PendingSubmission(
                id: UUID(),
                account: account.address,
                extrinsicHash: hash,
                createdAt: signed,
                updatedAt: opened,
                state: .submitted,
                recoveryContext: pendingContext(account: account, hash: hash, chain: chain, birthBlock: 128),
                purpose: purpose,
                finalizedInclusion: Sora2PendingFinalizedInclusion(
                    schemaVersion: Sora2PendingFinalizedInclusion.currentSchemaVersion,
                    blockNumber: 131,
                    blockHash: chain.blockHash(131),
                    extrinsicIndex: 0,
                    finalizedHeight: 5_000,
                    recordedAt: recordedAt
                )
            )
        }
        let sixDaysOn = opened.addingTimeInterval(6 * 24 * 3_600)
        let eightDaysOn = opened.addingTimeInterval(8 * 24 * 3_600)
        XCTAssertTrue(awaiting(.generic, recordedAt: opened).resultIsStillLookedFor(now: sixDaysOn))
        XCTAssertFalse(awaiting(.generic, recordedAt: opened).resultIsStillLookedFor(now: eightDaysOn))
        // An entry written before the time was kept: its last change is
        // the recording of its inclusion.
        XCTAssertTrue(awaiting(.generic, recordedAt: nil).resultIsStillLookedFor(now: sixDaysOn))
        XCTAssertFalse(awaiting(.generic, recordedAt: nil).resultIsStillLookedFor(now: eightDaysOn))
        XCTAssertTrue(awaiting(.legacyMigration, recordedAt: opened).resultIsStillLookedFor(now: eightDaysOn))
        XCTAssertTrue(
            awaiting(.legacyMigration, recordedAt: opened)
                .resultIsStillLookedFor(now: opened.addingTimeInterval(400 * 24 * 3_600))
        )
        // The time is additive: a journal without it reads unchanged, and
        // one with it reads back the same.
        let directory = try temporaryDirectory()
        let withTime = awaiting(.generic, recordedAt: opened)
        let withoutTime = Sora2PendingSubmission(
            id: UUID(),
            account: account.address,
            extrinsicHash: String(repeating: "6c", count: 32),
            createdAt: signed,
            updatedAt: opened,
            state: .submitted,
            recoveryContext: pendingContext(
                account: account, hash: String(repeating: "6c", count: 32), chain: chain, birthBlock: 128
            ),
            finalizedInclusion: Sora2PendingFinalizedInclusion(
                schemaVersion: Sora2PendingFinalizedInclusion.currentSchemaVersion,
                blockNumber: 131,
                blockHash: chain.blockHash(131),
                extrinsicIndex: 0,
                finalizedHeight: 5_000
            )
        )
        try writeJournal([withTime, withoutTime], in: directory)
        XCTAssertEqual(try Sora2PendingSubmissionStore(baseURL: directory).all(), [withTime, withoutTime])
    }

    /// Review finding 4. The transaction is signed against the finalized
    /// head of the node it is built on. A node that has another block at
    /// that height follows another finalized history (a fork with the
    /// mainnet genesis, which the add-node check accepts), and what it lacks
    /// is not evidence. The previous round resolved such an entry as "not
    /// included", which for a legacy migration offers to sign it again.
    func testEntrySignedOnAnotherFinalizedHistoryIsLeftUnresolved() async throws {
        let directory = try temporaryDirectory()
        let account = try pendingAccount()
        let chain = try mainnetChain(finalizedHeight: 400)
        RPCStubProtocol.resetByHost { [unowned self] _, method, params in
            self.prunedAnswer(chain: chain, method, params)
        }
        let hash = String(repeating: "d5", count: 32)
        let signedOn = String(repeating: "0f", count: 32)
        let created = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 - 2 * 3_600).rounded(.down))
        func entry(birthBlockHash: String?) -> Sora2PendingSubmission {
            Sora2PendingSubmission(
                id: UUID(),
                account: account.address,
                extrinsicHash: hash,
                createdAt: created,
                updatedAt: created,
                state: .submissionUnknown,
                recoveryContext: pendingContext(
                    account: account,
                    hash: hash,
                    chain: chain,
                    birthBlock: 128,
                    birthBlockHash: birthBlockHash
                )
            )
        }
        try writeJournal([entry(birthBlockHash: signedOn)], in: directory)
        let store = try Sora2PendingSubmissionStore(baseURL: directory)

        // The era (128 ..< 192) is long over on this node's chain, and the
        // transaction is not in it.
        let outcome = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory,
            walletNetworkSnapshot: { account.snapshot }
        ).scheduledPass()
        let report = try XCTUnwrap(outcome.report)
        XCTAssertEqual(report.resolved, 0)
        XCTAssertEqual(report.deferred, 1)
        // Asking this node again in a few seconds would change nothing.
        XCTAssertEqual(report.failedReads, 0)
        XCTAssertFalse(outcome.needsFollowUp)
        let left = try XCTUnwrap(store.all().first)
        XCTAssertNil(left.terminalResolution)
        XCTAssertNil(left.finalizedInclusion)
        XCTAssertEqual(left.state, .submissionUnknown)
        // Only the block the transaction was signed against was compared;
        // the era was not scanned on this history.
        XCTAssertEqual(RPCStubProtocol.callCount("chain_getBlock", host: Self.prunedHost), 2)

        // Time alone still deals with it: after the first hour it neither
        // blocks the removal of its account nor holds a journal place.
        XCTAssertNoThrow(
            try WalletPendingDeletionPolicy.validate(
                nexusTransactions: [],
                polkamarktTransactions: [],
                sora2Submissions: try store.all(),
                walletId: account.address,
                soraAddress: account.address
            )
        )
        XCTAssertEqual(Sora2PendingSubmissionStore.evictionIndex(in: try store.all(), now: Date()), 0)

        // Connected to the chain it was signed on again, it resolves like
        // any other entry.
        try writeJournal([entry(birthBlockHash: nil)], in: directory)
        let back = try await reconciler(
            runtimeService: RuntimeTestProvider(snapshot: nil),
            proofs: Sora2LiveRuntimeIdentityCache(),
            directory: directory,
            walletNetworkSnapshot: { account.snapshot }
        ).reconcile()
        XCTAssertEqual(back.resolved, 1)
        XCTAssertEqual(try store.all().first?.terminalResolution?.kind, .expiredNotIncluded)
    }

    // MARK: - Review round 6: balances that could not be read

    private static let valAssetId =
        "0x0200040000000000000000000000000000000000000000000000000000000000"

    /// Review finding 8, first part. One request of a balance read timed
    /// out: the asset was marked unavailable (its last good value thrown
    /// away) and nothing read it again until the account's XOR next
    /// changed. Now the value of the read before stays, and the provider
    /// asks again by itself, a bounded number of times.
    @MainActor
    func testBalanceProviderKeepsTheLastValueAndAsksAgain() throws {
        let xor = BalanceData(identifier: Self.xorAssetId, balance: AmountDecimal(value: 7))
        let val = BalanceData(identifier: Self.valAssetId, balance: AmountDecimal(value: 5))
        let ids = [Self.xorAssetId, Self.valAssetId]
        var refreshes = 0
        var timers: [(delay: TimeInterval, fire: () -> Void)] = []
        let provider = AssetProvider(
            refresh: { refreshes += 1 },
            schedule: { delay, fire in timers.append((delay, fire)) }
        )

        // A complete read: nothing more is asked for.
        provider.receive([xor, val])
        XCTAssertEqual(provider.getBalances(with: ids), [xor, val])
        XCTAssertTrue(provider.unavailableBalanceAssetIds(among: ids).isEmpty)
        XCTAssertTrue(timers.isEmpty)

        // The next read: the request for VAL got no answer. VAL keeps the
        // 5 it had (before: "Balance unavailable"), and a read is asked for
        // again after the first delay.
        let moreXor = BalanceData(identifier: Self.xorAssetId, balance: AmountDecimal(value: 8))
        provider.receive([moreXor, BalanceData.unavailable(identifier: Self.valAssetId, notRead: true)])
        XCTAssertEqual(provider.getBalances(with: ids), [moreXor, val])
        XCTAssertTrue(provider.unavailableBalanceAssetIds(among: ids).isEmpty)
        XCTAssertEqual(timers.map(\.delay), [AssetProvider.retryDelays[0]])
        XCTAssertEqual(refreshes, 0)

        // The delay passes: one read. It answers with the same list, which
        // the data provider does not deliver again, so the next try is
        // already waiting.
        guard timers.count == 1 else {
            return XCTFail("No further read was asked for")
        }
        timers[0].fire()
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(timers.map(\.delay), Array(AssetProvider.retryDelays.prefix(2)))

        // The read after that is complete: the asking ends, and a timer
        // still waiting does nothing.
        let moreVal = BalanceData(identifier: Self.valAssetId, balance: AmountDecimal(value: 6))
        provider.receive([moreXor, moreVal])
        XCTAssertEqual(provider.getBalances(with: ids), [moreXor, moreVal])
        guard timers.count == 2 else {
            return XCTFail("The second try was not waiting")
        }
        timers[1].fire()
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(timers.count, 2)

        // An answer that is not understood is another matter: the value
        // held before is no longer known to be right, so the asset is
        // unavailable. It is read again as well (a runtime upgrade is
        // followed by new metadata within seconds).
        timers.removeAll()
        refreshes = 0
        provider.receive([BalanceData.unavailable(identifier: Self.xorAssetId), moreVal])
        XCTAssertEqual(provider.getBalances(with: ids), [moreVal])
        XCTAssertEqual(provider.unavailableBalanceAssetIds(among: ids), [Self.xorAssetId])
        // Every try brings the same answer: the asking stops after the
        // last delay.
        var fired = 0
        while fired < timers.count {
            timers[fired].fire()
            fired += 1
        }
        XCTAssertEqual(timers.map(\.delay), AssetProvider.retryDelays)
        XCTAssertEqual(refreshes, AssetProvider.retryDelays.count)

        // A read that fails as a whole (the account itself could not be
        // read) leaves what is shown and is asked for again, too.
        let fresh = AssetProvider(
            refresh: { refreshes += 1 },
            schedule: { delay, fire in timers.append((delay, fire)) }
        )
        timers.removeAll()
        refreshes = 0
        fresh.receive([xor, val])
        fresh.receiveReadFailure()
        XCTAssertEqual(fresh.getBalances(with: ids), [xor, val])
        XCTAssertEqual(timers.map(\.delay), [AssetProvider.retryDelays[0]])

        // The very first read of a run: nothing was held before, so an
        // asset that got no answer has nothing to show.
        let merged = AssetProvider.merge(
            previous: [],
            items: [xor, BalanceData.unavailable(identifier: Self.valAssetId, notRead: true)]
        )
        XCTAssertEqual(merged.balances, [xor])
        XCTAssertEqual(merged.unavailable, [Self.valAssetId])
        XCTAssertTrue(merged.incomplete)
        // Both marks survive the provider's cache.
        let cached = try JSONDecoder().decode(
            [BalanceData].self,
            from: JSONEncoder().encode([
                BalanceData.unavailable(identifier: Self.xorAssetId),
                BalanceData.unavailable(identifier: Self.valAssetId, notRead: true),
            ])
        )
        XCTAssertEqual(cached.map(\.isUnavailable), [true, true])
        XCTAssertEqual(cached.map(\.balanceWasNotRead), [false, true])
        XCTAssertFalse(xor.isUnavailable)
    }

    /// Review finding 8, second part. The full asset list and the token
    /// picker were built from the balances that were read, so an asset
    /// whose balance could not be read was not in them at all, and saving
    /// the full list after editing took the asset out of the wallet until
    /// the next start.
    func testAssetListsKeepAnAssetWhoseBalanceCouldNotBeRead() throws {
        let pswap = "0x0200050000000000000000000000000000000000000000000000000000000000"
        let assets = [
            xorAsset,
            AssetInfo(id: Self.valAssetId, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "SORA Validator Token", visible: true),
            AssetInfo(id: pswap, symbol: "PSWAP", chainId: "", precision: 18, icon: nil, displayName: "Polkaswap", visible: false),
        ]
        let manager = BalanceListAssetManager(assets: assets)
        let factory = AssetViewModelFactory(walletAssets: assets, assetManager: manager, fiatService: nil)
        let ids = assets.map(\.identifier)
        let balances = [
            BalanceData(identifier: Self.xorAssetId, balance: AmountDecimal(value: 2)),
            BalanceData(identifier: pswap, balance: AmountDecimal(value: 0)),
        ]
        func rows(unavailable: Set<String>) -> [AssetListItem] {
            factory.assetListItems(assetIds: ids, balances: balances, unavailable: unavailable, mode: .view) { balance, assetInfo in
                factory.createAssetViewModel(with: balance, assetInfo: assetInfo, fiatData: [], mode: .view)
            }
        }

        // What the lists did before: VAL is missing.
        XCTAssertEqual(rows(unavailable: []).map(\.assetInfo.identifier), [Self.xorAssetId, pswap])

        let listed = rows(unavailable: [Self.valAssetId])
        XCTAssertEqual(listed.map(\.assetInfo.identifier), ids)
        let valRow = try XCTUnwrap(listed.first { $0.assetInfo.identifier == Self.valAssetId })
        XCTAssertTrue(valRow.balanceUnavailable)
        XCTAssertEqual(valRow.assetViewModel.subtitle, WalletUX.balanceUnavailableText)
        XCTAssertEqual(valRow.assetViewModel.fiatText, "")
        XCTAssertFalse(valRow.assetViewModel.subtitle.contains("0"))
        XCTAssertFalse(listed[0].balanceUnavailable)
        XCTAssertTrue(listed[0].assetViewModel.subtitle.contains("2"))

        // Saving the list after editing never takes an asset out of the
        // wallet, also one that had no row at all.
        let edited = [assets[1], assets[0]]
        XCTAssertEqual(
            ManageAssetListViewModel.listToSave(edited: edited, current: assets).map(\.identifier),
            [Self.valAssetId, Self.xorAssetId, pswap]
        )
        XCTAssertEqual(
            ManageAssetListViewModel.listToSave(edited: assets, current: assets).map(\.identifier),
            ids
        )
    }

    /// Review finding 7. Asset details showed "$0" under "Balance
    /// unavailable" whenever a price was known, and once the notice was up
    /// a later successful read did not replace it or bring the Send button
    /// back.
    @MainActor
    func testAssetDetailsShowNoValueForAnUnreadBalanceAndRecover() async throws {
        let asset = xorAsset
        let provider = BalanceListAssetProvider(balances: [], unavailable: [Self.xorAssetId])
        let service = TransferableItemService(
            assetInfo: asset,
            eventCenter: SilentEventCenter(),
            assetsProvider: provider,
            referralFactory: NoReferrals()
        )
        service.usdPrice = 3
        // The item as the details screen builds it for an unread balance.
        // (The placeholder's value at a known price is the "$0" that used
        // to be shown; the cell must not show it whatever the item says.)
        let item = TransferableItem(
            assetInfo: asset,
            fiat: "$0",
            balance: Amount(value: 0),
            frozenAmount: Amount(value: 0),
            frozenFiatAmount: "$0",
            service: service,
            balanceData: BalanceData(identifier: "", balance: AmountDecimal(value: 0)),
            balanceUnavailable: true
        )
        XCTAssertTrue(service.balanceUnavailable)
        let cell = TransferableCell(style: .default, reuseIdentifier: nil)
        cell.set(item: item, context: nil)
        func texts() -> [String] {
            var found: [String] = []
            func walk(_ view: UIView) {
                if let label = view as? UILabel, !label.isHidden, let text = label.text, !text.isEmpty {
                    found.append(text)
                }
                view.subviews.forEach(walk)
            }
            walk(cell.contentView)
            return found
        }
        func sendButtonHidden() -> Bool? {
            Mirror(reflecting: cell).children
                .first { $0.label?.hasSuffix("sendButton") == true }
                .flatMap { $0.value as? UIView }?
                .isHidden
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(texts().contains(WalletUX.balanceUnavailableText), "\(texts())")
        XCTAssertFalse(texts().contains { $0.contains("$") }, "\(texts())")
        XCTAssertEqual(sendButtonHidden(), true)
        // Nothing worked out from the placeholder was published.
        XCTAssertNil(service.balanceAmount)
        XCTAssertNil(service.fiatBalanceText)

        // The balance is read: 4 XOR at $3. The notice goes, the amount,
        // its value and the Send button are there.
        let read = BalanceData(identifier: Self.xorAssetId, balance: AmountDecimal(value: 4))
        provider.set(balances: [read], unavailable: [])
        service.processBalance(data: [read])
        await settle("the balance replaces the notice") {
            !texts().contains(WalletUX.balanceUnavailableText) && texts().contains { $0.contains("4") }
        }
        XCTAssertFalse(service.balanceUnavailable)
        XCTAssertTrue(texts().contains("$12"), "\(texts())")
        XCTAssertEqual(sendButtonHidden(), false)

        // And the other way while the screen is open: the next read does
        // not understand the answer.
        provider.set(balances: [], unavailable: [Self.xorAssetId])
        service.processBalance(data: [])
        await settle("the notice replaces the balance") {
            texts().contains(WalletUX.balanceUnavailableText)
        }
        XCTAssertFalse(texts().contains { $0.contains("$") }, "\(texts())")
        XCTAssertEqual(sendButtonHidden(), true)
        withExtendedLifetime((item, cell)) {}
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
        /// 200 with a web page instead of JSON.
        case page

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
        var contentType = "application/json"
        let text: String
        switch answer {
        case .page:
            contentType = "text/html"
            text = "<html><body>It works</body></html>"
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
            headerFields: ["Content-Type": statusCode == 200 ? contentType : "text/html"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Recovery schedule and custom node test doubles

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
            // What the production pass brings back: the report, and the
            // schedule's verdict worked out from the journal where the
            // pass ran.
            let report = try? result.get()
            return Sora2PendingPassOutcome(
                report: report,
                needsFollowUp: Sora2PendingFollowUpSchedule.needsFollowUp(
                    report: report,
                    journal: journal,
                    now: Date()
                )
            )
        }
    }

    func slept(_ delay: TimeInterval) {
        locked { sleptFor.append(delay) }
    }

    func noteResolved() {
        locked { notices += 1 }
    }
}

private final class LockedList<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Element] = []

    var values: [Element] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func append(_ element: Element) {
        lock.lock()
        stored.append(element)
        lock.unlock()
    }
}

private final class CustomNodeOutput: CustomNodeInteractorOutputProtocol {
    private let lock = NSLock()
    private var receivedErrors: [AddConnectionError] = []
    private var addedChain: SoraPassport.ChainModel?

    var errors: [AddConnectionError] {
        lock.lock()
        defer { lock.unlock() }
        return receivedErrors
    }

    var added: SoraPassport.ChainModel? {
        lock.lock()
        defer { lock.unlock() }
        return addedChain
    }

    var finished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return addedChain != nil || !receivedErrors.isEmpty
    }

    func didCompleteAdding(in chain: SoraPassport.ChainModel) {
        lock.lock()
        addedChain = chain
        lock.unlock()
    }

    func didReceive(error: AddConnectionError) {
        lock.lock()
        receivedErrors.append(error)
        lock.unlock()
    }
}

/// The node's WebSocket answers `system_chain`, as a reachable node does.
private final class ReachableNodeOperationFactory: SubstrateOperationFactoryProtocol {
    func fetchChainOperation(_: URL) -> BaseOperation<String> {
        ClosureOperation { "SORA" }
    }
}

private final class SilentEventCenter: EventCenterProtocol {
    func notify(with _: EventProtocol) {}
    func notify(with _: EventProtocol, completionOnMain: @escaping () -> Void) {
        DispatchQueue.main.async(execute: completionOnMain)
    }
    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

private final class MemoryRepository<Model: RobinHood.Identifiable>: DataProviderRepositoryProtocol {
    private let lock = NSLock()
    private var stored: [Model] = []

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
                removed.contains(old.identifier) ||
                    changed.contains { $0.identifier == old.identifier }
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
            return self.items.filter { selected.contains($0.identifier) }
        }
    }

    func fetchOperation(
        by id: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<Model?> {
        ClosureOperation {
            let selected = try id()
            return self.items.first { $0.identifier == selected }
        }
    }

    func fetchOperation(
        by _: RepositorySliceRequest,
        options: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        fetchAllOperation(with: options)
    }

    func replaceOperation(_ models: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        saveOperation(models, { self.items.map(\.identifier) })
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        replaceOperation { [] }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { self.items.count }
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

// MARK: - Review round 6 test doubles

/// The indexer's answer for a history page, set by the test.
private final class IndexerHistoryStub: @unchecked Sendable {
    private let lock = NSLock()
    private var current = HistoryService.RemotePage(items: [], endReached: true)

    var page: HistoryService.RemotePage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return current
        }
        set {
            lock.lock()
            current = newValue
            lock.unlock()
        }
    }
}

/// The rows of the current run, as `LocalTransactionStorage` holds them.
private final class SentRowsOfThisRun: LocalTransactionStorageProtocol {
    var transactions: [String: [Transaction]]

    init(_ transactions: [String: [Transaction]]) {
        self.transactions = transactions
    }
}

/// The Activity screen as its view model sees it: asked to start the list
/// again, it does what the real screen does.
private final class ActivityListTestView: ActivityViewProtocol {
    private weak var viewModel: ActivityViewModel?
    private(set) var resets = 0
    let controller = UIViewController()
    var isSetup: Bool { true }

    init(viewModel: ActivityViewModel) {
        self.viewModel = viewModel
    }

    func resetPagination() {
        resets += 1
        viewModel?.resetPagination()
    }

    func stopAnimating() {}
    func startPaginationLoader() {}
    func stopPaginationLoader() {}
}

private final class ActivityDetailsTestView: ActivityDetailsViewProtocol {
    private let lock = NSLock()
    private var shown: [SoramitsuTableViewItemProtocol] = []
    let controller = UIViewController()
    var isSetup: Bool { true }

    var items: [SoramitsuTableViewItemProtocol] {
        lock.lock()
        defer { lock.unlock() }
        return shown
    }

    func update(items: [SoramitsuTableViewItemProtocol]) {
        lock.lock()
        shown = items
        lock.unlock()
    }
}

private final class IdleHistoryService: HistoryServiceProtocol {
    func getHistory(count _: Int, assetId _: String?) async throws -> [Transaction] { [] }
    func getPageHistory(count _: Int, page _: Int, assetId _: String?) async throws -> HistoryPage {
        HistoryPage(transactions: [], endReached: true)
    }
    func getTransaction(by _: String) -> Transaction? { nil }
    func getHistory(
        count _: Int,
        assetId _: String?,
        completion: @escaping (Result<[Transaction], Swift.Error>) -> Void
    ) {
        completion(.success([]))
    }
    func getPageHistory(
        count _: Int,
        page _: Int,
        assetId _: String?,
        completion: @escaping (Result<HistoryPage, Swift.Error>) -> Void
    ) {
        completion(.success(HistoryPage(transactions: [], endReached: true)))
    }
}

private struct NoLiquidityProviderFee: LPFeeServiceProtocol {
    func getLpfee(with _: UInt32) -> String { "" }
}

/// Counts the journal's reads of the file system and where they ran.
private final class ThreadRecordingFileManager: FileManager {
    private let lock = NSLock()
    private var recording = false
    private var all = 0
    private var onMain = 0

    var reads: Int {
        lock.lock()
        defer { lock.unlock() }
        return all
    }

    var readsOnMainThread: Int {
        lock.lock()
        defer { lock.unlock() }
        return onMain
    }

    func startRecording() {
        lock.lock()
        recording = true
        lock.unlock()
    }

    override func fileExists(atPath path: String) -> Bool {
        lock.lock()
        if recording {
            all += 1
            if Thread.isMainThread {
                onMain += 1
            }
        }
        lock.unlock()
        return super.fileExists(atPath: path)
    }
}

/// No referral balance and no referral operations.
private final class NoReferrals: ReferralsOperationFactoryProtocol {
    func createReferrerBalancesOperation() -> JSONRPCListOperation<JSONScaleDecodable<SoraPassport.Balance>>? { nil }
    func createExtrinsicSetReferrerOperation(with _: String) -> BaseOperation<String> {
        ClosureOperation { "" }
    }
    func createExtrinsicReserveReferralBalanceOperation(with _: BigUInt) -> BaseOperation<String> {
        ClosureOperation { "" }
    }
    func createExtrinsicUnreserveReferralBalanceOperation(with _: BigUInt) -> BaseOperation<String> {
        ClosureOperation { "" }
    }
    func createReferrerOperation() -> JSONRPCListOperation<String>? { nil }
}
