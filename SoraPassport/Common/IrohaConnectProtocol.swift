// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import Foundation
import SSFUtils

enum IrohaConnectError: LocalizedError, Equatable {
    case invalidURI(String)
    case unsupportedNetwork
    case protocolViolation(String)
    case expired
    case authenticationFailed
    case walletUnavailable
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case let .invalidURI(reason):
            return "Invalid IrohaConnect request: \(reason)"
        case .unsupportedNetwork:
            return "This IrohaConnect network is not pinned by this wallet build."
        case let .protocolViolation(reason):
            return "IrohaConnect closed the request: \(reason)"
        case .expired:
            return "This IrohaConnect request expired. Scan a new code."
        case .authenticationFailed:
            return "Wallet authentication was not completed."
        case .walletUnavailable:
            return "A verified SORA 3 signing account is not available."
        case .connectionFailed:
            return "The secure connection could not be established."
        }
    }
}

struct IrohaConnectNetworkLiteral: Equatable {
    let literal: String
    let bytes: Data

    init(_ value: String) throws {
        let pattern = #"^hash:([0-9A-F]{64})#([0-9A-F]{4})$"#
        guard
            let expression = try? NSRegularExpression(pattern: pattern),
            let match = expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
            ),
            match.range.location != NSNotFound,
            let bodyRange = Range(match.range(at: 1), in: value),
            let checksumRange = Range(match.range(at: 2), in: value)
        else {
            throw IrohaConnectError.invalidURI(
                "network_id is not a canonical checksummed NetworkId"
            )
        }
        let body = String(value[bodyRange])
        let checksum = String(value[checksumRange])
        guard
            Self.checksum(tag: "hash", body: body) == checksum,
            let decoded = Data(strictHex: body),
            decoded.count == 32,
            (decoded[decoded.index(before: decoded.endIndex)] & 1) == 1
        else {
            throw IrohaConnectError.invalidURI(
                "network_id checksum or marker bit is invalid"
            )
        }
        literal = value
        bytes = decoded
    }

    init(bytes: Data) throws {
        guard bytes.count == 32, (bytes[bytes.index(before: bytes.endIndex)] & 1) == 1 else {
            throw IrohaConnectError.protocolViolation("invalid NetworkId bytes")
        }
        let body = bytes.hexString.uppercased()
        literal = "hash:\(body)#\(Self.checksum(tag: "hash", body: body))"
        self.bytes = bytes
    }

    private static func checksum(tag: String, body: String) -> String {
        var crc: UInt16 = 0xFFFF
        for byte in Data("\(tag):\(body)".utf8) {
            crc ^= UInt16(byte) << 8
            for _ in 0 ..< 8 {
                crc = (crc & 0x8000) != 0
                    ? (crc &<< 1) ^ 0x1021
                    : crc &<< 1
            }
        }
        return String(format: "%04X", crc)
    }
}

struct IrohaConnectLaunch: Equatable {
    static let tairaNetworkId =
        "hash:82531CE8EAE8BFF6BEECA4698BFD13A3BC8BEC5F0EE0D23D428C97FC17AB0F3B#3E94"

    let originalURL: URL
    let sid: Data
    let sidText: String
    let network: IrohaConnectNetworkLiteral
    let appPublicKey: Data
    let nonce: Data
    let node: URL
    let networkId: NetworkId
    let token: String
    let relayToken: String
    let receivedAt: Date

    var webSocketURL: URL {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = node.host
        components.port = node.port
        components.path = "/v1/connect/ws"
        components.queryItems = [
            URLQueryItem(name: "sid", value: sidText),
            URLQueryItem(name: "role", value: "wallet"),
        ]
        return components.url!
    }

    var webSocketProtocol: String {
        "iroha-connect.token.v1." + Data(token.utf8).base64URLString
    }

    static func parse(
        _ url: URL,
        bundle: Bundle = .main,
        receivedAt: Date = Date()
    ) throws -> IrohaConnectLaunch {
        guard url.absoluteString == url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw IrohaConnectError.invalidURI("surrounding whitespace is not allowed")
        }
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            ["iroha", "irohaconnect"].contains(components.scheme?.lowercased() ?? ""),
            components.host == "connect",
            components.user == nil,
            components.password == nil,
            components.port == nil,
            components.path.isEmpty,
            components.fragment == nil
        else {
            throw IrohaConnectError.invalidURI(
                "expected iroha://connect or irohaconnect://connect"
            )
        }

