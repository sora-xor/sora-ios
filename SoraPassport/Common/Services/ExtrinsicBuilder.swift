import Foundation
import BigInt
import IrohaCrypto
import SSFModels
import SSFUtils

public protocol ExtrinsicBuilderProtocol: AnyObject {
    func with<A: Codable>(address: A) throws -> Self
    func with(nonce: UInt32) -> Self
    func with(era: Era, blockHash: String) -> Self
    func with(tip: BigUInt) -> Self
    func with(shouldUseAtomicBatch: Bool) -> Self
    func adding<T: RuntimeCallable>(call: T) throws -> Self
    func adding(rawCall: Data) throws -> Self

    func signing(
        by signer: (Data) throws -> Data,
        of type: CryptoType,
        using encoder: DynamicScaleEncoding,
        metadata: RuntimeMetadata
    ) throws -> Self

    func buildExtrinsic(metadata: RuntimeMetadata) throws -> Extrinsic
    func build(encodingBy encoder: DynamicScaleEncoding, metadata: RuntimeMetadata) throws -> Data
    func buildSignature(
        encodingBy encoder: DynamicScaleEncoding,
        metadata: RuntimeMetadata
    ) throws -> Data
    func build(encodingBy encoder: DynamicScaleEncoding, extrinsic: Extrinsic) throws -> Data
}

public enum ExtrinsicBuilderError: Error {
    case missingCall
    case missingNonce
    case missingAddress
    case unsupportedSignedExtension(_ value: String)
    case unsupportedBatch
}

public final class ExtrinsicBuilder {
    static let payloadHashingTreshold = 256

    struct InternalCall: Codable {
        let moduleName: String
        let callName: String
        let args: JSON
    }

    private let specVersion: UInt32
    private let transactionVersion: UInt32
    private let genesisHash: String

    private var calls: [JSON]
    private var blockHash: String
    private var address: JSON?
    private var nonce: UInt32?
    private var era: Era
    private var tip: BigUInt
    private var signature: ExtrinsicSignature?
    private var shouldUseAtomicBatch: Bool = true

    public init(
        specVersion: UInt32,
        transactionVersion: UInt32,
        genesisHash: String
    ) {
        self.specVersion = specVersion
        self.transactionVersion = transactionVersion
        self.genesisHash = genesisHash
        self.blockHash = genesisHash
        self.era = .immortal
        self.tip = 0
        self.calls = []
    }

    private func prepareExtrinsicCall(for metadata: RuntimeMetadata) throws -> JSON {
        guard !calls.isEmpty else {
            throw ExtrinsicBuilderError.missingCall
        }

        guard calls.count > 1 else {
            return calls[0]
        }

        let callName = shouldUseAtomicBatch ? KnowRuntimeModule.Utitlity.batchAll : KnowRuntimeModule.Utitlity.batch

        let call = RuntimeCall(
            moduleName: KnowRuntimeModule.Utitlity.name,
            callName: callName,
            args: BatchArgs(calls: calls)
        )

        guard try metadata.getFunction(from: call.moduleName, with: call.callName) != nil else {
            throw ExtrinsicBuilderError.unsupportedBatch
        }

        return try call.toScaleCompatibleJSON()
    }

    private func appendExtraToPayload(encodingBy encoder: DynamicScaleEncoding) throws {
        let extra = ExtrinsicSignedExtra(era: era, nonce: nonce ?? 0, tip: tip)
        try encoder.append(extra, ofType: GenericType.extrinsicExtra.name)
    }

    private func appendAdditionalSigned(
        encodingBy encoder: DynamicScaleEncoding,
        metadata: RuntimeMetadata
    ) throws {
        for checkString in try metadata.extrinsic.signedExtensions(using: metadata.schemaResolver) {
            guard let check = ExtrinsicCheck(rawValue: checkString) else {
                continue
            }

            switch check {
            case .genesis:
                try encoder.appendBytes(json: .stringValue(genesisHash))
            case .mortality:
                try encoder.appendBytes(json: .stringValue(blockHash))
            case .specVersion:
                try encoder.append(encodable: specVersion)
            case .txVersion:
                try encoder.append(encodable: transactionVersion)
            default:
                continue
            }
        }
    }

    private func prepareSignaturePayload(
        encodingBy encoder: DynamicScaleEncoding,
        using metadata: RuntimeMetadata
    ) throws -> Data {
        let call = try prepareExtrinsicCall(for: metadata)
        try encoder.append(json: call, type: GenericType.call.name)

        try appendExtraToPayload(encodingBy: encoder)
        try appendAdditionalSigned(encodingBy: encoder, metadata: metadata)

        let payload = try encoder.encode()

        return payload.count > Self.payloadHashingTreshold ? (try payload.blake2b32()) : payload
    }
}

extension ExtrinsicBuilder: ExtrinsicBuilderProtocol {
    public func with<A: Codable>(address: A) throws -> Self {
        self.address = try address.toScaleCompatibleJSON()
        self.signature = nil

        return self
    }

    public func with(nonce: UInt32) -> Self {
        self.nonce = nonce
        self.signature = nil

        return self
    }

