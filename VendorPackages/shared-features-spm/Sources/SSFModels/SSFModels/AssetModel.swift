import Foundation

public struct TokenProperties: Codable, Hashable {
    public let priceId: String?
    public let currencyId: String?
    public let color: String?
    public let type: SubstrateAssetType?
    public let isNative: Bool?
    public let stacking: String?

    public init(
        priceId: String? = nil,
        currencyId: String? = nil,
        color: String? = nil,
        type: SubstrateAssetType? = nil,
        isNative: Bool = false,
        stacking: String? = ""
    ) {
        self.priceId = priceId
        self.currencyId = currencyId
        self.color = color
        self.type = type
        self.isNative = isNative
        self.stacking = stacking
    }
}

public struct AssetModel: Equatable, Codable, Hashable {
    public typealias Id = String
    public typealias PriceId = String

    public let id: String
    public let name: String
    public let symbol: String
    public let isUtility: Bool
    public let precision: UInt16
    public let icon: URL?
    public let substrateType: SubstrateAssetType?
    public let ethereumType: EthereumAssetType?
    public let tokenProperties: TokenProperties?
    public let price: Decimal?
    public let priceId: String?
    public let coingeckoPriceId: String?
    public let priceProvider: PriceProvider?

    public var symbolUppercased: String {
        symbol.uppercased()
    }

    public init(
        id: String,
        name: String,
        symbol: String,
        isUtility: Bool,
        precision: UInt16,
        icon: URL? = nil,
        substrateType: SubstrateAssetType?,
        ethereumType: EthereumAssetType?,
        tokenProperties: TokenProperties?,
        price: Decimal?,
        priceId: String?,
        coingeckoPriceId: String?,
        priceProvider: PriceProvider?
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.isUtility = isUtility
        self.precision = precision
        self.icon = icon
        self.substrateType = substrateType
        self.ethereumType = ethereumType
        self.tokenProperties = tokenProperties
        self.price = price
        self.priceId = priceId
        self.coingeckoPriceId = coingeckoPriceId
        self.priceProvider = priceProvider
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        isUtility = try container.decode(Bool.self, forKey: .isUtility)
        precision = try container.decode(UInt16.self, forKey: .precision)
        icon = try? container.decode(URL?.self, forKey: .icon)
        substrateType = try? container.decode(SubstrateAssetType?.self, forKey: .substrateType)
        ethereumType = try? container.decode(EthereumAssetType?.self, forKey: .ethereumType)
        tokenProperties = try? container.decode(TokenProperties?.self, forKey: .tokenProperties)
        price = nil
        priceId = nil
        coingeckoPriceId = nil
        priceProvider = nil
    }

    public func encode(to _: Encoder) throws {}

    public func replacingPrice(_: PriceData) -> AssetModel {
        AssetModel(
            id: id,
            name: name,
            symbol: symbol,
            isUtility: isUtility,
            precision: precision,
            icon: icon,
            substrateType: substrateType,
            ethereumType: ethereumType,
            tokenProperties: tokenProperties,
            price: price,
            priceId: priceId,
            coingeckoPriceId: coingeckoPriceId,
            priceProvider: priceProvider
        )
    }

    public static func == (lhs: AssetModel, rhs: AssetModel) -> Bool {
        lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.isUtility == rhs.isUtility &&
            lhs.precision == rhs.precision &&
            lhs.icon == rhs.icon &&
            lhs.symbol == rhs.symbol &&
            lhs.tokenProperties == rhs.tokenProperties &&
            lhs.substrateType == rhs.substrateType &&
            lhs.ethereumType == rhs.ethereumType &&
            lhs.tokenProperties == rhs.tokenProperties &&
            lhs.priceId == rhs.priceId &&
            lhs.coingeckoPriceId == rhs.coingeckoPriceId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension AssetModel {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbol
        case isUtility
        case precision
        case icon
        case tokenProperties
        case substrateType
        case ethereumType
        case currencyId
    }
}