        let expectedNames: Set<String> = [
            "sid", "network_id", "app_pk", "nonce", "node", "v", "role", "token", "relay",
        ]
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard expectedNames.contains(item.name) else {
                throw IrohaConnectError.invalidURI("unsupported parameter \(item.name)")
            }
            guard values[item.name] == nil else {
                throw IrohaConnectError.invalidURI("duplicate parameter \(item.name)")
            }
            guard let value = item.value, !value.isEmpty, value == value.trimmingCharacters(in: .whitespacesAndNewlines) else {
                throw IrohaConnectError.invalidURI("empty parameter \(item.name)")
            }
            values[item.name] = value
        }
        guard Set(values.keys) == expectedNames else {
            throw IrohaConnectError.invalidURI("all current v1 parameters are required")
        }
        guard values["v"] == "1", values["role"] == "wallet" else {
            throw IrohaConnectError.invalidURI("only current wallet-role v=1 requests are supported")
        }
        let network = try IrohaConnectNetworkLiteral(values["network_id"]!)
        let appPublicKey = try Data(canonicalBase64URL: values["app_pk"]!, length: 32, label: "app_pk")
        let nonce = try Data(canonicalBase64URL: values["nonce"]!, length: 16, label: "nonce")
        let sid = try Data(canonicalBase64URL: values["sid"]!, length: 32, label: "sid")
        guard appPublicKey.contains(where: { $0 != 0 }),
              nonce.contains(where: { $0 != 0 }) else {
            throw IrohaConnectError.invalidURI("app_pk and nonce must not be all zero")
        }
        let token = try Self.token(values["token"]!, name: "token")
        let relayToken = try Self.token(values["relay"]!, name: "relay")
        let node = try Self.canonicalNode(values["node"]!)

        let resolvedNetwork: NetworkId
        let expectedNetworkLiteral: String
        switch node.absoluteString {
        case "https://taira.sora.org":
            resolvedNetwork = .taira
            expectedNetworkLiteral = tairaNetworkId
        case "https://minamoto.sora.org":
            resolvedNetwork = .minamoto
            guard
                let configured = bundle.object(forInfoDictionaryKey: "SoraMinamotoNetworkId") as? String,
                !configured.isEmpty,
                (try? IrohaConnectNetworkLiteral(configured)) != nil
            else {
                throw IrohaConnectError.unsupportedNetwork
            }
            expectedNetworkLiteral = configured
        default:
            throw IrohaConnectError.unsupportedNetwork
        }
        guard network.literal == expectedNetworkLiteral else {
            throw IrohaConnectError.invalidURI("network_id does not match the pinned node")
        }

        var sidPreimage = Data("iroha-connect|sid|".utf8)
        sidPreimage.append(network.bytes)
        sidPreimage.append(appPublicKey)
        sidPreimage.append(nonce)
        let expectedSID: Data
        do {
            expectedSID = try sidPreimage.blake2b32()
        } catch {
            throw IrohaConnectError.protocolViolation("BLAKE2b is unavailable")
        }
        guard sid == expectedSID else {
            throw IrohaConnectError.invalidURI("sid does not bind the advertised session")
        }

        return IrohaConnectLaunch(
            originalURL: url,
            sid: sid,
            sidText: values["sid"]!,
            network: network,
            appPublicKey: appPublicKey,
            nonce: nonce,
            node: node,
            networkId: resolvedNetwork,
            token: token,
            relayToken: relayToken,
            receivedAt: receivedAt
        )
    }

    private static func token(_ value: String, name: String) throws -> String {
        guard
            value.range(of: #"^[A-Za-z0-9_-]{43}$"#, options: .regularExpression) != nil,
            (try? Data(canonicalBase64URL: value, length: 32, label: name)) != nil
        else {
            throw IrohaConnectError.invalidURI("\(name) must be a canonical 32-byte token")
        }
        return value
    }

    private static func canonicalNode(_ value: String) throws -> URL {
        guard
            let components = URLComponents(string: value),
            components.scheme == "https",
            components.user == nil,
            components.password == nil,
            components.port == nil,
            components.path.isEmpty,
            components.query == nil,
            components.fragment == nil,
            let host = components.host,
            host == host.lowercased(),
            let url = components.url,
            url.absoluteString == value
        else {
            throw IrohaConnectError.invalidURI("node must be an exact trusted HTTPS origin")
        }
        return url
    }
}

struct IrohaConnectPermissions: Equatable {
    let methods: [String]
    let events: [String]
    let resources: [String]?

    func validate() throws {
        let supportedMethods: Set<String> = ["sign_raw", "sign_transaction"]
        guard methods.count <= 2, Set(methods).count == methods.count,
              methods.allSatisfy(supportedMethods.contains) else {
            throw IrohaConnectError.protocolViolation("unsupported or duplicate signing permission")
        }
        guard events.isEmpty else {
            throw IrohaConnectError.protocolViolation("event permissions are not supported by this wallet")
        }
        if let resources {
            guard
                resources.count <= 32,
                Set(resources).count == resources.count,
                resources.allSatisfy({ value in
                    !value.isEmpty &&
                        value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
                        value.utf8.count <= 256 &&
                        !value.unicodeScalars.contains(where: {
                            CharacterSet.controlCharacters.contains($0)
                        })
                })
            else {
                throw IrohaConnectError.protocolViolation("invalid raw-signing resources")
            }
        }
        if methods.contains("sign_raw") {
            guard let resources, !resources.isEmpty else {
                throw IrohaConnectError.protocolViolation(
                    "raw signing requires explicit domain resources"
                )
            }
        }
        if methods.contains("sign_transaction"), resources != nil {
            throw IrohaConnectError.protocolViolation(
                "transaction signing cannot use a raw resource scope"
            )
        }
    }