    public func with(era: Era, blockHash: String) -> Self {
        self.era = era
        self.blockHash = blockHash
        self.signature = nil

        return self
    }

    public func with(tip: BigUInt) -> Self {
        self.tip = tip
        self.signature = nil

        return self
    }

    public func with(shouldUseAtomicBatch: Bool) -> Self {
        self.shouldUseAtomicBatch = shouldUseAtomicBatch
        return self
    }

    public func adding<T: RuntimeCallable>(call: T) throws -> Self {
        let json: JSON = try call.toScaleCompatibleJSON()
        calls.append(json)

        return self
    }
    
    public func adding(rawCall: Data) throws -> Self {
        let json = JSON.stringValue(rawCall.toHex())
        calls.append(json)

        return self
    }

    public func signing(
        by signer: (Data) throws -> Data,
        of type: CryptoType,
        using encoder: DynamicScaleEncoding,
        metadata: RuntimeMetadata
    ) throws -> Self {
        guard let address = address else {
            throw ExtrinsicBuilderError.missingAddress
        }

        let data = try prepareSignaturePayload(encodingBy: encoder, using: metadata)

        let rawSignature = try signer(data)

        var signatureJson = JSON.null
        var signatureTypeString = KnownType.signature.rawValue
        
        // Some networks like Moonbeam/Moonriver have signature as direct byte-array rather than MultiSignature enum
        // Though they have MultiSignature enum in their metadata, check what signature type is used within extrinsic
        // Otherwise provide default enum based MultiSignature behavior
        if let extrinsicType = try? metadata.schemaResolver.typeMetadata(for: metadata.extrinsic.type) {
            let signatureParam = extrinsicType.params.first { $0.name == "Signature" }
            if let signatureType = try? metadata.schemaResolver.typeMetadata(for: signatureParam?.type) {
                switch signatureType.def {
                case .variant:
                    break
                default:
                    signatureJson = try rawSignature.toScaleCompatibleJSON()
                    signatureTypeString = try metadata.schemaResolver.typeName(for: signatureType)
                }
            }
        }
        
        if signatureJson == .null {
            let signature: MultiSignature
            switch type {
            case .sr25519:
                signature = .sr25519(data: rawSignature)
            case .ed25519:
                signature = .ed25519(data: rawSignature)
            case .ecdsa:
                signature = .ecdsa(data: rawSignature)
            }

            signatureJson = try signature.toScaleCompatibleJSON()
        }

        let extra = ExtrinsicSignedExtra(era: era, nonce: nonce ?? 0, tip: tip)
        self.signature = ExtrinsicSignature(
            address: address,
            signature: signatureJson,
            extra: extra,
            type: signatureTypeString
        )

        return self
    }
    
    public func buildExtrinsic(metadata: RuntimeMetadata) throws -> Extrinsic {
        let call = try prepareExtrinsicCall(for: metadata)
        
        Log.enable(kind: "DynamicScale")
        return Extrinsic(call: call, signature: signature)
    }

    public func build(
        encodingBy encoder: DynamicScaleEncoding,
        metadata: RuntimeMetadata
    ) throws -> Data {
        let call = try prepareExtrinsicCall(for: metadata)
        
        Log.enable(kind: "DynamicScale")
        let extrinsic = Extrinsic(call: call, signature: signature)

        try encoder.append(extrinsic, ofType: GenericType.extrinsic.name)
        
        let encoded = try encoder.encode()
        Log.write("DynamicScale", message: "Extrinsic encoded: \(encoded.toHex(includePrefix: true))")
        Log.disable(kind: "DynamicScale")
        
        return encoded
    }
    
    public func build(encodingBy encoder: DynamicScaleEncoding, extrinsic: Extrinsic) throws -> Data {
        Log.enable(kind: "DynamicScale")
        try encoder.append(extrinsic, ofType: GenericType.extrinsic.name)
        
        let encoded = try encoder.encode()
        Log.write("DynamicScale", message: "Extrinsic encoded: \(encoded.toHex(includePrefix: true))")
        Log.disable(kind: "DynamicScale")
        
        return encoded
    }
    
    public func buildSignature(
        encodingBy encoder: DynamicScaleEncoding,
        metadata: RuntimeMetadata
    ) throws -> Data {
        try prepareSignaturePayload(encodingBy: encoder, using: metadata)
    }
}

struct Log {
    private static var enabled: [String] = []
    
    static func enable(kind: String) {
        enabled.append(kind)
    }
    
    static func disable(kind: String) {
        enabled.removeAll { $0 == kind }
    }
    
    static func write(_ kind: String, message: String) {
        if enabled.contains(kind) {
            print("[\(kind)] \(message)")
        }
    }
}

public extension Encodable {
    func toScaleCompatibleJSON() throws -> JSON {
        let container = EncodingContainer(value: self)

        let data = try JSONEncoder.scaleCompatible().encode(container)
        let json = try JSONDecoder.scaleCompatible(snakeCase: false).decode(JsonContainer.self, from: data).value

        return json
    }
}

struct EncodingContainer<T: Encodable>: Encodable {
    let value: T
}

struct JsonContainer: Codable {
    let value: JSON
}
