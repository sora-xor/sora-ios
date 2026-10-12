import BigInt
import Foundation
import SSFUtils

enum ExtrinsicCheck: String, CaseIterable {
    case specVersion = "frame_system::extensions::check_spec_version::CheckSpecVersion"
    case txVersion = "frame_system::extensions::check_tx_version::CheckTxVersion"
    case genesis = "frame_system::extensions::check_genesis::CheckGenesis"
    case mortality = "frame_system::extensions::check_mortality::CheckMortality"
    case nonce = "frame_system::extensions::check_nonce::CheckNonce"
    case weight = "frame_system::extensions::check_weight::CheckWeight"
    case txPayment = "pallet_transaction_payment::ChargeTransactionPayment"
    case attests = "polkadot_runtime_common::claims::PrevalidateAttests"
    case assetTxPayment = "pallet_asset_tx_payment::ChargeAssetTxPayment" // Statemine/Statemint case
    /// Written in disabled mode only: one mode byte (0) in the extra and an
    /// absent hash (0) in the additional signed data.
    case metadataHash = "frame_metadata_hash_extension::CheckMetadataHash"

    /// The extrinsic encoder (`ExtrinsicExtraNode`) writes bytes into the
    /// signed extra for this extension.
    var writesExtra: Bool {
        switch self {
        case .mortality, .nonce, .txPayment, .assetTxPayment, .metadataHash:
            return true
        case .specVersion, .txVersion, .genesis, .weight, .attests:
            return false
        }
    }

    /// `ExtrinsicBuilder.appendAdditionalSigned` writes bytes into the
    /// signature payload for this extension.
    var writesAdditionalSigned: Bool {
        switch self {
        case .specVersion, .txVersion, .genesis, .mortality, .metadataHash:
            return true
        case .nonce, .weight, .txPayment, .attests, .assetTxPayment:
            return false
        }
    }

    /// The extension a type name stands for, by the rule the extra encoder
    /// uses (`from(string:runtimeMetadata:)`): the exact name, otherwise the
    /// same last path component (`xor_fee::extension::ChargeTransactionPayment`
    /// is `.txPayment`). It keeps no shared state, so it may be called from
    /// any thread.
    static func matching(typeName: String) -> Self? {
        if let check = ExtrinsicCheck(rawValue: typeName) {
            return check
        }
        let withoutParameters = typeName.contains("<")
            ? typeName.components(separatedBy: "<").first ?? typeName
            : typeName
        let lastComponent = withoutParameters.components(separatedBy: "::").last
        return allCases.first {
            $0.rawValue.components(separatedBy: "::").last == lastComponent
        }
    }

    /// Overiden types explain which network has what full names
    /// Key UInt32 - is metadata reserver number to identify network
    /// Value - is String:String dictionary, which has fixing mappings from original name to actual name
    private static var overridenTypes: [UInt32: [String: String]] = [:]
    
    static func from(string: String, runtimeMetadata: RuntimeMetadata) -> Self? {
        if let check = ExtrinsicCheck(rawValue: string) {
            return check
        }
        
        var overridenTypes = overridenTypes[runtimeMetadata.metaReserved] ?? [:]
        
        if let overridenType = overridenTypes[string] {
            return from(string: overridenType, runtimeMetadata: runtimeMetadata)
        }
        
        var typeName: String? = string
        if typeName?.contains("<") == true {
            typeName = typeName?.components(separatedBy: "<").first
        }
        
        typeName = typeName?.components(separatedBy: "::").last
        
        for check in Self.allCases {
            if let checkTypeName = check.rawValue.components(separatedBy: "::").last, checkTypeName == typeName {
                overridenTypes[string] = check.rawValue
                self.overridenTypes[runtimeMetadata.metaReserved] = overridenTypes
                return from(string: check.rawValue, runtimeMetadata: runtimeMetadata)
            }
        }
        
        return nil
    }
}

/// Compares what the encoder writes for each signed extension with what the
/// runtime's own metadata says each extension carries.
///
/// The encoder knows a fixed set of extensions and silently writes nothing
/// for any other. That is right for an extension without data
/// (`CheckWeight`, `CheckNonZeroSender`) and wrong for one with data: the
/// node would decode the transaction at the wrong offsets, or verify the
/// signature over other bytes, and reject every transaction. The same holds
/// in reverse when a known extension stops carrying data. Either way the
/// app must not sign; it tells the user to update instead.
enum Sora2SignedExtensionSupport {
    struct Unsupported: Error, Equatable {
        /// The extension's identifier in the runtime metadata. Not secret,
        /// not shown to the user.
        let identifier: String
    }

    static func validate(metadata: RuntimeMetadata) throws {
        guard
            let extrinsic = metadata.extrinsic
                as? RuntimeMetadataV14.ExtrinsicMetadata
        else {
            // Every reviewed SORA2 runtime has V14 metadata. Without the
            // per-extension types nothing can be compared.
            throw Unsupported(identifier: "metadata")
        }
        let resolver = metadata.schemaResolver
        for signedExtension in extrinsic.signedExtensions {
            let typeName: String
            let carriesExtra: Bool
            let carriesAdditionalSigned: Bool
            do {
                typeName = try resolver.typeName(for: signedExtension.type)
                carriesExtra = try !isZeroSized(
                    signedExtension.type,
                    resolver: resolver,
                    depth: 0
                )
                carriesAdditionalSigned = try !isZeroSized(
                    signedExtension.additionalSigned,
                    resolver: resolver,
                    depth: 0
                )
            } catch {
                throw Unsupported(identifier: signedExtension.identifier)
            }
            // The same two lookups the encoders make: the signed extra is
            // matched by type name with a fallback to the last path
            // component, the additional signed data by exact type name.
            let writesExtra = ExtrinsicCheck.matching(typeName: typeName)?
                .writesExtra ?? false
            let writesAdditionalSigned = ExtrinsicCheck(rawValue: typeName)?
                .writesAdditionalSigned ?? false
            guard
                writesExtra == carriesExtra,
                writesAdditionalSigned == carriesAdditionalSigned
            else {
                throw Unsupported(identifier: signedExtension.identifier)
            }
        }
    }

    /// A type that SCALE-encodes to no bytes: an empty tuple or struct
    /// (`PhantomData`), or one made only of such types.
    private static func isZeroSized(
        _ index: BigUInt,
        resolver: Schema.Resolver,
        depth: Int
    ) throws -> Bool {
        guard depth < 16 else {
            return false
        }
        switch try resolver.typeMetadata(for: index).def {
        case let .composite(composite):
            return try composite.fields.allSatisfy {
                try isZeroSized($0.type, resolver: resolver, depth: depth + 1)
            }
        case let .tuple(items):
            return try items.allSatisfy {
                try isZeroSized($0, resolver: resolver, depth: depth + 1)
            }
        case let .array(array):
            return try array.length == 0 ||
                isZeroSized(array.type, resolver: resolver, depth: depth + 1)
        case .variant, .sequence, .primitive, .compact, .bitSequence:
            // An enum writes its variant index, a vector its length.
            return false
        }
    }
}