    func permits(_ request: IrohaConnectSigningRequest) -> Bool {
        switch request {
        case let .raw(domain, _):
            return methods.contains("sign_raw") && (resources?.contains(domain) == true)
        case .transaction:
            return methods.contains("sign_transaction") && resources == nil
        }
    }
}

struct IrohaConnectAppMetadata: Equatable {
    let name: String
    let url: String?
    let iconHash: String?
}

struct IrohaConnectSignInProof: Equatable {
    let domain: String
    let uri: String
    let statement: String
    let issuedAt: String
    let nonce: String
}

enum IrohaConnectSigningRequest: Equatable {
    case raw(domain: String, bytes: Data)
    case transaction(bytes: Data)

    var bytes: Data {
        switch self {
        case let .raw(_, bytes), let .transaction(bytes): return bytes
        }
    }
}

enum IrohaConnectEnvelopePayload: Equatable {
    case close(who: UInt32, code: UInt16, reason: String, retryable: Bool)
    case reject(code: UInt16, codeId: String, reason: String)
    case signRequest(IrohaConnectSigningRequest)
    case signResult(signature: Data)
    case signError(code: String, message: String)
    case display(title: String, body: String)
}

enum IrohaConnectControl: Equatable {
    case open(
        appPublicKey: Data,
        metadata: IrohaConnectAppMetadata?,
        network: IrohaConnectNetworkLiteral,
        permissions: IrohaConnectPermissions?
    )
    case approve(
        walletPublicKey: Data,
        accountId: String,
        permissions: IrohaConnectPermissions?,
        proof: IrohaConnectSignInProof?,
        signature: Data
    )
    case reject(code: UInt16, codeId: String, reason: String)
    case close(who: UInt32, code: UInt16, reason: String, retryable: Bool)
    case ping(UInt64)
    case pong(UInt64)
    case serverEvent(height: UInt64, entryHash: String, proofsJSON: String)
}

enum IrohaConnectFrameKind: Equatable {
    case control(IrohaConnectControl)
    case ciphertext(direction: UInt32, bytes: Data)
}

struct IrohaConnectFrame: Equatable {
    static let maximumBytes = 1_048_576
    let sid: Data
    let direction: UInt32
    let sequence: UInt64
    let kind: IrohaConnectFrameKind
}

enum IrohaConnectWire {
    static let envelopeSchema = Data([
        0x69, 0x47, 0xAF, 0xE3, 0xE8, 0xA8, 0x54, 0x46,
        0xD6, 0xA3, 0xEE, 0x7B, 0xB1, 0xA3, 0x7C, 0x0A,
    ])

    static func decodeFrame(_ data: Data) throws -> IrohaConnectFrame {
        guard data.count <= IrohaConnectFrame.maximumBytes else {
            throw IrohaConnectError.protocolViolation("frame is too large")
        }
        var reader = Reader(data)
        let sid = try reader.field("frame.sid", maximum: 32)
        guard sid.count == 32 else { throw violation("frame SID must be 32 bytes") }
        let direction = try Reader(try reader.field("frame.direction", maximum: 4)).u32("frame.direction")
        guard direction <= 1 else { throw violation("invalid frame direction") }
        let sequence = try Reader(try reader.field("frame.sequence", maximum: 8)).u64("frame.sequence")
        var kindReader = Reader(try reader.field("frame.kind", maximum: IrohaConnectFrame.maximumBytes))
        try reader.finish("frame")
        let tag = try kindReader.u32("frame.kind.tag")
        let bodyLength = try kindReader.length("frame.kind.length", maximum: IrohaConnectFrame.maximumBytes)
        let body = try kindReader.bytes(bodyLength, "frame.kind.body")
        try kindReader.finish("frame.kind")
        let kind: IrohaConnectFrameKind
        switch tag {
        case 0:
            kind = .control(try decodeControl(body))
        case 1:
            var cipher = Reader(body)
            let innerDirection = try Reader(try cipher.field("ciphertext.direction", maximum: 4)).u32("ciphertext.direction")
            let bytes = try decodeByteVector(try cipher.field("ciphertext.bytes", maximum: IrohaConnectFrame.maximumBytes), label: "ciphertext.bytes", maximum: IrohaConnectFrame.maximumBytes)
            try cipher.finish("ciphertext")
            guard innerDirection == direction else { throw violation("ciphertext direction mismatch") }
            kind = .ciphertext(direction: innerDirection, bytes: bytes)
        default:
            throw violation("unsupported frame kind")
        }
        return IrohaConnectFrame(sid: sid, direction: direction, sequence: sequence, kind: kind)
    }

    static func encodeApprove(
        sid: Data,
        sequence: UInt64,
        walletKey: Data,
        accountId: String,
        permissions: IrohaConnectPermissions?,
        proof: IrohaConnectSignInProof? = nil,
        signature: Data
    ) throws -> Data {
        guard walletKey.count == 32, signature.count == 64 else { throw violation("invalid approval key or signature") }
        let signaturePayload = structure([
            Data([0]),
            byteVector(signature),
        ])
        let body = structure([
            walletKey,
            string(accountId),
            option(permissions.map(encodePermissions)),
            option(proof.map(encodeProof)),
            signaturePayload,
        ])
        return frame(sid: sid, direction: 1, sequence: sequence, tag: 0, body: tagged(1, body))
    }

