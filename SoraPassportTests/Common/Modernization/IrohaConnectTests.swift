// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import CryptoKit
import SSFUtils
import XCTest
@testable import SoraPassport

final class IrohaConnectTests: XCTestCase {
    func testSigningReviewRequiresCompleteReadableText() {
        let complete = "Authorize a request\nDomain: example.app\nAmount: 12 XOR"
        XCTAssertEqual(IrohaConnectSigningReview(request: .raw(domain: "example.app", bytes: Data(complete.utf8))).readableMessage, complete)
        XCTAssertTrue(IrohaConnectSigningReview(request: .raw(domain: "example.app", bytes: Data(repeating: 65, count: 4096))).canSign)
        let unreadable = [Data(), Data([0xFF]), Data("   ".utf8), Data("pay\u{202E}123".utf8),
                          Data("pay\u{200B}123".utf8), Data("pay\0more".utf8), Data(repeating: 65, count: 4097)]
        for bytes in unreadable {
            XCTAssertFalse(IrohaConnectSigningReview(request: .raw(domain: "example.app", bytes: bytes)).canSign)
        }
        XCTAssertFalse(IrohaConnectSigningReview(request: .transaction(bytes: Data(complete.utf8))).canSign,
                       "Readable-looking bytes are not a decoded transaction")
    }

    func testUninterpretableRequestsNeverInvokeSigner() throws {
        let requests: [IrohaConnectSigningRequest] = [
            .transaction(bytes: Data("Transfer 1 XOR".utf8)),
            .raw(domain: "uranai.contract-call.v1", bytes: Data("Hidden\u{202E}text".utf8))
        ]
        for request in requests {
            let fixture = try makeFixture()
            let launch = try IrohaConnectLaunch.parse(fixture.url, receivedAt: fixture.receivedAt)
            let engine = IrohaConnectSessionEngine(launch: launch)
            let permissions: IrohaConnectPermissions
            switch request {
            case .transaction:
                permissions = IrohaConnectPermissions(methods: ["sign_transaction"], events: [], resources: nil)
            case let .raw(domain, _):
                permissions = IrohaConnectPermissions(methods: ["sign_raw"], events: [], resources: [domain])
            }
            _ = try engine.receive(IrohaConnectWire.encodeOpenForTesting(sid: launch.sid, appPublicKey: launch.appPublicKey,
                network: launch.network, metadata: nil, permissions: permissions), now: fixture.receivedAt)
            let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 0x42, count: 32))
            let account = IrohaConnectWalletContext(walletId: "wallet-fixture", networkId: .taira,
                accountId: "fixture-account-i105", publicKey: signingKey.publicKey.rawRepresentation)
            let seed = Data((1 ... 32).map { UInt8($0) })
            _ = try engine.approve(account: account, agreementPrivateKey: seed,
                signer: { try signingKey.signature(for: $0) }, now: fixture.receivedAt)
            var keys = try IrohaConnectCrypto.directionKeys(
                walletPrivateKey: Curve25519.KeyAgreement.PrivateKey(rawRepresentation: seed),
                appPublicKey: launch.appPublicKey, sid: launch.sid)
            defer { keys.wipe() }
            let envelope = try IrohaConnectWire.encodeEnvelope(sequence: 2, payload: .signRequest(request))
            let encrypted = try IrohaConnectCrypto.encrypt(envelope: envelope, key: keys.appToWallet,
                sid: launch.sid, direction: 0, sequence: 2)
            _ = try engine.receive(IrohaConnectWire.encodeCiphertext(sid: launch.sid, direction: 0, sequence: 2, bytes: encrypted), now: fixture.receivedAt)
            let result = try engine.approvePendingSignature(account: account, signer: { _ in
                XCTFail("An uninterpretable request must not reach private-key signing")
                return Data()
            }, now: fixture.receivedAt)
            let frame = try IrohaConnectWire.decodeFrame(result)
            guard case let .ciphertext(_, ciphertext) = frame.kind else { return XCTFail("Expected encrypted rejection") }
            let plain = try IrohaConnectCrypto.decrypt(ciphertext: ciphertext, key: keys.walletToApp,
                sid: launch.sid, direction: 1, sequence: 2)
            let (_, payload) = try IrohaConnectWire.decodeEnvelope(plain)
            guard case let .signError(code, _) = payload else { return XCTFail("Expected readable-review rejection") }
            XCTAssertEqual(code, "UNREADABLE_REQUEST")
            XCTAssertNil(engine.pendingRequest)
            XCTAssertFalse(engine.isClosed)
        }
    }

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

