import FearlessUtils
import BigInt
import Foundation

class SwapAmount: Codable {
    var desired: BigUInt
    var slip: BigUInt
    let type: SwapVariant

    enum CodingKeysIn: String, CodingKey {
        case desired = "desired_amount_in"
        case slip = "min_amount_out"
    }
    enum CodingKeysOut: String, CodingKey {
        case desired = "desired_amount_out"
        case slip = "max_amount_in"
    }

    init(type: SwapVariant, desired: BigUInt, slip: BigUInt) {
        self.desired = desired
        self.slip = slip
        self.type = type
    }

    required public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeysIn.self),
           !container.allKeys.isEmpty {
            let slip = try container.decode(String.self, forKey: CodingKeysIn.slip)
            let desired = try container.decode(String.self, forKey: CodingKeysIn.desired)
            self.slip = BigUInt(slip) ?? 0
            self.desired = BigUInt(desired) ?? 0
            type = .desiredInput
        } else
        if let container = try? decoder.container(keyedBy: CodingKeysOut.self),
           !container.allKeys.isEmpty {
            let desired = try container.decode(String.self, forKey: CodingKeysOut.slip)
            let slip = try container.decode(String.self, forKey: CodingKeysOut.desired)
            self.slip = BigUInt(slip) ?? 0
            self.desired = BigUInt(desired) ?? 0
            type = .desiredOutput
        } else {
            let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                debugDescription: "Invalid CodingKey")
            throw DecodingError.typeMismatch(SwapAmount.self, context)
        }
    }

    public func encode(to encoder: Encoder) throws {
        let key: CodingKey
        switch type {
            //please, mind that we encode .description, because metadata requires string, and @stringCodable somehow fails
        case .desiredOutput:
            var container = encoder.container(keyedBy: CodingKeysOut.self)
            try container.encode(desired.description, forKey: .desired)
            try container.encode(slip.description, forKey: .slip)
        case .desiredInput:
            var container = encoder.container(keyedBy: CodingKeysIn.self)
            try container.encode(desired.description, forKey: .desired)
            try container.encode(slip.description, forKey: .slip)
        }
    }
}

enum SwapVariant: String, Codable {
    case desiredInput = "WithDesiredInput"
    case desiredOutput = "WithDesiredOutput"
}

struct SwapCall: Codable {
    let dexId: String
    @ArrayCodable var inputAssetId: String
    @ArrayCodable var outputAssetId: String

    var amount: [SwapVariant: SwapAmount]
    let liquiditySourceType: [UInt?] //TBD liquiditySourceType.codable
    let filterMode: UInt

    enum CodingKeys: String, CodingKey {
        case dexId = "dex_id"
        case inputAssetId = "input_asset_id"
        case outputAssetId = "output_asset_id"
        case amount = "swap_amount"
        case liquiditySourceType = "selected_source_types"
        case filterMode = "filter_mode"
    }

}
