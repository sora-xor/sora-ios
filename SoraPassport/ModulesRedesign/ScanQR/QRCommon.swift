import Foundation

public protocol QRInfo {
    var address: String { get }
}

public protocol QRDecodable {
    func decode(data: Data) throws -> QRInfo
}

public protocol QREncodable {
    func encode(info: AddressQRInfo) throws -> Data
}

public enum QREncoderError: Error, Equatable {
    case brokenData
}

public enum QRDecoderError: Error, Equatable {
    case brokenFormat
    case unexpectedNumberOfFields
    case undefinedPrefix
    case accountIdMismatch
    case wrongDecoder
}
