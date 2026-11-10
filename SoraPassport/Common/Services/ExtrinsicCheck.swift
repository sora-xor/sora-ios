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
        guard extrinsic.signedExtensions.count <= 256 else { throw Unsupported(identifier: "signed-extension-count") }
        let resolver = metadata.schemaResolver
        var remainingNodes = 4_096
        var extraOrder: [ExtrinsicCheck] = []
        var additionalOrder: [ExtrinsicCheck] = []
        for signedExtension in extrinsic.signedExtensions {
            let typeName: String
            let carriesExtra: Bool
            let carriesAdditionalSigned: Bool
            do {
                typeName = try resolver.typeName(for: signedExtension.type)
                carriesExtra = try !isZeroSized(
                    signedExtension.type,
                    resolver: resolver,
                    depth: 0,
                    remainingNodes: &remainingNodes
                )
                carriesAdditionalSigned = try !isZeroSized(
                    signedExtension.additionalSigned,
                    resolver: resolver,
                    depth: 0,
                    remainingNodes: &remainingNodes
                )
            } catch {
                throw Unsupported(identifier: signedExtension.identifier)
            }
            // The same two lookups the encoders make: the signed extra is
            // matched by type name with a fallback to the last path
            // component, the additional signed data by exact type name.
            let extraCheck = ExtrinsicCheck.matching(typeName: typeName)
            let additionalCheck = ExtrinsicCheck(rawValue: typeName)
            let writesExtra = extraCheck?.writesExtra ?? false
            let writesAdditionalSigned = additionalCheck?.writesAdditionalSigned ?? false
            guard
                writesExtra == carriesExtra,
                writesAdditionalSigned == carriesAdditionalSigned
            else {
                throw Unsupported(identifier: signedExtension.identifier)
            }
            if writesExtra, let extraCheck { extraOrder.append(extraCheck) }
            if writesAdditionalSigned, let additionalCheck { additionalOrder.append(additionalCheck) }
        }
        // Presence alone is insufficient: swapping nonce and payment makes
        // the node-supplied nonce become the real-chain tip. Pin the byte
        // sequences, not the whole list, so harmless zero-sized additions
        // remain compatible. Equality also rejects omissions and duplicates.
        let metadataHash: [ExtrinsicCheck] = extraOrder.last == .metadataHash ? [.metadataHash] : []
        guard extraOrder == [.mortality, .nonce, .txPayment] + metadataHash,
              additionalOrder == [.specVersion, .txVersion, .genesis, .mortality] + metadataHash else {
            throw Unsupported(identifier: "signed-extension-order")
        }
    }

    /// A type that SCALE-encodes to no bytes: an empty tuple or struct
    /// (`PhantomData`), or one made only of such types.
    private static func isZeroSized(
        _ index: BigUInt,
        resolver: Schema.Resolver,
        depth: Int,
        remainingNodes: inout Int
    ) throws -> Bool {
        guard depth < 16, remainingNodes > 0 else {
            throw Unsupported(identifier: "signed-extension-layout")
        }
        remainingNodes -= 1
        switch try resolver.typeMetadata(for: index).def {
        case let .composite(composite):
            guard composite.fields.count <= 64 else { throw Unsupported(identifier: "signed-extension-layout") }
            return try composite.fields.allSatisfy {
                try isZeroSized($0.type, resolver: resolver, depth: depth + 1, remainingNodes: &remainingNodes)
            }
        case let .tuple(items):
            guard items.count <= 64 else { throw Unsupported(identifier: "signed-extension-layout") }
            return try items.allSatisfy {
                try isZeroSized($0, resolver: resolver, depth: depth + 1, remainingNodes: &remainingNodes)
            }
        case let .array(array):
            return try array.length == 0 ||
                isZeroSized(array.type, resolver: resolver, depth: depth + 1, remainingNodes: &remainingNodes)
        case .variant, .sequence, .primitive, .compact, .bitSequence:
            // An enum writes its variant index, a vector its length.
            return false
        }
    }
}