extension IrohaConnectTests {
    private func proof(_ values: [String] = ["example.app", "https://example.app/sign-in", "Sign in to the public fixture", "2026-10-28T00:00:00Z", "public-nonce"]) -> IrohaConnectSignInProof {
        .init(domain: values[0], uri: values[1], statement: values[2], issuedAt: values[3], nonce: values[4])
    }
    func testApprovalRoundTripPreservesTheEntireSignInProofAndSignature() throws {
        let fixture = try makeFixture(), key = Data(repeating: 2, count: 32), signature = Data(repeating: 3, count: 64)
        let permissions = IrohaConnectPermissions(methods: ["sign_raw"], events: [], resources: ["example.app"])
        let bytes = try IrohaConnectWire.encodeApprove(sid: fixture.sid, sequence: 2, walletKey: key,
            accountId: "public-fixture-account", permissions: permissions, proof: proof(), signature: signature)
        let decoded = try IrohaConnectWire.decodeFrame(bytes)
        XCTAssertEqual(decoded.sid, fixture.sid); XCTAssertEqual(decoded.sequence, 2); XCTAssertEqual(decoded.direction, 1)
        XCTAssertEqual(decoded.kind, .control(.approve(walletPublicKey: key, accountId: "public-fixture-account",
            permissions: permissions, proof: proof(), signature: signature)))
    }
    func testApprovalSignaturePreimageBindsEverySignInProofField() throws {
        let fixture = try makeFixture(), launch = try IrohaConnectLaunch.parse(fixture.url, receivedAt: fixture.receivedAt)
        let original = ["example.app", "https://example.app/sign-in", "Sign in to the public fixture", "2026-10-28T00:00:00Z", "public-nonce"]
        func preimage(_ proof: IrohaConnectSignInProof?) throws -> Data {
            try IrohaConnectWire.approvalPreimage(launch: launch, walletKey: Data(repeating: 2, count: 32),
                accountId: "public-fixture-account", permissions: nil, proof: proof)
        }
        let expected = try preimage(proof(original)); XCTAssertNotEqual(expected, try preimage(nil))
        for index in original.indices {
            var changed = original; changed[index] += "-changed"
            XCTAssertNotEqual(expected, try preimage(proof(changed)), "Proof field \(index) must be signed")
        }
    }
    func testApprovalRejectsAnOversizedProofFieldDuringDecode() throws {
        let fixture = try makeFixture()
        for (index, limit) in [(0, 512), (1, 4096), (2, 8192), (3, 256), (4, 512)] {
            var fields = ["example.app", "https://example.app/sign-in", "Statement", "2026-10-28", "nonce"]
            fields[index] = String(repeating: "x", count: limit + 1)
            let bytes = try IrohaConnectWire.encodeApprove(sid: fixture.sid, sequence: 1,
                walletKey: Data(repeating: 2, count: 32), accountId: "fixture", permissions: nil,
                proof: proof(fields), signature: Data(repeating: 3, count: 64))
            XCTAssertThrowsError(try IrohaConnectWire.decodeFrame(bytes))
        }
    }
    func testCloseFramePreservesReasonRoleCodeAndRetryPolicy() throws {
        let fixture = try makeFixture()
        for retryable in [false, true] {
            let decoded = try IrohaConnectWire.decodeFrame(IrohaConnectWire.encodeClose(sid: fixture.sid,
                sequence: 42, code: 409, reason: "Public fixture closed", retryable: retryable))
            XCTAssertEqual(decoded.sequence, 42); XCTAssertEqual(decoded.direction, 1)
            XCTAssertEqual(decoded.kind, .control(.close(who: 1, code: 409, reason: "Public fixture closed", retryable: retryable)))
        }
    }
    func testCloseFrameRejectsAnOversizedReasonAndTruncatedPayload() throws {
        let fixture = try makeFixture()
        let large = IrohaConnectWire.encodeClose(sid: fixture.sid, sequence: 2, code: 400,
            reason: String(repeating: "x", count: 4097), retryable: false)
        XCTAssertThrowsError(try IrohaConnectWire.decodeFrame(large))
        let valid = IrohaConnectWire.encodeClose(sid: fixture.sid, sequence: 2, code: 400, reason: "Closed", retryable: false)
        XCTAssertThrowsError(try IrohaConnectWire.decodeFrame(Data(valid.dropLast())))
    }
    func testPongPreservesTheMaximumNonceWithoutNarrowing() throws {
        let fixture = try makeFixture()
        let decoded = try IrohaConnectWire.decodeFrame(IrohaConnectWire.encodePong(sid: fixture.sid, sequence: 3, nonce: UInt64.max))
        XCTAssertEqual(decoded.kind, .control(.pong(UInt64.max))); XCTAssertEqual(decoded.sequence, 3)
    }
    func testWireRejectsFramesAboveTheProtocolSizeLimit() {
        XCTAssertThrowsError(try IrohaConnectWire.decodeFrame(Data(repeating: 0, count: IrohaConnectFrame.maximumBytes + 1)))
    }
    func testNetworkLiteralRejectsInvalidLengthMarkerAndChecksum() throws {
        for length in [0, 1, 31, 33] {
            XCTAssertThrowsError(try IrohaConnectNetworkLiteral(bytes: Data(repeating: 1, count: length)))
        }
        XCTAssertThrowsError(try IrohaConnectNetworkLiteral(bytes: Data(repeating: 2, count: 32)))
        XCTAssertThrowsError(try IrohaConnectNetworkLiteral(IrohaConnectLaunch.tairaNetworkId.lowercased()))
        XCTAssertThrowsError(try IrohaConnectNetworkLiteral(String(IrohaConnectLaunch.tairaNetworkId.dropLast()) + "0"))
        let literal = try IrohaConnectNetworkLiteral(bytes: Data(repeating: 1, count: 32))
        XCTAssertEqual(try IrohaConnectNetworkLiteral(literal.literal), literal)
    }
    private func changingQuery(_ name: String, value: String?) throws -> URL {
        var parts = URLComponents(url: try makeFixture().url, resolvingAgainstBaseURL: false)!
        parts.queryItems = parts.queryItems?.map { $0.name == name ? URLQueryItem(name: name, value: value) : $0 }
        return try XCTUnwrap(parts.url)
    }
    func testLaunchRejectsEmptyMissingAndWhitespaceQueryValues() throws {
        for value in [nil, "", " wallet", "wallet "] as [String?] {
            XCTAssertThrowsError(try IrohaConnectLaunch.parse(changingQuery("role", value: value)))
        }
        var parts = URLComponents(url: try makeFixture().url, resolvingAgainstBaseURL: false)!
        parts.queryItems?.removeAll { $0.name == "relay" }
        XCTAssertThrowsError(try IrohaConnectLaunch.parse(XCTUnwrap(parts.url)))
    }
    func testLaunchRejectsAllZeroAgreementKeysAndNonces() throws {
        for (name, length) in [("app_pk", 32), ("nonce", 16)] {
            XCTAssertThrowsError(try IrohaConnectLaunch.parse(changingQuery(name, value: Data(repeating: 0, count: length).base64URL)))
        }
    }
    func testLaunchRejectsPaddedOrShortTokensBeforeAnyConnection() throws {
        for name in ["token", "relay"] {
            for value in [Data(repeating: 1, count: 32).base64EncodedString(), Data(repeating: 1, count: 31).base64URL, "a+b/"] {
                XCTAssertThrowsError(try IrohaConnectLaunch.parse(changingQuery(name, value: value)))
            }
        }
    }
    func testLaunchRequiresAnExactTrustedHttpsOrigin() throws {
        for node in ["http://taira.sora.org", "https://taira.sora.org/path", "https://user@taira.sora.org", "https://taira.sora.org?x=1", "https://taira.sora.org#fragment", "https://untrusted.invalid"] {
            XCTAssertThrowsError(try IrohaConnectLaunch.parse(changingQuery("node", value: node)))
        }
    }
    func testLaunchRejectsUnpinnedMinamotoBuildConfiguration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "test.unpinned.connect"], format: .xml, options: 0)
        try plist.write(to: directory.appendingPathComponent("Info.plist"))
        let bundle = try XCTUnwrap(Bundle(url: directory))
        XCTAssertThrowsError(try IrohaConnectLaunch.parse(changingQuery("node", value: "https://minamoto.sora.org"), bundle: bundle)) {
            XCTAssertEqual($0 as? IrohaConnectError, .unsupportedNetwork)
        }
    }
    func testPermissionsRejectEventsAndInvalidResourceScopes() {
        let bad = [IrohaConnectPermissions(methods: [], events: ["transfer"], resources: nil),
            .init(methods: ["sign_raw"], events: [], resources: nil),
            .init(methods: ["sign_raw"], events: [], resources: []),
            .init(methods: ["sign_transaction"], events: [], resources: ["example.app"])]
        for permissions in bad { XCTAssertThrowsError(try permissions.validate()) }
        for resources in [[""], [" domain"], ["domain\n"], ["same", "same"], [String(repeating: "a", count: 257)], (0...32).map { "domain-\($0)" }] {
            XCTAssertThrowsError(try IrohaConnectPermissions(methods: ["sign_raw"], events: [], resources: resources).validate())
        }
    }
}