    static func encodeReject(
        sid: Data,
        sequence: UInt64,
        code: UInt16,
        codeId: String,
        reason: String
    ) -> Data {
        let body = structure([u16(code), string(codeId), string(reason)])
        return frame(sid: sid, direction: 1, sequence: sequence, tag: 0, body: tagged(2, body))
    }

    static func encodeClose(
        sid: Data,
        sequence: UInt64,
        code: UInt16,
        reason: String,
        retryable: Bool
    ) -> Data {
        let body = structure([u32(1), u16(code), string(reason), Data([retryable ? 1 : 0])])
        return frame(sid: sid, direction: 1, sequence: sequence, tag: 0, body: tagged(3, body))
    }

    static func encodePong(sid: Data, sequence: UInt64, nonce: UInt64) -> Data {
        frame(sid: sid, direction: 1, sequence: sequence, tag: 0, body: tagged(5, structure([u64(nonce)])))
    }

    static func encodeServerEventForTesting(
        sid: Data,
        sequence: UInt64,
        height: UInt64,
        entryHash: String,
        proofsJSON: String
    ) -> Data {
        let eventBody = structure([
            u64(height),
            string(entryHash),
            string(proofsJSON),
        ])
        let event = tagged(0, eventBody)
        return frame(
            sid: sid,
            direction: 0,
            sequence: sequence,
            tag: 0,
            body: tagged(6, structure([event]))
        )
    }

    static func encodeCiphertext(
        sid: Data,
        direction: UInt32 = 1,
        sequence: UInt64,
        bytes: Data
    ) -> Data {
        let body = structure([u32(direction), byteVector(bytes)])
        return frame(sid: sid, direction: direction, sequence: sequence, tag: 1, body: body)
    }

    static func decodeEnvelope(_ data: Data) throws -> (UInt64, IrohaConnectEnvelopePayload) {
        guard data.count >= 40, data.prefix(4) == Data("NRT0".utf8) else { throw violation("invalid envelope magic") }
        guard data[4] == 0, data[5] == 0, Data(data[6 ..< 22]) == envelopeSchema,
              data[22] == 0, data[39] == 0 else { throw violation("unsupported envelope layout") }
        let payloadLength = try Reader(Data(data[23 ..< 31])).u64("envelope.length")
        let checksum = try Reader(Data(data[31 ..< 39])).u64("envelope.checksum")
        let payload = Data(data.dropFirst(40))
        guard UInt64(payload.count) == payloadLength, crc64XZ(payload) == checksum else {
            throw violation("envelope length or checksum mismatch")
        }
        var reader = Reader(payload)
        let sequence = try Reader(try reader.field("envelope.sequence", maximum: 8)).u64("envelope.sequence")
        var value = Reader(try reader.field("envelope.payload", maximum: 524_288))
        try reader.finish("envelope")
        let tag = try value.u32("envelope.payload.tag")
        let decoded: IrohaConnectEnvelopePayload
        switch tag {
        case 0:
            var control = Reader(try value.field("envelope.control", maximum: 16_384))
            let controlTag = try control.u32("envelope.control.tag")
            if controlTag == 0 {
                let who = try Reader(try control.field("close.who", maximum: 4)).u32("close.who")
                guard who <= 1 else { throw violation("encrypted close role is invalid") }
                let code = try Reader(try control.field("close.code", maximum: 2)).u16("close.code")
                let reason = try decodeString(try control.field("close.reason", maximum: 4_096), label: "close.reason")
                let retry = try decodeBool(try control.field("close.retry", maximum: 1), label: "close.retry")
                decoded = .close(who: who, code: code, reason: reason, retryable: retry)
            } else if controlTag == 1 {
                let code = try Reader(try control.field("reject.code", maximum: 2)).u16("reject.code")
                let codeId = try decodeString(try control.field("reject.code_id", maximum: 256), label: "reject.code_id")
                let reason = try decodeString(try control.field("reject.reason", maximum: 4_096), label: "reject.reason")
                decoded = .reject(code: code, codeId: codeId, reason: reason)
            } else {
                throw violation("unsupported encrypted control")
            }
            try control.finish("envelope.control")
        case 1:
            let domain = try decodeString(try value.field("sign_raw.domain", maximum: 512), label: "sign_raw.domain")
            let bytes = try decodeByteVector(try value.field("sign_raw.bytes", maximum: 524_296), label: "sign_raw.bytes", maximum: 524_288)
            decoded = .signRequest(.raw(domain: domain, bytes: bytes))
        case 2:
            let bytes = try decodeByteVector(try value.field("sign_tx.bytes", maximum: 524_296), label: "sign_tx.bytes", maximum: 524_288)
            decoded = .signRequest(.transaction(bytes: bytes))
        case 3:
            decoded = .signResult(signature: try decodeWalletSignature(try value.field("sign_result.signature", maximum: 128)))
        case 4:
            let code = try decodeString(try value.field("sign_error.code", maximum: 256), label: "sign_error.code")
            let message = try decodeString(try value.field("sign_error.message", maximum: 4_096), label: "sign_error.message")
            decoded = .signError(code: code, message: message)
        case 5:
            let title = try decodeString(try value.field("display.title", maximum: 512), label: "display.title")
            let body = try decodeString(try value.field("display.body", maximum: 8_192), label: "display.body")
            decoded = .display(title: title, body: body)
        default:
            throw violation("unsupported encrypted payload")
        }
        try value.finish("envelope.payload")
        return (sequence, decoded)
    }