/// The reviewed SCALE layout of every SORA2 call built by the wallet. A node can
/// lie consistently about its runtime and metadata hash; neither authenticates
/// the meaning of the bytes it asks us to sign. Indices and argument layouts
/// therefore stay pinned locally even when the live runtime version changes.
/// These encodings match the reviewed mainnet 133/138 call table (also used on
/// Android). A real layout change requires review and an app update.
enum Sora2CallTable {
    struct Pin {
        let pallet: String
        let call: String
        let shape: String
        var identifier: String { "\(pallet).\(call)" }
    }

    struct Mismatch: Error {
        let identifier: String
    }

    private static let asset = "{code:[u8;32]}"
    private static let account = "[u8;32]"
    private static let balance = "u128"
    private static let swapAmount =
        "enum{0=WithDesiredInput:{desired_amount_in:u128,min_amount_out:u128}|1=WithDesiredOutput:{desired_amount_out:u128,max_amount_in:u128}}"
    private static let sources =
        "Vec<enum{0=XYKPool|1=BondingCurvePool|2=MulticollateralBondingCurvePool|3=MockPool|4=MockPool2|5=MockPool3|6=MockPool4|7=XSTPool|8=OrderBook}>"
    private static let filter = "enum{0=Disabled|1=ForbidSelected|2=AllowSelected}"
    private static let farm = "base_asset:\(asset),pool_asset:\(asset),reward_asset:\(asset)"

    static let pinned: [Pin] = [
        Pin(pallet: "Assets", call: "transfer", shape: "21:1(asset_id:\(asset),to:\(account),amount:\(balance))"),
        Pin(pallet: "LiquidityProxy", call: "swap", shape: "26:0(dex_id:u32,input_asset_id:\(asset),output_asset_id:\(asset),swap_amount:\(swapAmount),selected_source_types:\(sources),filter_mode:\(filter))"),
        Pin(pallet: "PoolXYK", call: "deposit_liquidity", shape: "25:0(dex_id:u32,input_asset_a:\(asset),input_asset_b:\(asset),input_a_desired:u128,input_b_desired:u128,input_a_min:u128,input_b_min:u128)"),
        Pin(pallet: "PoolXYK", call: "withdraw_liquidity", shape: "25:1(dex_id:u32,output_asset_a:\(asset),output_asset_b:\(asset),marker_asset_desired:u128,output_a_min:u128,output_b_min:u128)"),
        Pin(pallet: "PoolXYK", call: "initialize_pool", shape: "25:2(dex_id:u32,asset_a:\(asset),asset_b:\(asset))"),
        Pin(pallet: "TradingPair", call: "register", shape: "20:0(dex_id:u32,base_asset_id:\(asset),target_asset_id:\(asset))"),
        Pin(pallet: "Referrals", call: "reserve", shape: "7:0(balance:u128)"),
        Pin(pallet: "Referrals", call: "unreserve", shape: "7:1(balance:u128)"),
        Pin(pallet: "Referrals", call: "set_referrer", shape: "7:2(referrer:\(account))"),
        Pin(pallet: "IrohaMigration", call: "migrate", shape: "35:0(iroha_address:str,iroha_public_key:str,iroha_signature:str)"),
        Pin(pallet: "DemeterFarmingPlatform", call: "deposit", shape: "50:2(\(farm),is_farm:bool,pooled_tokens:u128)"),
        Pin(pallet: "DemeterFarmingPlatform", call: "withdraw", shape: "50:4(\(farm),pooled_tokens:u128,is_farm:bool)"),
        Pin(pallet: "DemeterFarmingPlatform", call: "get_rewards", shape: "50:3(\(farm),is_farm:bool)"),
        Pin(pallet: "Faucet", call: "transfer", shape: "80:0(asset_id:\(asset),target:\(account),amount:u128)"),
        Pin(pallet: "Utility", call: "batch", shape: "11:0(calls:Vec<Call>)"),
        Pin(pallet: "Utility", call: "batch_all", shape: "11:2(calls:Vec<Call>)")
    ]

