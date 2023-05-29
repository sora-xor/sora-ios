import Foundation
import IrohaCrypto

enum SS58AddressFactoryError: Error {
    case unexpectedAddress
}

extension SS58AddressFactory {
    func extractAddressType(from address: String) throws -> SNAddressType {
        let addressTypeValue = try type(fromAddress: address)

        let addressType = SNAddressType(addressTypeValue.uint8Value)

        return addressType
    }

    func accountId(from address: String) throws -> Data {
        let addressType = try extractAddressType(from: address)
        return try accountId(fromAddress: address, type: addressType)
    }

    func addressFromAccountId(data: Data, type: SNAddressType) throws -> String {
        return try address(fromAccountId: data, type: type)
    }
}