    static func encodeEnvelope(sequence: UInt64, payload: IrohaConnectEnvelopePayload) throws -> Data {
        let encoded: Data
        switch payload {
        case let .close(who, code, reason, retryable):
            let control = u32(0) + field(u32(who)) + field(u16(code)) + field(string(reason)) + field(Data([retryable ? 1 : 0]))
            encoded = u32(0) + field(control)
        case let .reject(code, codeId, reason):
            let control = u32(1) + field(u16(code)) + field(string(codeId)) + field(string(reason))
            encoded = u32(0) + field(control)
        case let .signRequest(.raw(domain, bytes)):
            encoded = u32(1) + field(string(domain)) + field(byteVector(bytes))
        case let .signRequest(.transaction(bytes)):
            encoded = u32(2) + field(byteVector(bytes))
        case let .signResult(signature):
            guard signature.count == 64 else { throw violation("Ed25519 signature must be 64 bytes") }
            encoded = u32(3) + field(structure([Data([0]), byteVector(signature)]))
        case let .signError(code, message):
            encoded = u32(4) + field(string(code)) + field(string(message))
        case let .display(title, body):
            encoded = u32(5) + field(string(title)) + field(string(body))
        }
        let bare = structure([u64(sequence), encoded])
        return Data("NRT0".utf8) + Data([0, 0]) + envelopeSchema + Data([0]) +
            u64(UInt64(bare.count)) + u64(crc64XZ(bare)) + Data([0]) + bare
    }

    static func approvalPreimage(
        launch: IrohaConnectLaunch,
        walletKey: Data,
        accountId: String,
        permissions: IrohaConnectPermissions?,
        proof: IrohaConnectSignInProof? = nil
    ) throws -> Data {
        func taggedField(_ name: String, _ value: Data) -> Data {
            let tag = Data(name.utf8)
            return u16(UInt16(tag.count)) + tag + u64(UInt64(value.count)) + value
        }
        let constraintsHash = try structure([launch.network.bytes]).blake2b32()
        var output = taggedField("domain", Data("iroha-connect|approve|v1".utf8))
        output += taggedField("network_id", launch.network.bytes)
        output += taggedField("constraints", constraintsHash)
        output += taggedField("sid", launch.sid)
        output += taggedField("app_pk", launch.appPublicKey)
        output += taggedField("wallet_pk", walletKey)
        output += taggedField("account_id", Data(accountId.utf8))
        if let permissions {
            output += taggedField("permissions", try encodePermissions(permissions).blake2b32())
        }
        if let proof {
            output += taggedField("proof", try encodeProof(proof).blake2b32())
        }
        let relayAuth = Data("iroha-connect|relay-auth|v1".utf8) + launch.sid + Data(launch.relayToken.utf8)
        output += taggedField("relay_auth", Data(SHA256.hash(data: relayAuth)))
        return output
    }

    static func encodeOpenForTesting(
        sid: Data,
        appPublicKey: Data,
        network: IrohaConnectNetworkLiteral,
        metadata: IrohaConnectAppMetadata?,
        permissions: IrohaConnectPermissions?
    ) -> Data {
        let metadataBytes = metadata.map { metadata in
            structure([string(metadata.name), option(metadata.url.map(string)), option(metadata.iconHash.map(string))])
        }
        let body = structure([
            appPublicKey,
            option(metadataBytes),
            structure([network.bytes]),
            option(permissions.map(encodePermissions)),
        ])
        return frame(sid: sid, direction: 0, sequence: 1, tag: 0, body: tagged(0, body))
    }

    static func encodePermissions(_ value: IrohaConnectPermissions) -> Data {
        structure([
            vector(value.methods.map(string)),
            vector(value.events.map(string)),
            option(value.resources.map { vector($0.map(string)) }),
        ])
    }

    static func encodeProof(_ value: IrohaConnectSignInProof) -> Data {
        structure([
            string(value.domain),
            string(value.uri),
            string(value.statement),
            string(value.issuedAt),
            string(value.nonce),
        ])
    }