    static func validate(factory: RuntimeCoderFactoryProtocol) throws {
        // This is the encoder used by ExtrinsicBuilder, including nested batch
        // calls. Its metadata must be the same object we validated as live.
        guard let call = factory.catalog.node(
            for: GenericType.call.name, version: UInt64(factory.specVersion)
        ) as? GenericCallNode, call.runtimeMetadata === factory.metadata else {
            throw Mismatch(identifier: "GenericCall")
        }
        try Sora2TypeNames.requireOneDefinitionPerName(in: factory.metadata)
        for pin in pinned {
            // Absent calls cannot be built (e.g. mainnet has no faucet).
            guard let actual = try shape(of: pin, factory: factory) else { continue }
            guard actual == pin.shape else { throw Mismatch(identifier: pin.identifier) }
        }
        // The signed extra writes the nonce and tip through these names.
        let renderer = Sora2EncoderShape(factory: factory)
        for (name, expected) in [(KnownType.index.name, "u32"), (KnownType.balance.name, "u128")] {
            guard renderer.render(type: name) == expected else {
                throw Mismatch(identifier: "signed-extra.\(name)")
            }
        }
    }

    static func shape(of pin: Pin, factory: RuntimeCoderFactoryProtocol) throws -> String? {
        let metadata = factory.metadata
        // Use the encoder's case-insensitive lookups, including explicit v14
        // discriminants, rather than the order the node lists its calls in.
        guard let function = try metadata.getFunction(from: pin.pallet, with: pin.call),
              let pallet = metadata.getModuleIndex(pin.pallet),
              let call = try metadata.getCallIndex(in: pin.pallet, callName: pin.call) else { return nil }
        guard function.arguments.count <= 64,
              function.arguments.allSatisfy({ $0.name.utf8.count <= 128 }) else { return "?arguments" }
        let renderer = Sora2EncoderShape(factory: factory)
        return "\(pallet):\(call)(" + function.arguments.map {
            "\($0.name):\(renderer.render(type: $0.type))"
        }.joined(separator: ",") + ")"
    }
}

/// The encoder finds types by name, and what a name resolves to can change while
/// types are being built: the first schema item with that name, until another item
/// is registered under it by id. With two definitions under one name, the call table
/// could read one layout and the encoder later write the other. Real runtimes repeat
/// a name only with the same definition, so anything else is refused before signing.
private enum Sora2TypeNames {
    private static let lock = NSLock()
    private static let verified = NSHashTable<RuntimeMetadata>.weakObjects()

    static func requireOneDefinitionPerName(in metadata: RuntimeMetadata) throws {
        lock.lock()
        let alreadyVerified = verified.contains(metadata)
        lock.unlock()
        guard !alreadyVerified else { return }

        let items = metadata.schema?.types ?? []
        let resolver = metadata.schemaResolver
        var names: [BigUInt: String] = [:]
        for item in items {
            names[item.id] = try resolver.typeName(for: item.type)
        }
        var definitions: [String: String] = [:]
        for item in items {
            guard let name = names[item.id] else { throw Sora2CallTable.Mismatch(identifier: "type-name") }
            let definition = try definition(of: item.type.def, names: names)
            if let known = definitions[name], known != definition {
                throw Sora2CallTable.Mismatch(identifier: "type-name")
            }
            definitions[name] = definition
        }

        lock.lock()
        verified.add(metadata)
        lock.unlock()
    }

