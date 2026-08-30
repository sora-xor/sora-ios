// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import SSFUtils
import XCTest
@testable import SoraPassport

final class IrohaConnectTests: XCTestCase {
    func testCurrentV1RejectsLegacyAndBindsCanonicalTairaURI() throws {
        let fixture = try makeFixture()
        let launch = try IrohaConnectLaunch.parse(
            fixture.url,
            receivedAt: fixture.receivedAt
        )
        XCTAssertEqual(launch.sid, fixture.sid)
        XCTAssertEqual(
            launch.appPublicKey,
            fixture.appPrivate.publicKey.rawRepresentation
        )
        XCTAssertEqual(
            launch.network.literal,
            IrohaConnectLaunch.tairaNetworkId
        )
        XCTAssertEqual(launch.node.absoluteString, "https://taira.sora.org")
        XCTAssertEqual(launch.networkId, .taira)
        XCTAssertEqual(
            launch.webSocketURL.absoluteString,
            "wss://taira.sora.org/v1/connect/ws?sid=\(fixture.sid.base64URL)&role=wallet"
        )
        XCTAssertTrue(
            launch.webSocketProtocol.hasPrefix("iroha-connect.token.v1.")
        )

        var legacy = try XCTUnwrap(
            URLComponents(url: fixture.url, resolvingAgainstBaseURL: false)
        )
        legacy.queryItems = legacy.queryItems?.map {
            $0.name == "network_id"
                ? URLQueryItem(name: "chain_id", value: $0.value)
                : $0
        }
        XCTAssertThrowsError(
            try IrohaConnectLaunch.parse(try XCTUnwrap(legacy.url))
        )

        var duplicate = try XCTUnwrap(
            URLComponents(url: fixture.url, resolvingAgainstBaseURL: false)
        )
        duplicate.queryItems?.append(
            URLQueryItem(name: "sid", value: fixture.sid.base64URL)
        )
        XCTAssertThrowsError(
            try IrohaConnectLaunch.parse(try XCTUnwrap(duplicate.url))
        )

        var appRole = try XCTUnwrap(
            URLComponents(url: fixture.url, resolvingAgainstBaseURL: false)
        )
        appRole.queryItems = appRole.queryItems?.map {
            $0.name == "role"
                ? URLQueryItem(name: "role", value: "app")
                : $0
        }
        XCTAssertThrowsError(
            try IrohaConnectLaunch.parse(try XCTUnwrap(appRole.url))
        )
    }

