import Foundation
import SSFQRService

public protocol AddressQREncodable: QREncodable {}
public protocol AddressQRDecodable: QRDecodable {}

public struct AddressQRInfo: QRInfo, Equatable {
    public let prefix: String
    public let address: String
    public let rawPublicKey: Data
    public let username: String?
    
    public init(
        prefix: String = SubstrateQRConstants.prefix,
        address: String,
        rawPublicKey: Data,
        username: String?
    ) {
        self.prefix = prefix
        self.address = address
        self.rawPublicKey = rawPublicKey
        self.username = username
    }
}