    /// The layout in terms of names, because two items may refer to the same-named
    /// child by different ids. Every name is checked here too, so equal text means
    /// equal bytes.
    private static func definition(of def: TypeMetadata.Def, names: [BigUInt: String]) throws -> String {
        func name(_ id: BigUInt) throws -> String {
            guard let name = names[id] else { throw Sora2CallTable.Mismatch(identifier: "type-name") }
            return name
        }
        func fields(_ fields: [TypeMetadata.Def.Composite.Field]) throws -> String {
            try fields.map { "\($0.name ?? "_"):\(try name($0.type))" }.joined(separator: ",")
        }
        switch def {
        case let .composite(value):
            return "{\(try fields(value.fields))}"
        case let .variant(value):
            return try "enum{" + value.variants.map {
                "\($0.index)=\($0.name)(\(try fields($0.fields)))"
            }.joined(separator: "|") + "}"
        case let .sequence(value):
            return "Vec<\(try name(value.type))>"
        case let .array(value):
            return "[\(try name(value.type));\(value.length)]"
        case let .tuple(items):
            return "(\(try items.map(name).joined(separator: ",")))"
        case let .primitive(value):
            return "\(value)"
        case let .compact(value):
            return "Compact<\(try name(value.type))>"
        case let .bitSequence(value):
            return "BitVec<\(try name(value.store)),\(try name(value.order))>"
        }
    }
}

/// Follows the *effective* encoder graph, not just the node's portable schema.
/// SSF resolves names through pinned overrides and aliases; inspecting only a
/// schema type id would miss a malicious path that resolves to another encoder.
/// Each child is looked up exactly as its accept(encoder:) implementation does.
private final class Sora2EncoderShape {
    let factory: RuntimeCoderFactoryProtocol
    private let maximumDepth = 32
    private var remainingNodes = 4_096
    private var resolving: Set<String> = []
    private var validatingRuntimeCall: EnumNode?

    init(factory: RuntimeCoderFactoryProtocol) { self.factory = factory }

    func render(type: String, depth: Int = 0) -> String {
        if let current = validatingRuntimeCall, type == current.typeName,
           factory.catalog.node(for: type, version: UInt64(factory.specVersion)) === current {
            return "Call"
        }
        guard depth < maximumDepth, remainingNodes > 0,
              resolving.insert(type).inserted else { return "?recursive" }
        defer { resolving.remove(type) }
        guard let node = factory.catalog.node(for: type, version: UInt64(factory.specVersion)) else { return "?unresolved" }
        return render(node: node, depth: depth + 1)
    }

    private func render(node: Node, depth: Int) -> String {
        guard depth < maximumDepth, remainingNodes > 0 else { return "?limit" }
        remainingNodes -= 1
        let next = depth + 1
        switch node {
        case let value as AliasNode:
            return render(type: value.underlyingTypeName, depth: next)
        case let value as ProxyNode:
            guard let underlying = value.resolver?.resolve(for: value.typeName) else { return "?proxy" }
            if underlying is GenericNode { return render(type: value.typeName, depth: next) }
            return render(node: underlying, depth: next)
        case let value as StructNode:
            guard value.typeMapping.count <= 64,
                  value.typeMapping.allSatisfy({ $0.name.utf8.count <= 128 }) else { return "?fields" }
            return "{" + value.typeMapping.map {
                "\($0.name):\(render(type: $0.node.typeName, depth: next))"
            }.joined(separator: ",") + "}"
        case let value as MappingNode:
            guard value.typeMapping.count <= 64,
                  value.typeMapping.allSatisfy({ $0.name.utf8.count <= 128 }) else { return "?fields" }
            return "{" + value.typeMapping.map {
                "\($0.name):\(render(type: $0.type, depth: next))"
            }.joined(separator: ",") + "}"
        case let value as EnumNode:
            guard value.typeMapping.count <= 256,
                  value.typeMapping.allSatisfy({ $0.name.utf8.count <= 128 }) else { return "?variants" }
            if value.typeName == "framenode_runtime::RuntimeCall" {
                return renderRuntimeCall(value, depth: next)
            }
            return "enum{" + value.typeMapping.map {
                let payload = render(type: $0.node.typeName, depth: next)
                return "\($0.index)=\($0.name)" + (["()", "{}"].contains(payload) ? "" : ":\(payload)")
            }.joined(separator: "|") + "}"
        case let value as EnumValuesNode:
            guard value.values.count <= 256,
                  value.values.allSatisfy({ $0.utf8.count <= 128 }) else { return "?variants" }
            return "enum{" + value.values.enumerated().map { "\($0.offset)=\($0.element)" }.joined(separator: "|") + "}"
        case let value as TupleNode:
            guard value.innerNodes.count <= 64 else { return "?tuple" }
            return "(" + value.innerNodes.map { render(type: $0.typeName, depth: next) }.joined(separator: ",") + ")"
        case let value as VectorNode:
            return "Vec<\(render(type: value.underlying.typeName, depth: next))>"
        case let value as FixedArrayNode:
            return "[\(render(type: value.elementType.typeName, depth: next));\(value.length)]"
        case let value as OptionNode:
            return "Option<\(render(type: value.underlying.typeName, depth: next))>"
        case let value as CompactNode:
            return "Compact<\(render(type: value.underlying.typeName, depth: next))>"
        case let value as GenericCallNode:
            return value.runtimeMetadata === factory.metadata ? "Call" : "?metadata"
        case is GenericAccountIdNode, is H256Node: return "bytes[32]"
        case is BytesNode: return "Vec<\(render(type: PrimitiveType.u8.name, depth: next))>"
        case is NullNode: return "()"
        case is U8Node: return "u8"
        case is U16Node: return "u16"
        case is U32Node: return "u32"
        case is U64Node: return "u64"
        case is U128Node: return "u128"
        case is U256Node: return "u256"
        case is BoolNode: return "bool"
        case is StringNode: return "str"
        default: return "?unsupported"
        }
    }

