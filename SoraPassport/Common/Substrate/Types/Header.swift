import Foundation
import FearlessUtils
import BigInt

struct Header: ScaleDecodable {

    let parentHash: String
    let stateRoot: String
    @StringCodable var number: UInt32
    let extrinsicRoot: String
    let digest: [String : String]

    enum CodingKeys: String, CodingKey {
        case parentHash
        case stateRoot
        case number
        case extrinsicRoot
    }

    init(scaleDecoder: ScaleDecoding) throws {
        parentHash = try String(scaleDecoder: scaleDecoder)
        stateRoot = try String(scaleDecoder: scaleDecoder)
        number = try UInt32(scaleDecoder: scaleDecoder)
        extrinsicRoot = try String(scaleDecoder: scaleDecoder)
        digest = [:]
    }

//    public init(from decoder: Decoder) throws {
//        var container = try decoder.container(keyedBy: CodingKeys.self)
//
//        parentHash = try container.decode(String.self, forKey: .parentHash)
//        stateRoot = try container.decode(String.self, forKey: .stateRoot)
//        number = try container.decode(BigUInt.self, forKey: .number)
//        extrinsicRoot = try container.decode(String.self, forKey: .extrinsicRoot)
//        digest = [:]
//    }
}
