import BigInt
import Foundation

// MARK: - Protocol

public protocol RuntimeFunctionMetadata {
    var name: String { get }
    var arguments: [RuntimeFunctionArgumentMetadata] { get }
    var documentation: [String] { get }
}

// MARK: - V1

public extension RuntimeMetadataV1 {
    struct FunctionMetadata: RuntimeFunctionMetadata, ScaleCodable {
        public let name: String
        private let _arguments: [FunctionArgumentMetadata]
        public var arguments: [RuntimeFunctionArgumentMetadata] { _arguments }
        public let documentation: [String]

        public init(name: String, arguments: [FunctionArgumentMetadata], documentation: [String]) {
            self.name = name
            _arguments = arguments
            self.documentation = documentation
        }

        public func encode(scaleEncoder: ScaleEncoding) throws {
            try name.encode(scaleEncoder: scaleEncoder)
            try _arguments.encode(scaleEncoder: scaleEncoder)
            try documentation.encode(scaleEncoder: scaleEncoder)
        }

        public init(scaleDecoder: ScaleDecoding) throws {
            name = try String(scaleDecoder: scaleDecoder)
            _arguments = try [FunctionArgumentMetadata](scaleDecoder: scaleDecoder)
            documentation = try [String](scaleDecoder: scaleDecoder)
        }
    }
}

// MARK: - V14

public extension RuntimeMetadataV14 {
    struct FunctionMetadata: RuntimeFunctionMetadata {
        public let name: String
        private let _arguments: [FunctionArgumentMetadata]
        public var arguments: [RuntimeFunctionArgumentMetadata] { _arguments }
        public let documentation: [String]

        public init(item: TypeMetadata.Def.Variant.Item, schemaResolver: Schema.Resolver) throws {
            name = item.name
            _arguments = try item.fields.map {
                guard let name = $0.name else {
                    throw Schema.Resolver.Error.wrongData
                }
                let typeName = try schemaResolver.typeName(for: $0.type)
                return FunctionArgumentMetadata(name: name, type: typeName)
            }
            documentation = item.docs
        }
    }
}
