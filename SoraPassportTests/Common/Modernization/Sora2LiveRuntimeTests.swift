// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import Foundation
import IrohaCrypto
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
