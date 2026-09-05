import Foundation

// sourcery: AutoMockable
public protocol QREncoder {
    func encode(with type: QRType) throws -> Data
}

public final class QREncoderDefault: QREncoder {
    public func encode(with type: QRType) throws -> Data {
        switch type {
        case let .address(address):
            return try CexQREncoder().encode(address: address)
        case let .addressInfo(addressInfo):
            return try SoraQREncoder().encode(addressInfo: addressInfo)
        }
    }
}