    /// Batch items use SSF's runtime enum encoder, not GenericCallNode. Check
    /// that enum's own discriminants and argument nodes independently: matching
    /// the pallet metadata alone does not constrain the bytes inside a batch.
    private func renderRuntimeCall(_ call: EnumNode, depth: Int) -> String {
        guard validatingRuntimeCall == nil else { return "?nested-call" }
        validatingRuntimeCall = call
        let outerResolving = resolving
        resolving = []
        defer { validatingRuntimeCall = nil; resolving = outerResolving }
        var matched = false
        for pin in Sora2CallTable.pinned {
            guard let pallet = call.typeMapping.first(where: { $0.name.lowercased() == pin.pallet.lowercased() }) else { continue }
            guard let functions = resolveEnum(type: pallet.node.typeName),
                  functions.typeMapping.count <= 256,
                  functions.typeMapping.allSatisfy({ $0.name.utf8.count <= 128 }) else { return "?pallet" }
            guard let function = functions.typeMapping.first(where: { $0.name.lowercased() == pin.call.lowercased() }) else { continue }
            let payload = render(type: function.node.typeName, depth: depth + 1)
            guard payload.hasPrefix("{"), payload.hasSuffix("}") else { return "?arguments" }
            let shape = "\(pallet.index):\(function.index)(" + payload.dropFirst().dropLast() + ")"
            guard shape == pin.shape else { return "?call-layout" }
            matched = true
        }
        return matched ? "Call" : "?empty-call"
    }

    private func resolveEnum(type: String) -> EnumNode? {
        var node = factory.catalog.node(for: type, version: UInt64(factory.specVersion))
        for _ in 0..<maximumDepth {
            guard remainingNodes > 0 else { return nil }
            remainingNodes -= 1
            switch node {
            case let value as EnumNode: return value
            case let value as AliasNode:
                node = factory.catalog.node(for: value.underlyingTypeName, version: UInt64(factory.specVersion))
            case let value as ProxyNode:
                node = value.resolver?.resolve(for: value.typeName)
                if node is GenericNode {
                    node = factory.catalog.node(for: value.typeName, version: UInt64(factory.specVersion))
                }
            default: return nil
            }
        }
        return nil
    }
}