    func testNoritoHandshakeCryptoPermissionAndReplayBoundary() throws {
        let fixture = try makeFixture()
        let launch = try IrohaConnectLaunch.parse(
            fixture.url,
            receivedAt: fixture.receivedAt
        )
        let permissions = IrohaConnectPermissions(
            methods: ["sign_raw"],
            events: [],
            resources: ["uranai.contract-call.v1"]
        )
        let metadata = IrohaConnectAppMetadata(
            name: "Uranai",
            url: "https://uranai.example",
            iconHash: nil
        )
        let openBytes = IrohaConnectWire.encodeOpenForTesting(
            sid: launch.sid,
            appPublicKey: launch.appPublicKey,
            network: launch.network,
            metadata: metadata,
            permissions: permissions
        )
        let decodedOpen = try IrohaConnectWire.decodeFrame(openBytes)
        XCTAssertEqual(decodedOpen.direction, 0)
        XCTAssertEqual(decodedOpen.sequence, 1)
        XCTAssertEqual(
            decodedOpen.kind,
            .control(.open(
                appPublicKey: launch.appPublicKey,
                metadata: metadata,
                network: launch.network,
                permissions: permissions
            ))
        )

        let engine = IrohaConnectSessionEngine(launch: launch)
        let serverEvent = IrohaConnectWire.encodeServerEventForTesting(
            sid: launch.sid,
            sequence: 1,
            height: 42,
            entryHash: "fixture-entry",
            proofsJSON: "[]"
        )
        XCTAssertEqual(
            try engine.receive(serverEvent, now: fixture.receivedAt),
            IrohaConnectSessionResult(event: .none, outbound: [])
        )
        XCTAssertEqual(
            try engine.receive(openBytes, now: fixture.receivedAt).event,
            .open(metadata: metadata, permissions: permissions)
        )

        let signingPrivate = try Curve25519.Signing.PrivateKey(
            rawRepresentation: Data(repeating: 0x42, count: 32)
        )
        let account = IrohaConnectWalletContext(
            walletId: "wallet-fixture",
            networkId: .taira,
            accountId: "fixture-account-i105",
            publicKey: signingPrivate.publicKey.rawRepresentation
        )
        let agreementSeed = Data((1 ... 32).map { UInt8($0) })
        let approval = try engine.approve(
            account: account,
            agreementPrivateKey: agreementSeed,
            signer: { try signingPrivate.signature(for: $0) },
            now: fixture.receivedAt
        )
        let decodedApproval = try IrohaConnectWire.decodeFrame(approval)
        guard case let .control(
            .approve(walletPublicKey, accountId, granted, proof, signature)
        ) = decodedApproval.kind else {
            return XCTFail("Expected a canonical approval frame")
        }
        XCTAssertEqual(decodedApproval.direction, 1)
        XCTAssertEqual(decodedApproval.sequence, 1)
        XCTAssertEqual(accountId, account.accountId)
        XCTAssertEqual(granted, permissions)
        XCTAssertNil(proof)
        let preimage = try IrohaConnectWire.approvalPreimage(
            launch: launch,
            walletKey: walletPublicKey,
            accountId: account.accountId,
            permissions: permissions
        )
        XCTAssertTrue(
            signingPrivate.publicKey.isValidSignature(signature, for: preimage)
        )

        let agreementPrivate = try Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: agreementSeed
        )
        var keys = try IrohaConnectCrypto.directionKeys(
            walletPrivateKey: agreementPrivate,
            appPublicKey: launch.appPublicKey,
            sid: launch.sid
        )
        defer { keys.wipe() }
        XCTAssertEqual(
            launch.sid.hexString,
            "0583df9e34f3ba384fa2c3fe9037cb9f315e4ae96d24819aa5c2f5b043bd15c5"
        )
        XCTAssertEqual(
            keys.appToWallet.hexString,
            "0e8e8c0c57d5ee3ecff8700af37712c62245e90f3f8778f960509f3ceb82cb12"
        )
        XCTAssertEqual(
            keys.walletToApp.hexString,
            "ced6e4317ce0ed612c629fd372e6de2392669310375965a7cd95298ffa8b0217"
        )
        let requestBytes = Data("fortune request".utf8)
        let requestEnvelope = try IrohaConnectWire.encodeEnvelope(
            sequence: 2,
            payload: .signRequest(.raw(
                domain: "uranai.contract-call.v1",
                bytes: requestBytes
            ))
        )
        let appCiphertext = try IrohaConnectCrypto.encrypt(
            envelope: requestEnvelope,
            key: keys.appToWallet,
            sid: launch.sid,
            direction: 0,
            sequence: 2
        )
        let requestFrame = IrohaConnectWire.encodeCiphertext(
            sid: launch.sid,
            direction: 0,
            sequence: 2,
            bytes: appCiphertext
        )
        XCTAssertEqual(
            try engine.receive(requestFrame, now: fixture.receivedAt).event,
            .signingRequest(.raw(
                domain: "uranai.contract-call.v1",
                bytes: requestBytes
            ))
        )

        let resultFrame = try engine.approvePendingSignature(
            account: account,
            signer: { try signingPrivate.signature(for: $0) },
            now: fixture.receivedAt
        )
        let decodedResultFrame = try IrohaConnectWire.decodeFrame(resultFrame)
        guard case let .ciphertext(direction, resultCiphertext) =
            decodedResultFrame.kind else {
            return XCTFail("Expected an encrypted signature result")
        }
        XCTAssertEqual(direction, 1)
        XCTAssertEqual(decodedResultFrame.sequence, 2)
        let resultPlaintext = try IrohaConnectCrypto.decrypt(
            ciphertext: resultCiphertext,
            key: keys.walletToApp,
            sid: launch.sid,
            direction: 1,
            sequence: 2
        )
        let (resultSequence, resultPayload) = try
            IrohaConnectWire.decodeEnvelope(resultPlaintext)
        XCTAssertEqual(resultSequence, 2)
        guard case let .signResult(resultSignature) = resultPayload else {
            return XCTFail("Expected an Ed25519 signature result")
        }
        XCTAssertTrue(
            signingPrivate.publicKey.isValidSignature(
                resultSignature,
                for: requestBytes
            )
        )