    private static func decodeControl(_ data: Data) throws -> IrohaConnectControl {
        var reader = Reader(data)
        let tag = try reader.u32("control.tag")
        let length = try reader.length("control.length", maximum: 64_000)
        let body = try reader.bytes(length, "control.body")
        try reader.finish("control")
        var fields = Reader(body)
        switch tag {
        case 0:
            let appPublicKey = try fields.field("open.app_pk", maximum: 32)
            guard appPublicKey.count == 32 else { throw violation("open app key must be 32 bytes") }
            let metadata = try decodeOption(
                try fields.field("open.app_meta", maximum: 16_384),
                label: "open.app_meta"
            ) { bytes in
                var inner = Reader(bytes)
                let name = try decodeString(try inner.field("app.name", maximum: 512), label: "app.name")
                guard !name.isEmpty else { throw violation("app name is empty") }
                let url = try decodeOption(try inner.field("app.url", maximum: 4_096), label: "app.url") {
                    try decodeString($0, label: "app.url")
                }
                let icon = try decodeOption(try inner.field("app.icon", maximum: 512), label: "app.icon") {
                    try decodeString($0, label: "app.icon")
                }
                try inner.finish("app metadata")
                return IrohaConnectAppMetadata(name: name, url: url, iconHash: icon)
            }
            var constraints = Reader(try fields.field("open.constraints", maximum: 64))
            let network = try IrohaConnectNetworkLiteral(bytes: constraints.field("open.network_id", maximum: 32))
            try constraints.finish("open.constraints")
            let permissions = try decodeOption(
                try fields.field("open.permissions", maximum: 32_768),
                label: "open.permissions",
                decodePermissions
            )
            try permissions?.validate()
            try fields.finish("open")
            return .open(appPublicKey: appPublicKey, metadata: metadata, network: network, permissions: permissions)
        case 1:
            let walletPublicKey = try fields.field("approve.wallet_pk", maximum: 32)
            guard walletPublicKey.count == 32 else { throw violation("approval wallet key must be 32 bytes") }
            let accountId = try decodeString(try fields.field("approve.account_id", maximum: 1_024), label: "approve.account_id")
            let permissions = try decodeOption(
                try fields.field("approve.permissions", maximum: 32_768),
                label: "approve.permissions",
                decodePermissions
            )
            try permissions?.validate()
            let proof = try decodeOption(
                try fields.field("approve.proof", maximum: 32_768),
                label: "approve.proof",
                decodeProof
            )
            let signature = try decodeWalletSignature(
                try fields.field("approve.signature", maximum: 128)
            )
            try fields.finish("approve")
            return .approve(
                walletPublicKey: walletPublicKey,
                accountId: accountId,
                permissions: permissions,
                proof: proof,
                signature: signature
            )
        case 2:
            let code = try Reader(try fields.field("reject.code", maximum: 2)).u16("reject.code")
            let codeId = try decodeString(try fields.field("reject.code_id", maximum: 256), label: "reject.code_id")
            let reason = try decodeString(try fields.field("reject.reason", maximum: 4_096), label: "reject.reason")
            try fields.finish("reject")
            return .reject(code: code, codeId: codeId, reason: reason)
        case 3:
            let who = try Reader(try fields.field("close.who", maximum: 4)).u32("close.who")
            guard who <= 1 else { throw violation("close role is invalid") }
            let code = try Reader(try fields.field("close.code", maximum: 2)).u16("close.code")
            let reason = try decodeString(try fields.field("close.reason", maximum: 4_096), label: "close.reason")
            let retryable = try decodeBool(try fields.field("close.retry", maximum: 1), label: "close.retry")
            try fields.finish("close")
            return .close(who: who, code: code, reason: reason, retryable: retryable)
        case 4, 5:
            let nonce = try Reader(try fields.field("ping.nonce", maximum: 8)).u64("ping.nonce")
            try fields.finish("ping")
            return tag == 4 ? .ping(nonce) : .pong(nonce)
        case 6:
            var event = Reader(try fields.field("server_event.event", maximum: 32_768))
            try fields.finish("server_event")
            let eventTag = try event.u32("server_event.tag")
            let length = try event.length("server_event.length", maximum: 32_000)
            var body = Reader(try event.bytes(length, "server_event.body"))
            try event.finish("server_event")
            guard eventTag == 0 else { throw violation("unsupported server event") }
            let height = try Reader(try body.field("server_event.height", maximum: 8)).u64("server_event.height")
            let entryHash = try decodeString(try body.field("server_event.entry_hash", maximum: 512), label: "server_event.entry_hash")
            let proofsJSON = try decodeString(try body.field("server_event.proofs_json", maximum: 16_384), label: "server_event.proofs_json")
            try body.finish("server_event.body")
            return .serverEvent(height: height, entryHash: entryHash, proofsJSON: proofsJSON)
        default:
            throw violation("unsupported control tag")
        }
    }

    private static func decodePermissions(_ data: Data) throws -> IrohaConnectPermissions {
        var reader = Reader(data)
        let methods = try decodeStringVector(try reader.field("permissions.methods", maximum: 4_096), label: "permissions.methods")
        let events = try decodeStringVector(try reader.field("permissions.events", maximum: 4_096), label: "permissions.events")
        let resources = try decodeOption(try reader.field("permissions.resources", maximum: 16_384), label: "permissions.resources") {
            try decodeStringVector($0, label: "permissions.resources")
        }
        try reader.finish("permissions")
        return IrohaConnectPermissions(methods: methods, events: events, resources: resources)
    }

    private static func decodeProof(_ data: Data) throws -> IrohaConnectSignInProof {
        var reader = Reader(data)
        let domain = try decodeString(try reader.field("proof.domain", maximum: 512), label: "proof.domain")
        let uri = try decodeString(try reader.field("proof.uri", maximum: 4_096), label: "proof.uri")
        let statement = try decodeString(try reader.field("proof.statement", maximum: 8_192), label: "proof.statement")
        let issuedAt = try decodeString(try reader.field("proof.issued_at", maximum: 256), label: "proof.issued_at")
        let nonce = try decodeString(try reader.field("proof.nonce", maximum: 512), label: "proof.nonce")
        try reader.finish("proof")
        return IrohaConnectSignInProof(
            domain: domain,
            uri: uri,
            statement: statement,
            issuedAt: issuedAt,
            nonce: nonce
        )
    }

