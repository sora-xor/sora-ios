import Foundation

struct EthereumSignature: Codable {
    enum CodingKeys: String, CodingKey {
        case vPart = "v"
        case rPart = "r"
        case sPart = "s"
    }

    let vPart: UInt8
    let rPart: Data
    let sPart: Data

    init(vPart: UInt8, rPart: Data, sPart: Data) {
        self.vPart = vPart
        self.rPart = rPart
        self.sPart = sPart
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let vPartString = try container.decode(String.self, forKey: .vPart)
        let vPartData = try NSData(hexString: vPartString) as Data
        vPart = 0//vPartData.bytes[0]

        let rPartString = try container.decode(String.self, forKey: .rPart)
        rPart = try NSData(hexString: rPartString) as Data

        let sPartString = try container.decode(String.self, forKey: .sPart)
        sPart = try NSData(hexString: sPartString) as Data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(Data([vPart]).soraHex, forKey: .vPart)
        try container.encode(rPart.soraHex, forKey: .rPart)
        try container.encode(sPart.soraHex, forKey: .sPart)
    }
}