        let expiredBytes = Data("expired fortune request".utf8)
        let expiredEnvelope = try IrohaConnectWire.encodeEnvelope(
            sequence: 3,
            payload: .signRequest(.raw(
                domain: "uranai.contract-call.v1",
                bytes: expiredBytes
            ))
        )
        let expiredCiphertext = try IrohaConnectCrypto.encrypt(
            envelope: expiredEnvelope,
            key: keys.appToWallet,
            sid: launch.sid,
            direction: 0,
            sequence: 3
        )
        let expiredRequestFrame = IrohaConnectWire.encodeCiphertext(
            sid: launch.sid,
            direction: 0,
            sequence: 3,
            bytes: expiredCiphertext
        )
        XCTAssertEqual(
            try engine.receive(
                expiredRequestFrame,
                now: fixture.receivedAt.addingTimeInterval(121)
            ).event,
            .signingRequest(.raw(
                domain: "uranai.contract-call.v1",
                bytes: expiredBytes
            ))
        )
        let expiredResultFrame = try engine.approvePendingSignature(
            account: account,
            signer: { _ in
                XCTFail("An expired request must never invoke the signer")
                return Data()
            },
            now: fixture.receivedAt.addingTimeInterval(241)
        )
        let decodedExpiredResult = try
            IrohaConnectWire.decodeFrame(expiredResultFrame)
        guard case let .ciphertext(_, expiredResultCiphertext) =
            decodedExpiredResult.kind else {
            return XCTFail("Expected an encrypted expiration result")
        }
        let expiredResultPlaintext = try IrohaConnectCrypto.decrypt(
            ciphertext: expiredResultCiphertext,
            key: keys.walletToApp,
            sid: launch.sid,
            direction: 1,
            sequence: 3
        )
        let (expiredResultSequence, expiredResultPayload) = try
            IrohaConnectWire.decodeEnvelope(expiredResultPlaintext)
        XCTAssertEqual(expiredResultSequence, 3)
        guard case let .signError(code, _) = expiredResultPayload else {
            return XCTFail("Expected an expiration error")
        }
        XCTAssertEqual(code, "REQUEST_EXPIRED")
        XCTAssertThrowsError(
            try engine.receive(
                requestFrame,
                now: fixture.receivedAt.addingTimeInterval(241)
            )
        )
        XCTAssertTrue(engine.isClosed)
    }

    func testEnvelopeFailsClosedOnTamperExpiryAndWrongDomain() throws {
        let fixture = try makeFixture()
        let launch = try IrohaConnectLaunch.parse(
            fixture.url,
            receivedAt: fixture.receivedAt
        )
        let walletAgreement = try Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: Data(repeating: 0x23, count: 32)
        )
        var keys = try IrohaConnectCrypto.directionKeys(
            walletPrivateKey: walletAgreement,
            appPublicKey: launch.appPublicKey,
            sid: launch.sid
        )
        defer { keys.wipe() }
        let envelope = try IrohaConnectWire.encodeEnvelope(
            sequence: 7,
            payload: .display(title: "Review", body: "Exact payload")
        )
        let ciphertext = try IrohaConnectCrypto.encrypt(
            envelope: envelope,
            key: keys.appToWallet,
            sid: launch.sid,
            direction: 0,
            sequence: 7
        )
        XCTAssertEqual(
            try IrohaConnectCrypto.decrypt(
                ciphertext: ciphertext,
                key: keys.appToWallet,
                sid: launch.sid,
                direction: 0,
                sequence: 7
            ),
            envelope
        )
        var tampered = ciphertext
        tampered[tampered.index(before: tampered.endIndex)] ^= 1
        XCTAssertThrowsError(
            try IrohaConnectCrypto.decrypt(
                ciphertext: tampered,
                key: keys.appToWallet,
                sid: launch.sid,
                direction: 0,
                sequence: 7
            )
        )

        let expiredEngine = IrohaConnectSessionEngine(launch: launch)
        XCTAssertThrowsError(
            try expiredEngine.receive(
                Data(),
                now: fixture.receivedAt.addingTimeInterval(121)
            )
        ) { error in
            XCTAssertEqual(error as? IrohaConnectError, .expired)
        }

        let raw = IrohaConnectSigningRequest.raw(
            domain: "uranai.contract-call.v1",
            bytes: Data([1])
        )
        XCTAssertFalse(
            IrohaConnectPermissions(
                methods: ["sign_raw"],
                events: [],
                resources: ["different.domain"]
            ).permits(raw)
        )
    }

    private func makeFixture() throws -> (
        url: URL,
        sid: Data,
        appPrivate: Curve25519.KeyAgreement.PrivateKey,
        receivedAt: Date
    ) {
        let network = try IrohaConnectNetworkLiteral(
            IrohaConnectLaunch.tairaNetworkId
        )
        let appPrivate = try Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: Data(repeating: 0x11, count: 32)
        )
        let nonce = Data((0 ..< 16).map { UInt8($0) })
        var sidInput = Data("iroha-connect|sid|".utf8)
        sidInput.append(network.bytes)
        sidInput.append(appPrivate.publicKey.rawRepresentation)
        sidInput.append(nonce)
        let sid = try sidInput.blake2b32()
        var components = URLComponents()
        components.scheme = "irohaconnect"
        components.host = "connect"
        components.queryItems = [
            URLQueryItem(name: "sid", value: sid.base64URL),
            URLQueryItem(name: "network_id", value: network.literal),
            URLQueryItem(
                name: "app_pk",
                value: appPrivate.publicKey.rawRepresentation.base64URL
            ),
            URLQueryItem(name: "nonce", value: nonce.base64URL),
            URLQueryItem(name: "node", value: "https://taira.sora.org"),
            URLQueryItem(name: "v", value: "1"),
            URLQueryItem(name: "role", value: "wallet"),
            URLQueryItem(
                name: "token",
                value: Data(repeating: 0xA1, count: 32).base64URL
            ),
            URLQueryItem(
                name: "relay",
                value: Data(repeating: 0xB2, count: 32).base64URL
            ),
        ]
        return (
            try XCTUnwrap(components.url),
            sid,
            appPrivate,
            Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