    private static func decodeWalletSignature(_ data: Data) throws -> Data {
        var reader = Reader(data)
        let algorithm = try reader.field("signature.algorithm", maximum: 1)
        guard algorithm == Data([0]) else { throw violation("signature is not Ed25519") }
        let signature = try decodeByteVector(try reader.field("signature.bytes", maximum: 72), label: "signature.bytes", maximum: 64)
        try reader.finish("signature")
        guard signature.count == 64 else { throw violation("invalid Ed25519 signature") }
        return signature
    }

    private static func decodeStringVector(_ data: Data, label: String) throws -> [String] {
        var reader = Reader(data)
        let count = try reader.length("\(label).count", maximum: 64)
        var output: [String] = []
        for index in 0 ..< count {
            output.append(try decodeString(try reader.field("\(label)[\(index)]", maximum: 1_024), label: "\(label)[\(index)]"))
        }
        try reader.finish(label)
        return output
    }

    private static func decodeString(_ data: Data, label: String) throws -> String {
        var reader = Reader(data)
        let count = try reader.length("\(label).length", maximum: 524_288)
        let bytes = try reader.bytes(count, label)
        try reader.finish(label)
        guard let value = String(data: bytes, encoding: .utf8), Data(value.utf8) == bytes else {
            throw violation("\(label) is not canonical UTF-8")
        }
        return value
    }

    private static func decodeByteVector(_ data: Data, label: String, maximum: Int) throws -> Data {
        var reader = Reader(data)
        let count = try reader.length("\(label).count", maximum: maximum)
        let output = try reader.bytes(count, label)
        try reader.finish(label)
        return output
    }

    private static func decodeBool(_ data: Data, label: String) throws -> Bool {
        guard data == Data([0]) || data == Data([1]) else { throw violation("\(label) is not canonical") }
        return data[0] == 1
    }

    private static func decodeOption<T>(_ data: Data, label: String, _ decode: (Data) throws -> T) throws -> T? {
        var reader = Reader(data)
        let tag = try reader.byte("\(label).tag")
        if tag == 0 {
            try reader.finish(label)
            return nil
        }
        guard tag == 1 else { throw violation("unsupported option tag") }
        let length = try reader.length("\(label).length", maximum: 524_288)
        let value = try reader.bytes(length, label)
        try reader.finish(label)
        return try decode(value)
    }

    private static func frame(sid: Data, direction: UInt32, sequence: UInt64, tag: UInt32, body: Data) -> Data {
        structure([sid, u32(direction), u64(sequence), tagged(tag, body)])
    }

    private static func tagged(_ tag: UInt32, _ body: Data) -> Data {
        u32(tag) + u64(UInt64(body.count)) + body
    }

    private static func structure(_ values: [Data]) -> Data {
        values.reduce(into: Data()) { $0.append(field($1)) }
    }

    private static func vector(_ values: [Data]) -> Data {
        u64(UInt64(values.count)) + values.reduce(into: Data()) { $0.append(field($1)) }
    }

    private static func option(_ value: Data?) -> Data {
        guard let value else { return Data([0]) }
        return Data([1]) + u64(UInt64(value.count)) + value
    }

    private static func field(_ value: Data) -> Data {
        u64(UInt64(value.count)) + value
    }

    private static func string(_ value: String) -> Data {
        let bytes = Data(value.utf8)
        return u64(UInt64(bytes.count)) + bytes
    }

    private static func byteVector(_ value: Data) -> Data {
        u64(UInt64(value.count)) + value
    }

    private static func u16(_ value: UInt16) -> Data { integer(value.littleEndian) }
    private static func u32(_ value: UInt32) -> Data { integer(value.littleEndian) }
    private static func u64(_ value: UInt64) -> Data { integer(value.littleEndian) }

    private static func integer<T>(_ value: T) -> Data {
        withUnsafeBytes(of: value) { Data($0) }
    }

    private static func crc64XZ(_ data: Data) -> UInt64 {
        var crc = UInt64.max
        for byte in data {
            crc ^= UInt64(byte)
            for _ in 0 ..< 8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xC96C5795D7870F42 : crc >> 1
            }
        }
        return ~crc
    }

    private static func violation(_ reason: String) -> IrohaConnectError {
        .protocolViolation(reason)
    }

    final class Reader {
        private let data: Data
        private var offset = 0

        init(_ data: Data) { self.data = data }

        func byte(_ label: String) throws -> UInt8 {
            let value = try bytes(1, label)
            return value[0]
        }

        func u16(_ label: String) throws -> UInt16 {
            let value = try bytes(2, label)
            return value.withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.littleEndian
        }

        func u32(_ label: String) throws -> UInt32 {
            let value = try bytes(4, label)
            return value.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
        }

        func u64(_ label: String) throws -> UInt64 {
            let value = try bytes(8, label)
            return value.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }.littleEndian
        }

        func length(_ label: String, maximum: Int) throws -> Int {
            let value = try u64(label)
            guard value <= UInt64(maximum), let result = Int(exactly: value) else {
                throw IrohaConnectError.protocolViolation("\(label) exceeds its limit")
            }
            return result
        }

        func field(_ label: String, maximum: Int) throws -> Data {
            try bytes(length("\(label).length", maximum: maximum), label)
        }

        func bytes(_ count: Int, _ label: String) throws -> Data {
            guard count >= 0, offset <= data.count, count <= data.count - offset else {
                throw IrohaConnectError.protocolViolation("\(label) is truncated")
            }
            let end = offset + count
            let output = Data(data[offset ..< end])
            offset = end
            return output
        }

        func finish(_ label: String) throws {
            guard offset == data.count else {
                throw IrohaConnectError.protocolViolation("\(label) has trailing bytes")
            }
        }
    }
}

struct IrohaConnectDirectionKeys {
    var appToWallet: Data
    var walletToApp: Data

    mutating func wipe() {
        appToWallet.resetBytes(in: appToWallet.startIndex ..< appToWallet.endIndex)
        walletToApp.resetBytes(in: walletToApp.startIndex ..< walletToApp.endIndex)
    }
}

enum IrohaConnectCrypto {
    static func directionKeys(
        walletPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        appPublicKey: Data,
        sid: Data
    ) throws -> IrohaConnectDirectionKeys {
        let appKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: appPublicKey)
        let shared = try walletPrivateKey.sharedSecretFromKeyAgreement(with: appKey)
        let sessionKey = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("iroha:x25519:hkdf:v1".utf8),
            sharedInfo: Data("iroha:x25519:session-key".utf8),
            outputByteCount: 32
        )
        let salt = try (Data("iroha-connect|salt|".utf8) + sid).blake2b32()
        let app = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: sessionKey,
            salt: salt,
            info: Data("iroha-connect|k_app".utf8),
            outputByteCount: 32
        )
        let wallet = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: sessionKey,
            salt: salt,
            info: Data("iroha-connect|k_wallet".utf8),
            outputByteCount: 32
        )
        return IrohaConnectDirectionKeys(
            appToWallet: app.data,
            walletToApp: wallet.data
        )
    }

    static func encrypt(
        envelope: Data,
        key: Data,
        sid: Data,
        direction: UInt32,
        sequence: UInt64
    ) throws -> Data {
        let nonce = try ChaChaPoly.Nonce(data: nonce(sequence))
        let sealed = try ChaChaPoly.seal(
            envelope,
            using: SymmetricKey(data: key),
            nonce: nonce,
            authenticating: aad(sid: sid, direction: direction, sequence: sequence)
        )
        return sealed.ciphertext + sealed.tag
    }

    static func decrypt(
        ciphertext: Data,
        key: Data,
        sid: Data,
        direction: UInt32,
        sequence: UInt64
    ) throws -> Data {
        guard ciphertext.count >= 16 else { throw IrohaConnectError.protocolViolation("ciphertext is truncated") }
        let nonce = try ChaChaPoly.Nonce(data: nonce(sequence))
        let box = try ChaChaPoly.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext.dropLast(16),
            tag: ciphertext.suffix(16)
        )
        do {
            return try ChaChaPoly.open(
                box,
                using: SymmetricKey(data: key),
                authenticating: aad(sid: sid, direction: direction, sequence: sequence)
            )
        } catch {
            throw IrohaConnectError.protocolViolation("ciphertext authentication failed")
        }
    }

    private static func nonce(_ sequence: UInt64) -> Data {
        Data(repeating: 0, count: 4) + withUnsafeBytes(of: sequence.littleEndian) { Data($0) }
    }

    private static func aad(sid: Data, direction: UInt32, sequence: UInt64) -> Data {
        Data("connect:v1".utf8) + sid + Data([UInt8(direction)]) +
            withUnsafeBytes(of: sequence.littleEndian) { Data($0) } + Data([1])
    }
}

private extension Data {
    init?(strictHex value: String) {
        self.init()
        guard value.count.isMultiple(of: 2) else { return nil }
        reserveCapacity(value.count / 2)
        var cursor = value.startIndex
        while cursor < value.endIndex {
            let next = value.index(cursor, offsetBy: 2)
            guard let byte = UInt8(value[cursor ..< next], radix: 16) else {
                return nil
            }
            append(byte)
            cursor = next
        }
    }

    init(canonicalBase64URL value: String, length: Int, label: String) throws {
        guard
            !value.contains("="),
            value.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        else {
            throw IrohaConnectError.invalidURI("\(label) is not unpadded base64url")
        }
        let base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/") +
            String(repeating: "=", count: (4 - value.count % 4) % 4)
        guard let decoded = Data(base64Encoded: base64), decoded.count == length,
              decoded.base64URLString == value else {
            throw IrohaConnectError.invalidURI("\(label) has the wrong length or encoding")
        }
        self = decoded
    }

    var base64URLString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}

private extension SymmetricKey {
    var data: Data { withUnsafeBytes { Data($0) } }
}
